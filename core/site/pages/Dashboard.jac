import from "@jac/runtime" { Link, useNavigate }
import from "lucide-react" {
    ArrowRight,
    Flame,
    GitCommitHorizontal,
    Users,
    Files,
    ShieldCheck,
    FlaskConical,
    Bus,
    ScanSearch,
    LayoutGrid,
    Github
}

def weekly_from_days(days: list[any]) -> list[float] {
    out: list[float] = [];
    acc = 0;
    for (i, d) in enumerate(days) {
        acc += d.count;
        if (i + 1) % 7 == 0 {
            out.append(acc);
            acc = 0;
        }
    }
    return out;
}

def:pub Dashboard -> JsxElement {
    has data: any = None,
        error: str = "";
    nav = useNavigate();
    async def load {
        try {
            data = await dashboard();
        } except Exception as e {
            error = str(e);
        }
    }
    async can with entry {
        await load();
    }
    useLiveReload(["data", "review"], load);
    async def review(pr_id: str) {
        nav("/reviews/" + pr_id);
        await launch_review(pr_id, "");
    }
    if error {
        return
            <div className="p-8">
                <Empty title="Could not load the dashboard" hint={error}/>
            </div>;
    }
    if not data {
        return
            <div className="@container mx-auto max-w-7xl space-y-4 p-4 sm:p-6">
                <Skeleton className="h-20"/>
                <div className="grid grid-cols-2 gap-3 lg:grid-cols-6">
                    {for i in range(6) {
                        <Skeleton key={str(i)} className="h-24"/>
                    }}
                </div>
                <Skeleton className="h-64"/>
            </div>;
    }
    r = data.repo;
    s = data.stats;
    langs = data.languages;
    lang_total = sum([l.bytes for l in langs]) or 1;
    spark = weekly_from_days(data.activity);
    open_prs = len(data.prs);
    risky = [
        row
        for row in data.prs
        if row.risk >= 0
    ];
    <div className="@container mx-auto max-w-7xl space-y-5 p-4 sm:p-6">
        <PageHeader
            eyebrow="Repository"
            title={r.name}
            subtitle={r.path + " · " + r.branch + " @ " + r.head + " · base " + r.base}
        >
            {if r.github {
                <a
                    href={"https://github.com/" + r.github}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground"
                >
                    <Github className="size-4"/>
                    {r.github}
                </a>
            }}
            <Link
                to="/reviews"
                className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground hover:bg-primary/90"
            >
                <ScanSearch className="size-4"/>
                Review queue
            </Link>
        </PageHeader>
        <div className="grid grid-cols-2 gap-3 @2xl:grid-cols-4 @5xl:grid-cols-7">
            <StatTile
                label="Commits"
                value={fmt_num(r.commits)}
                hint={"since " + r.first_commit[:10]}
            />
            <StatTile
                label="Last 90 days"
                value={fmt_num(s.commits_90d)}
                hint={str(s.authors_90d) + " authors · +" + fmt_num(s.additions_90d)}
            >
                <Sparkline values={spark} width={130} height={26}/>
            </StatTile>
            <StatTile
                label="Contributors"
                value={fmt_num(r.contributors)}
                hint={"bus factor " + str(s.bus_factor)}
            />
            <StatTile
                label="Tracked files"
                value={fmt_num(r.files)}
                hint={str(round(s.test_ratio * 1000) / 10) + "% look like tests"}
            />
            <StatTile
                label="Median commit"
                value={fmt_num(s.median_commit_size)}
                hint="lines changed"
            />
            <StatTile
                label="Review queue"
                value={str(open_prs)}
                hint={str(len(risky)) + " reviewed by diffwalker"}
            />
            <StatTile
                label="Model spend"
                value={"$" + str(round(data.spend * 100) / 100)}
                hint={str(data.reviews) + " reviews · byLLM telemetry"}
            />
        </div>
        <div className="grid gap-5 @5xl:grid-cols-[minmax(0,1fr)_380px]">
            <Panel
                title="Commit activity"
                subtitle={"Busiest day "
                    + s.busiest_day
                    + " with "
                    + str(s.busiest_count)
                    + " commits · current streak "
                    + str(s.streak_days)
                    + " days"}
                action={<Link
                    to="/insights?view=activity"
                    className="text-xs text-primary hover:underline"
                >
                    Deep dive
                </Link>}
            >
                <CalendarHeatmap days={data.activity} cell={13}/>
            </Panel>
            <Panel title="Languages" subtitle="Bytes at HEAD, generated files excluded">
                <Donut
                    labels={[l.language for l in langs]}
                    values={[float(l.bytes) for l in langs]}
                    center={fmt_bytes(lang_total)}
                    sub="source"
                    size={150}
                />
            </Panel>
        </div>
        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
            <Panel
                title="Review queue"
                subtitle="Local branches ahead of base, GitHub pull requests, and uncommitted work"
                action={<Link
                    to="/reviews"
                    className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
                >
                    All{" "}
                    <ArrowRight className="size-3"/>
                </Link>}
                bodyClass="pt-2"
            >
                {if len(data.prs) == 0 {
                    <Empty
                        title="Nothing to review"
                        hint="No branches ahead of base and a clean working tree."
                    />
                } else {
                    <div className="-mx-2">
                        {for row in data.prs {
                            <PRLine
                                key={row.pr.id}
                                row={row}
                                onReview={review}
                                compact={True}
                            />
                        }}
                    </div>
                } }
            </Panel>
            <Panel
                title="Hotspots"
                subtitle="Change frequency × size × recency over the last 1,500 commits"
                action={<Link
                    to="/insights?view=hotspots"
                    className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
                >
                    Explore{" "}
                    <ArrowRight className="size-3"/>
                </Link>}
            >
                <HBars
                    labels={[base_name(h.path) for h in data.hotspots]}
                    sub={[dir_name(h.path) for h in data.hotspots]}
                    values={[h.score for h in data.hotspots]}
                    colors={["var(--status-serious)" for h in data.hotspots]}
                />
            </Panel>
        </div>
        <div className="grid gap-5 @4xl:grid-cols-[minmax(0,1fr)_320px]">
            <Panel
                title="Latest findings"
                subtitle="From the most recent review of each pull request"
                bodyClass="pt-2"
            >
                {if len(data.findings) == 0 {
                    <Empty
                        title="No findings yet"
                        hint="Run a review from the queue, or ask Copilot to review the riskiest pull request."
                    />
                } else {
                    <div className="divide-y divide-border">
                        {for f in data.findings {
                            <Link
                                key={f.id}
                                to={"/reviews/"
                                    + f.pr_id
                                    + "?tab=files&file="
                                    + encodeURIComponent(f.path)
                                    + "&line="
                                    + str(f.line)}
                                className="flex items-start gap-3 py-2.5 hover:bg-muted/30"
                            >
                                <SevBadge sev={f.severity}/>
                                <div className="min-w-0 flex-1">
                                    <div
                                        className={"truncate text-sm "
                                            + (
                                                "line-through text-muted-foreground"
                                                    if f.status != "open"
                                                    else ""
                                            )}
                                    >
                                        {f.title}
                                    </div>
                                    <div
                                        className="truncate font-mono text-[11px] text-muted-foreground"
                                    >
                                        {f.path
                                            + ":"
                                            + str(f.line)
                                            + " · "
                                            + f.category
                                            + " · "
                                            + ago(f.created)}
                                    </div>
                                </div>
                            </Link>
                        }}
                    </div>
                } }
            </Panel>
            <Panel
                title="Insight board"
                subtitle="Charts and diagrams Copilot pinned for this repository"
            >
                <div className="flex items-center gap-4">
                    <span
                        className="grid size-14 place-items-center rounded-2xl bg-primary/15 text-primary"
                    >
                        <LayoutGrid className="size-6"/>
                    </span>
                    <div>
                        <div className="text-3xl font-semibold">
                            {str(data.insights)}
                        </div>
                        <div className="text-xs text-muted-foreground">
                            pinned insights
                        </div>
                    </div>
                </div>
                <Link
                    to="/board"
                    className="mt-4 inline-flex items-center gap-1 text-xs text-primary hover:underline"
                >
                    Open the board{" "}
                    <ArrowRight className="size-3"/>
                </Link>
            </Panel>
        </div>
    </div>
}
