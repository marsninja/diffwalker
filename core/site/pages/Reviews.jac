import from "@jac/runtime" { useNavigate }
import from "lucide-react" { RefreshCw, Search, GitBranch, Github, PencilLine, Layers }

glob FILTERS: list[any] = [
         {"key": "all", "label": "All", "icon": Layers},
         {"key": "branch", "label": "Branches", "icon": GitBranch},
         {"key": "github", "label": "GitHub", "icon": Github},
         {"key": "worktree", "label": "Worktree", "icon": PencilLine}
     ];

def FilterTab(item: any, active: bool, count: int, onPick: any) -> JsxElement {
    Icon = item["icon"];
    <button
        type="button"
        onClick={lambda { onPick(item["key"]); }}
        className={"inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-medium transition-colors "
            + (
                "bg-background text-foreground shadow-sm"
                    if active
                    else "text-muted-foreground hover:text-foreground"
            )}
    >
        <Icon className="size-3.5"/>
        {item["label"]}
        <span className="rounded-full bg-muted px-1.5 text-[10px] tabular">
            {str(count)}
        </span>
    </button>
}

def:pub Reviews -> JsxElement {
    has rows: list[any] = [],
        loaded: bool = False,
        kind: str = "all",
        query: str = "",
        sort: str = "updated",
        refreshing: bool = False;
    nav = useNavigate();
    async def load {
        rows = await list_reviews(False);
        loaded = True;
    }
    async def refresh {
        refreshing = True;
        rows = await list_reviews(True);
        refreshing = False;
    }
    async can with entry {
        await load();
    }
    useLiveReload(["data", "review"], load);
    async def review(pr_id: str) {
        nav("/reviews/" + pr_id);
        await launch_review(pr_id, "");
    }
    q = query.lower();
    shown = [
        r
        for r in rows
        if (kind == "all" or r.pr.kind == kind)
            and (
                not q
                or q in r.pr.title.lower()
                or q in r.pr.head.lower()
                or q in r.pr.author.lower()
            )
    ];
    if sort == "risk" {
        shown = sorted(shown, key=lambda (r: any) -> int { return 0 - r.risk; });
    } elif sort == "size" {
        shown = sorted(
            shown,
            key=lambda (r: any) -> int { return 0 - (r.pr.additions + r.pr.deletions); }
        );
    }
    reviewed = [
        r
        for r in rows
        if r.verdict
    ];
    verdicts = {"approve": 0, "comment": 0, "request_changes": 0};
    for r in reviewed {
        verdicts[r.verdict] = (verdicts[r.verdict] or 0) + 1;
    }
    total_open = sum([r.open_findings for r in reviewed]);
    <div className="@container mx-auto max-w-7xl space-y-5 p-4 sm:p-6">
        <PageHeader
            eyebrow="Review queue"
            title="Pull requests"
            subtitle="Every local branch ahead of base, open GitHub pull requests from the remote, and your uncommitted work. Pick one, or let Copilot choose."
        >
            <button
                type="button"
                onClick={refresh}
                className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground"
            >
                <RefreshCw
                    className={"size-4 " + ("animate-spin" if refreshing else "")}
                />
                Rescan
            </button>
        </PageHeader>
        <div className="grid gap-5 @4xl:grid-cols-[minmax(0,1fr)_300px]">
            <Panel bodyClass="pt-3">
                <div className="mb-3 flex flex-wrap items-center gap-2">
                    <div className="flex flex-wrap gap-0.5 rounded-xl bg-muted p-1">
                        {for f in FILTERS {
                            <FilterTab
                                key={f["key"]}
                                item={f}
                                active={kind == f["key"]}
                                count={len(rows)
                                    if f["key"] == "all"
                                    else len(
                                        [
                                            r
                                            for r in rows
                                            if r.pr.kind == f["key"]
                                        ]
                                    )}
                                onPick={lambda (k: str) { kind = k; }}
                            />
                        }}
                    </div>
                    <label
                        className="ml-auto flex h-8 min-w-[180px] flex-1 items-center gap-2 rounded-lg border border-border bg-background px-2.5 sm:max-w-xs"
                    >
                        <Search className="size-3.5 text-muted-foreground"/>
                        <input
                            value={query}
                            onChange={lambda (e: any) { query = e.target.value; }}
                            placeholder="Filter by title, branch, author"
                            className="min-w-0 flex-1 bg-transparent text-xs outline-none"
                        />
                    </label>
                    <select
                        value={sort}
                        onChange={lambda (e: any) { sort = e.target.value; }}
                        className="h-8 rounded-lg border border-border bg-background px-2 text-xs"
                        aria-label="Sort"
                    >
                        <option value="updated">Recently updated</option>
                        <option value="risk">Highest risk</option>
                        <option value="size">Largest change</option>
                    </select>
                </div>
                {if not loaded {
                    <div className="space-y-2">
                        {for i in range(6) {
                            <Skeleton key={str(i)} className="h-12"/>
                        }}
                    </div>
                } elif len(shown) == 0 {
                    <Empty
                        title="Nothing matches"
                        hint="Clear the filter or rescan the repository."
                    />
                } else {
                    <div className="-mx-2 divide-y divide-border/60">
                        {for row in shown {
                            <PRLine key={row.pr.id} row={row} onReview={review}/>
                        }}
                    </div>
                }  }
            </Panel>
            <div className="space-y-5">
                <Panel
                    title="Verdicts"
                    subtitle={str(len(reviewed))
                        + " of "
                        + str(len(rows))
                        + " reviewed"}
                >
                    {if len(reviewed) == 0 {
                        <p className="text-xs text-muted-foreground">
                            No reviews yet. Hover a row and press Review, or ask Copilot.
                        </p>
                    } else {
                        <Donut
                            labels={["Approve", "Comment", "Changes requested"]}
                            values={[
                                float(verdicts["approve"]),
                                float(verdicts["comment"]),
                                float(verdicts["request_changes"])
                            ]}
                            colors={[
                                "var(--status-good)",
                                "var(--status-warning)",
                                "var(--status-critical)"
                            ]}
                            center={str(len(reviewed))}
                            sub="reviews"
                            size={130}
                        />
                    } }
                </Panel>
                <Panel
                    title="Open findings"
                    subtitle="Across the latest review of each pull request"
                >
                    <div className="text-3xl font-semibold tabular">
                        {str(total_open)}
                    </div>
                    <div className="mt-3 space-y-1.5">
                        {for r in sorted(
                            reviewed,
                            key=lambda (x: any) -> int { return 0 - x.open_findings; }
                        )[:5] {
                            <a
                                key={r.pr.id}
                                href={"/reviews/" + r.pr.id + "?tab=findings"}
                                className="flex items-center gap-2 text-xs hover:underline"
                            >
                                <span
                                    className="inline-block size-2 rounded-full"
                                    style={{"background": risk_color(r.risk)}}
                                ></span>
                                <span className="truncate">{r.pr.title}</span>
                                <span className="ml-auto tabular text-muted-foreground">
                                    {str(r.open_findings)}
                                </span>
                            </a>
                        }}
                    </div>
                </Panel>
            </div>
        </div>
    </div>
}
