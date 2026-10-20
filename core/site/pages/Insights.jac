import from "@jac/runtime" { useLocation, useNavigate }
import from "lucide-react" {
    Activity,
    Flame,
    Users,
    Boxes,
    Network as NetworkIcon,
    Sparkles,
    TriangleAlert
}

glob VIEWS: list[any] = [
         {"key": "activity", "label": "Activity", "icon": Activity},
         {"key": "hotspots", "label": "Hotspots", "icon": Flame},
         {"key": "people", "label": "People", "icon": Users},
         {"key": "structure", "label": "Structure", "icon": Boxes},
         {"key": "coupling", "label": "Coupling", "icon": NetworkIcon}
     ],
     KIND_NAMES: list[str] = [
         "feat",
         "fix",
         "refactor",
         "docs",
         "test",
         "chore",
         "perf",
         "other"
     ];

def view_from(search: str) -> str {
    for part in (search[1:] if search.startswith("?") else search).split("&") {
        if part.startswith("view=") {
            return part[5:];
        }
    }
    return "";
}

def ViewTab(item: any, active: bool, onPick: any) -> JsxElement {
    Icon = item["icon"];
    <button
        type="button"
        onClick={lambda { onPick(item["key"]); }}
        className={"inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm transition-colors "
            + (
                "bg-background font-medium text-foreground shadow-sm"
                    if active
                    else "text-muted-foreground hover:text-foreground"
            )}
    >
        <Icon className="size-4"/>
        {item["label"]}
    </button>
}

def AskButton(prompt: str, label: str = "Ask Copilot") -> JsxElement {
    <button
        type="button"
        onClick={lambda { ask_copilot(prompt); }}
        className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs text-primary hover:bg-primary/10"
    >
        <Sparkles className="size-3.5"/>
        {label}
    </button>
}

def ActivityPane -> JsxElement {
    has data: any = None;
    async can with entry {
        data = await activity_view();
    }
    if not data {
        return
            <div className="space-y-4">
                <Skeleton className="h-48"/>
                <Skeleton className="h-64"/>
            </div>;
    }
    weeks = data.weeks;
    labels = [w.week[5:] for w in weeks];
    day_weeks: list[float] = [];
    day_labels: list[str] = [];
    acc = 0;
    for (i, d) in enumerate(data.days) {
        acc += d.count;
        if (i + 1) % 7 == 0 {
            day_weeks.append(float(acc));
            day_labels.append(d.day[5:]);
            acc = 0;
        }
    }
    kinds = data.kinds;
    s = data.stats;
    <div className="space-y-5">
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatTile
                label="Commits · 90d"
                value={fmt_num(s.commits_90d)}
                hint={str(s.authors_90d) + " active authors"}
            />
            <StatTile
                label="Lines added · 90d"
                value={"+" + fmt_num(s.additions_90d)}
                hint={"−" + fmt_num(s.deletions_90d) + " removed"}
            />
            <StatTile
                label="Busiest day"
                value={str(s.busiest_count)}
                hint={s.busiest_day}
            />
            <StatTile
                label="Current streak"
                value={str(s.streak_days) + "d"}
                hint="consecutive days with commits"
            />
        </div>
        <Panel
            title="A year of commits"
            subtitle="Each square is a day on the current branch, merges excluded"
            action={<AskButton
                prompt="Look at the last year of commit activity. When were the busiest stretches, what changed then (check the commit subjects), and is the pace speeding up or slowing down? Render a chart."
                label="Explain"
            />}
        >
            <CalendarHeatmap days={data.days} cell={11}/>
        </Panel>
        <div className="grid gap-5 xl:grid-cols-2">
            <Panel title="Commits per week" subtitle="Last 53 weeks, merges excluded">
                <BarChart
                    labels={day_labels}
                    values={day_weeks}
                    color="var(--series-1)"
                    unit="commits"
                    height={200}
                />
            </Panel>
            <Panel title="Churn per week" subtitle="Lines added vs removed">
                <LineChart
                    labels={labels}
                    series={[
                        {
                            "name": "Added",
                            "values": [float(w.additions) for w in weeks],
                            "color": "var(--series-3)"
                        },
                        {
                            "name": "Removed",
                            "values": [float(w.deletions) for w in weeks],
                            "color": "var(--series-2)"
                        }
                    ]}
                    height={200}
                />
            </Panel>
        </div>
        <Panel
            title="What kind of work"
            subtitle="Conventional-commit type per month (feat, fix, refactor, …); unprefixed commits count as other"
        >
            <StackedBars
                labels={[k.month for k in kinds]}
                series={[
                    {"name": n, "values": [float(k.counts[n] or 0) for k in kinds]}
                    for n in KIND_NAMES
                ]}
                height={220}
            />
        </Panel>
    </div>
}

def HotspotsPane -> JsxElement {
    has rows: list[any] = [],
        loaded: bool = False;
    async can with entry {
        rows = await hotspots_view(40);
        loaded = True;
    }
    if not loaded {
        return <Skeleton className="h-96"/>;
    }
    langs: list[str] = [];
    for h in rows {
        if h.language not in langs {
            langs.append(h.language);
        }
    }
    def lang_color(lang: str) -> str {
        i = langs.index(lang);
        return series_color(i) if i < 8 else "var(--ink-muted)";
    }
    points = [
        {
            "x": h.changes,
            "y": h.churn,
            "r": h.authors,
            "color": lang_color(h.language),
            "label": h.path,
            "lines": [
                {"label": "changes", "value": str(h.changes), "color": ""},
                {"label": "churn", "value": fmt_num(h.churn), "color": ""},
                {"label": "authors", "value": str(h.authors), "color": ""},
                {"label": "size", "value": fmt_bytes(h.size), "color": ""}
            ]
        } for h in rows
    ];
    <div className="space-y-5">
        <Panel
            title="Change frequency vs churn"
            subtitle="Each bubble is a file. Up and to the right churns most; bubble size is the number of distinct authors."
            action={<AskButton
                prompt="Explain the top 5 hotspots in this repository: why do they keep changing, who changes them, and what refactor would reduce the churn? Open the files you cite."
                label="Diagnose"
            />}
        >
            <Scatter
                points={points}
                x_label="commits touching the file"
                y_label="lines churned"
                onPick={lambda (i: int) { ask_copilot(
                    "Why does "
                        + rows[i].path
                        + " change so often? Look at its history and blame and tell me what keeps changing."
                ); }}
            />
            <div
                className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground"
            >
                {for (i, l) in enumerate(langs[:8]) {
                    <span key={l} className="inline-flex items-center gap-1.5">
                        <span
                            className="inline-block size-2.5 rounded-full"
                            style={{"background": series_color(i)}}
                        ></span>
                        {l}
                    </span>
                }}
            </div>
        </Panel>
        <Panel
            title="Ranked hotspots"
            subtitle="Score = changes × log(size) × recency + authors"
            bodyClass="pt-2"
        >
            <div className="overflow-x-auto thin-scroll">
                <table className="w-full text-sm">
                    <thead
                        className="text-left text-[11px] uppercase tracking-wider text-muted-foreground"
                    >
                        <tr>
                            <th className="pb-2 pr-3 font-medium">#</th>
                            <th className="pb-2 pr-3 font-medium">File</th>
                            <th className="pb-2 pr-3 text-right font-medium">
                                Changes
                            </th>
                            <th className="pb-2 pr-3 text-right font-medium">Churn</th>
                            <th className="pb-2 pr-3 text-right font-medium">
                                Authors
                            </th>
                            <th className="pb-2 pr-3 text-right font-medium">Size</th>
                            <th className="pb-2 pr-3 font-medium">Last change</th>
                            <th className="pb-2 text-right font-medium">Score</th>
                        </tr>
                    </thead>
                    <tbody className="tabular">
                        {for (i, h) in enumerate(rows) {
                            <tr key={h.path} className="border-t border-border/60">
                                <td
                                    className="py-1.5 pr-3 text-xs text-muted-foreground"
                                >
                                    {str(i + 1)}
                                </td>
                                <td className="max-w-[340px] py-1.5 pr-3">
                                    <div className="truncate font-mono text-xs">
                                        {base_name(h.path)}
                                    </div>
                                    <div
                                        className="truncate font-mono text-[10px] text-muted-foreground"
                                    >
                                        {dir_name(h.path)}
                                    </div>
                                </td>
                                <td className="py-1.5 pr-3 text-right">
                                    {str(h.changes)}
                                </td>
                                <td className="py-1.5 pr-3 text-right">
                                    {fmt_num(h.churn)}
                                </td>
                                <td className="py-1.5 pr-3 text-right">
                                    {str(h.authors)}
                                </td>
                                <td className="py-1.5 pr-3 text-right">
                                    {fmt_bytes(h.size)}
                                </td>
                                <td
                                    className="py-1.5 pr-3 text-xs text-muted-foreground"
                                >
                                    {ago(h.last_ts)}
                                </td>
                                <td className="py-1.5 text-right font-medium">
                                    {fmt_num(h.score)}
                                </td>
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>
        </Panel>
    </div>
}

def PeoplePane -> JsxElement {
    has data: any = None;
    async can with entry {
        data = await people_view();
    }
    if not data {
        return <Skeleton className="h-96"/>;
    }
    people = data.contributors;
    owners = data.ownership;
    owner_names: list[str] = [];
    for o in owners {
        if o.owner not in owner_names {
            owner_names.append(o.owner);
        }
    }
    def owner_color(name: str) -> str {
        i = owner_names.index(name);
        return series_color(i) if i < 8 else "var(--ink-muted)";
    }
    silos = [
        o
        for o in owners
        if o.share >= 0.8 and o.commits >= 10
    ];
    <div className="space-y-5">
        <div className="grid gap-5 xl:grid-cols-2">
            <Panel
                title="Most active contributors"
                subtitle="Commits in the last 1,500 non-merge commits"
            >
                <HBars
                    labels={[p.name for p in people[:12]]}
                    sub={[
                        "+"
                            + fmt_num(p.additions)
                            + " −"
                            + fmt_num(p.deletions)
                            + " · mostly "
                            + p.top_area for p in people[:12]
                    ]}
                    values={[float(p.commits) for p in people[:12]]}
                    colors={["var(--series-1)" for p in people[:12]]}
                    mono={False}
                />
            </Panel>
            <Panel
                title="Who owns what"
                subtitle="Dominant author's share of commits per directory. Bars over 80% are knowledge silos."
                action={<AskButton
                    prompt="Which directories are knowledge silos (one author owns most commits)? Show the ownership view, rank the riskiest silos, and suggest who could pair on each."
                    label="Assess"
                />}
            >
                <div className="space-y-2">
                    {for o in owners {
                        <div key={o.area} className="text-xs">
                            <div className="mb-1 flex items-center gap-2">
                                <span className="min-w-0 flex-1 truncate font-mono">
                                    {o.area}
                                </span>
                                {if o.share >= 0.8 and o.commits >= 10 {
                                    <TriangleAlert
                                        className="size-3.5 text-[var(--status-warning)]"
                                    />
                                }}
                                <span className="text-muted-foreground">
                                    {o.owner + " · " + pct(o.share, 1)}
                                </span>
                            </div>
                            <div className="h-2 overflow-hidden rounded-full bg-muted">
                                <div
                                    className="h-full rounded-full"
                                    style={{
                                        "width": str(round(o.share * 100)) + "%",
                                        "background": owner_color(o.owner)
                                    }}
                                ></div>
                            </div>
                        </div>
                    }}
                </div>
            </Panel>
        </div>
        {if len(silos) > 0 {
            <div
                className="flex items-start gap-3 rounded-2xl border border-[var(--status-warning)]/40 bg-[var(--status-warning)]/10 p-4 text-sm"
            >
                <TriangleAlert
                    className="mt-0.5 size-4 shrink-0 text-[var(--status-warning)]"
                />
                <div>
                    <span className="font-medium">
                        {str(len(silos)) + " knowledge silos. "}
                    </span>
                    <span className="text-muted-foreground">
                        {", ".join([o.area + " (" + o.owner + ")" for o in silos[:5]])}
                    </span>
                </div>
            </div>
        }}
        <Panel title="Contributor table" bodyClass="pt-2">
            <div className="overflow-x-auto thin-scroll">
                <table className="w-full text-sm">
                    <thead
                        className="text-left text-[11px] uppercase tracking-wider text-muted-foreground"
                    >
                        <tr>
                            <th className="pb-2 pr-3 font-medium">Author</th>
                            <th className="pb-2 pr-3 text-right font-medium">
                                Commits
                            </th>
                            <th className="pb-2 pr-3 text-right font-medium">Added</th>
                            <th className="pb-2 pr-3 text-right font-medium">
                                Removed
                            </th>
                            <th className="pb-2 pr-3 text-right font-medium">Files</th>
                            <th className="pb-2 pr-3 font-medium">Main area</th>
                            <th className="pb-2 font-medium">Last active</th>
                        </tr>
                    </thead>
                    <tbody className="tabular">
                        {for p in people {
                            <tr key={p.name} className="border-t border-border/60">
                                <td className="py-1.5 pr-3">{p.name}</td>
                                <td className="py-1.5 pr-3 text-right">
                                    {str(p.commits)}
                                </td>
                                <td
                                    className="py-1.5 pr-3 text-right text-[var(--status-good)]"
                                >
                                    {"+" + fmt_num(p.additions)}
                                </td>
                                <td
                                    className="py-1.5 pr-3 text-right text-[var(--status-critical)]"
                                >
                                    {"−" + fmt_num(p.deletions)}
                                </td>
                                <td className="py-1.5 pr-3 text-right">
                                    {fmt_num(p.files)}
                                </td>
                                <td
                                    className="py-1.5 pr-3 font-mono text-xs text-muted-foreground"
                                >
                                    {p.top_area}
                                </td>
                                <td className="py-1.5 text-xs text-muted-foreground">
                                    {ago(p.last_ts)}
                                </td>
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>
        </Panel>
    </div>
}

def StructurePane -> JsxElement {
    has data: any = None,
        mode: str = "language";
    async can with entry {
        data = await structure_view();
    }
    if not data {
        return <Skeleton className="h-[480px]"/>;
    }
    cells = data.cells;
    langs = [l.language for l in data.languages];
    peak = 1;
    for c in cells {
        peak = max(peak, c.churn);
    }
    def color_of(c: any, i: int) -> str {
        if mode == "churn" {
            ratio = c.churn / peak;
            steps = [
                "var(--seq-200)",
                "var(--seq-300)",
                "var(--seq-400)",
                "var(--seq-500)",
                "var(--seq-600)",
                "var(--seq-700)"
            ];
            return steps[min(5, int(ratio * 6))];
        }
        idx = langs.index(c.language) if c.language in langs else 9;
        return series_color(idx) if idx < 8 else "var(--ink-muted)";
    }
    <div className="space-y-5">
        <Panel
            title="Repository map"
            subtitle="Directories (three levels deep) sized by bytes at HEAD"
            action={<div className="flex gap-0.5 rounded-lg bg-muted p-0.5 text-xs">
                <button
                    type="button"
                    onClick={lambda { mode = "language"; }}
                    className={"rounded-md px-2 py-1 "
                        + (
                            "bg-background shadow-sm"
                                if mode == "language"
                                else "text-muted-foreground"
                        )}
                >
                    Language
                </button>
                <button
                    type="button"
                    onClick={lambda { mode = "churn"; }}
                    className={"rounded-md px-2 py-1 "
                        + (
                            "bg-background shadow-sm"
                                if mode == "churn"
                                else "text-muted-foreground"
                        )}
                >
                    Churn
                </button>
            </div>}
        >
            <Treemap
                cells={cells}
                color_of={color_of}
                height={260}
                label_of={lambda (c: any) -> str { return c.path; }}
                sub_of={lambda (c: any) -> str { return fmt_bytes(c.bytes)
                    + " · "
                    + str(c.files)
                    + " files"; }}
            />
            {if mode == "language" {
                <div
                    className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground"
                >
                    {for (i, l) in enumerate(langs[:8]) {
                        <span key={l} className="inline-flex items-center gap-1.5">
                            <span
                                className="inline-block size-2.5 rounded-[3px]"
                                style={{"background": series_color(i)}}
                            ></span>
                            {l}
                        </span>
                    }}
                </div>
            } else {
                <div
                    className="mt-3 flex items-center gap-2 text-xs text-muted-foreground"
                >
                    <span>low churn</span>
                    <span
                        className="h-2 w-40 rounded-full"
                        style={{
                            "background": "linear-gradient(90deg, var(--seq-200), var(--seq-700))"
                        }}
                    ></span>
                    <span>high churn</span>
                </div>
            } }
        </Panel>
        <Panel title="Languages" subtitle="Share of bytes at HEAD">
            <Donut
                labels={langs}
                values={[float(l.bytes) for l in data.languages]}
                center={str(len(langs))}
                sub="languages"
                size={160}
            />
        </Panel>
    </div>
}

def CouplingPane -> JsxElement {
    has data: any = None;
    async can with entry {
        data = await coupling_view();
    }
    if not data {
        return <Skeleton className="h-[480px]"/>;
    }
    if len(data.nodes) == 0 {
        return
            <Empty
                title="No strong temporal coupling"
                hint="No file pairs changed together at least three times in recent history."
            />;
    }
    <div className="space-y-5">
        <Panel
            title="Temporal coupling"
            subtitle="Files that change in the same commits. Thicker edges co-change more; hover a file to isolate its neighbours."
            action={<AskButton
                prompt="Look at the temporal coupling between files. Which coupled pairs are surprising (different areas changing together), and what hidden dependency might explain them? Draw a diagram."
                label="Explain"
            />}
        >
            <Network nodes={data.nodes} edges={data.edges} height={480}/>
        </Panel>
        <Panel title="Strongest pairs" bodyClass="pt-2">
            <div className="divide-y divide-border/60">
                {for e in data.edges[:15] {
                    <div
                        key={e.a + e.b}
                        className="flex items-center gap-3 py-2 text-xs"
                    >
                        <span className="min-w-0 flex-1 truncate font-mono">
                            {short_path(e.a, 2)}
                        </span>
                        <span
                            className="shrink-0 rounded-full bg-primary/15 px-2 py-0.5 text-primary tabular"
                        >
                            {str(e.weight) + "×"}
                        </span>
                        <span className="min-w-0 flex-1 truncate text-right font-mono">
                            {short_path(e.b, 2)}
                        </span>
                    </div>
                }}
            </div>
        </Panel>
    </div>
}

def:pub Insights -> JsxElement {
    location = useLocation();
    nav = useNavigate();
    has view: str = "activity",
        epoch: int = 0;
    can with [location.search] entry {
        v = view_from(location.search);
        if v {
            view = v;
        }
    }
    useLiveReload(["data"], lambda { epoch = epoch + 1; });
    <div className="mx-auto max-w-7xl space-y-5 p-4 sm:p-6">
        <PageHeader
            eyebrow="Repository analytics"
            title="Insights"
            subtitle="Mined from git history: who changes what, how often, and what changes together. Copilot reads the same numbers through its tools."
        />
        <div className="flex flex-wrap gap-0.5 rounded-xl bg-muted p-1">
            {for v in VIEWS {
                <ViewTab
                    key={v["key"]}
                    item={v}
                    active={view == v["key"]}
                    onPick={lambda (k: str) {
                        view = k;
                        nav("/insights?view=" + k, {"replace": True});
                    }}
                />
            }}
        </div>
        <div key={view + str(epoch)} className="fade-up">
            {if view == "activity" {
                <ActivityPane/>
            } elif view == "hotspots" {
                <HotspotsPane/>
            } elif view == "people" {
                <PeoplePane/>
            } elif view == "structure" {
                <StructurePane/>
            } else {
                <CouplingPane/>
            }    }
        </div>
    </div>
}
