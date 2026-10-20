import from "@jac/runtime" { useParams, useLocation, useNavigate, Link }
import from "lucide-react" {
    ArrowLeft,
    Play,
    RotateCw,
    FileDown,
    Github,
    Sparkles,
    GitCommitHorizontal,
    ShieldX,
    FileSearch,
    CircleCheck,
    LoaderCircle,
    Target,
    ExternalLink,
    Clock,
    Info,
    TriangleAlert
}

glob TABS: list[str] = ["overview", "files", "findings", "commits", "history"];

def parse_query(search: str) -> dict[str, str] {
    out: dict[str, str] = {};
    body = search[1:] if search.startswith("?") else search;
    for part in body.split("&") {
        if "=" in part {
            idx = part.index("=");
            out[part[:idx]] = decodeURIComponent(part[idx + 1:].replace("+", " "));
        }
    }
    return out;
}

def fresh_run(review_id: str) -> any {
    return {
        "review_id": review_id,
        "stages": default_stages(),
        "files": {},
        "feed": [],
        "active": True
    };
}

def FeedRow(item: any) -> JsxElement {
    kind = item["kind"];
    <div className="fade-up flex items-start gap-2 text-xs">
        {if kind == "drop" {
            <ShieldX className="mt-0.5 size-3.5 shrink-0 text-[var(--status-serious)]"/>
        } elif kind == "draft" {
            <FileSearch className="mt-0.5 size-3.5 shrink-0 text-primary"/>
        } elif kind == "file" {
            <CircleCheck
                className="mt-0.5 size-3.5 shrink-0 text-[var(--status-good)]"
            />
        } elif kind == "warn" {
            <TriangleAlert className="mt-0.5 size-3.5 shrink-0 text-[var(--status-warning)]"/>
        } else {
            <Info className="mt-0.5 size-3.5 shrink-0 text-muted-foreground"/>
        }   }
        <div className="min-w-0">
            <div
                className={"leading-snug "
                    + ("line-through text-muted-foreground" if kind == "drop" else "")}
            >
                {item["title"]}
            </div>
            {if item["detail"] {
                <div
                    className="mt-0.5 line-clamp-2 text-[11px] leading-snug text-muted-foreground"
                    title={item["detail"]}
                >
                    {item["detail"]}
                </div>
            }}
        </div>
    </div>
}

def TabButton(
    name: str, label: str, active: bool, count: int, onPick: any
) -> JsxElement {
    <button
        type="button"
        onClick={lambda { onPick(name); }}
        className={"relative inline-flex items-center gap-1.5 whitespace-nowrap px-3 py-2.5 text-sm transition-colors "
            + (
                "font-medium text-foreground"
                    if active
                    else "text-muted-foreground hover:text-foreground"
            )}
    >
        {label}
        {if count >= 0 {
            <span className="rounded-full bg-muted px-1.5 text-[10px] tabular">
                {str(count)}
            </span>
        }}
        {if active {
            <span
                className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-primary"
            ></span>
        }}
    </button>
}

glob STAGE_LABELS: dict[str, str] = {
         "plan": "Plan",
         "review": "Specialist lenses",
         "cross": "Cross-file",
         "investigate": "Investigate (routing)",
         "verify": "Verify",
         "synthesize": "Synthesize"
     };

"""Where the money went: byLLM telemetry, billed per stage by the review's meter."""
def CostPanel(rv: any) -> JsxElement {
    total = max([c.cost for c in rv.costs]) or 0.000001;
    <div className="@container">
    <Panel
        title="Model spend"
        subtitle={"$" + str(round(rv.cost * 10000) / 10000) + " · " + fmt_num(rv.tokens) + " tokens · " + str(rv.llm_calls) + " calls · from byLLM telemetry, billed per stage"}
    >
        <div className="space-y-2">
            {for c in rv.costs {
                <div key={c.stage} className="grid grid-cols-[130px_minmax(0,1fr)] items-center gap-x-3 gap-y-1 text-xs @2xl:grid-cols-[150px_minmax(0,1fr)_330px]">
                    <span className="truncate text-muted-foreground">{STAGE_LABELS[c.stage] or c.stage}</span>
                    <span className="h-2 overflow-hidden rounded-full bg-muted">
                        <span
                            className="block h-full rounded-full bg-primary"
                            style={{"width": str(max(2, round(100 * c.cost / total))) + "%"}}
                        ></span>
                    </span>
                    <span className="tabular text-muted-foreground col-span-2 @2xl:col-span-1 @2xl:text-right">
                        {"$" + str(round(c.cost * 10000) / 10000) + " · " + str(c.calls) + " calls · " + fmt_num(c.tokens) + " tok" + (" (" + fmt_num(c.cached) + " cached)" if c.cached else "") + " · " + str(round(c.ms / 100) / 10) + "s"}
                    </span>
                </div>
            }}
        </div>
    </Panel>
    </div>
}

def:pub ReviewWorkspace -> JsxElement {
    params = useParams();
    location = useLocation();
    nav = useNavigate();
    pr_id = params["id"] or "";
    has detail: any = None,
        tab: str = "overview",
        file: str = "",
        line: int = 0,
        flashKey: str = "",
        sev: str = "",
        cat: str = "",
        status: str = "open",
        focus: str = "",
        tick: int = 0,
        missing: bool = False,
        picked: str = "",
        run: Ref[any] = Ref(None);

    async def load {
        d = await pr_detail(pr_id, picked);
        if not d.found {
            missing = True;
            return;
        }
        detail = d;
        if d.review and d.review.status == "running" and not run.current {
            r = fresh_run(d.review.id);
            r["stages"] = [
                {
                    "key": s.key,
                    "label": s.label,
                    "status": s.status,
                    "detail": s.detail
                } for s in d.review.stages
            ];
            run.current = r;
        }
        if d.review and d.review.status != "running" and run.current {
            run.current = None;
        }
        tick = tick + 1;
    }
    async can with [pr_id] entry {
        detail = None;
        missing = False;
        run.current = None;
        await load();
    }
    can with [location.search] entry {
        q = parse_query(location.search);
        if q["tab"] and q["tab"] in TABS {
            tab = q["tab"];
        }
        if q["file"] {
            file = q["file"];
            tab = "files";
        }
        line = int(q["line"]) if q["line"] else 0;
        flashKey = q["nonce"] or "";
        if q["severity"] {
            sev = q["severity"];
        }
        if (q["review"] or "") != picked {
            picked = q["review"] or "";
            load();
        }
    }
    can with [pr_id] entry {
        off_filter = on_channel(
            "findings-filter",
            lambda (a: any) {
                sev = a.severity or "";
                cat = a.category or "";
                status = a.status or "";
                tab = "findings";
            }
        );
        off = on_live(
            lambda (e: any) {
                d = e.data;
                if not d or (d.pr_id and d.pr_id != pr_id) {
                    return;
                }
                if e.kind == "data" and d.what in ("finding", "reviewing") {
                    load();
                    return;
                }
                if e.kind != "review" {
                    return;
                }
                ph = d.phase;
                if ph == "start" {
                    run.current = fresh_run(d.review_id);
                    run.current["feed"] = [
                        {
                            "kind": "info",
                            "title": "Review " + d.review_id + " started",
                            "detail": "Trigger: " + str(d.trigger)
                        }
                    ];
                    tab = "overview";
                } elif not run.current {
                    if ph in ("done", "failed") {
                        load();
                    }
                    return;
                }
                r: any = run.current;
                if ph == "stage" {
                    r["stages"] = d.stages;
                } elif ph == "triage" {
                    r["triage"] = d.files;
                    r["risk"] = d.risk;
                } elif ph == "file" {
                    r["files"] = {** r["files"], d.path: d.status};
                    if d.status == "reviewed" {
                        r["feed"] = [
                            {
                                "kind": "file",
                                "title": base_name(d.path)
                                    + " reviewed · "
                                    + str(d.findings)
                                    + " draft findings",
                                "detail": d.summary
                            }
                        ]
                            + r["feed"];
                    }
                } elif ph == "drafts" {
                    fresh = [
                        {
                            "kind": "draft",
                            "title": "[" + x.severity + "] " + x.title,
                            "detail": base_name(x.path)
                                + ":"
                                + str(x.line)
                                + " · "
                                + x.source
                        } for x in d.drafts
                    ];
                    r["feed"] = fresh + r["feed"];
                } elif ph == "drop" {
                    r["feed"] = [
                        {
                            "kind": "drop",
                            "title": d.title,
                            "detail": d.detail
                        }
                    ]
                        + r["feed"];
                } elif ph in ("warn", "info", "investigate") {
                    r["feed"] = [
                        {
                            "kind": "file" if ph == "investigate" else ("warn" if ph == "warn" else "info"),
                            "title": d.title,
                            "detail": d.detail
                        }
                    ]
                        + r["feed"];
                } elif ph == "done" {
                    r["active"] = False;
                    r["feed"] = [
                        {
                            "kind": "file",
                            "title": "Review finished in "
                                + str(d.seconds)
                                + "s · "
                                + verdict_label(d.verdict),
                            "detail": str(len(d.findings))
                                + " findings survived verification · $"
                                + str(round((d.cost or 0) * 1000) / 1000)
                        }
                    ]
                        + r["feed"];
                    load();
                    setTimeout(lambda { load(); }, 2000);
                } elif ph == "failed" {
                    r["active"] = False;
                    load();
                }
                run.current = r;
                tick = tick + 1;
            }
        );
        off_finished = on_channel(
            "review-finished",
            lambda (pid: str) { if pid == pr_id {
                if run.current {
                    run.current["active"] = False;
                }
                load();
                setTimeout(lambda { load(); }, 1500);
            }}
        );
        return lambda {
            off();
            off_filter();
            off_finished();
        };
    }
    async def kick {
        if not run.current or not run.current["active"] {
            run.current = fresh_run("");
        }
        tick = tick + 1;
        await launch_review(pr_id, focus);
    }
    async def do_export {
        md = await export_markdown(pr_id);
        if md {
            publish("export", {"pr_id": pr_id, "markdown": md});
        } else {
            toast("Run a review first", "warning");
        }
    }
    def pick_tab(name: str) {
        tab = name;
        nav("/reviews/" + pr_id + "?tab=" + name, {"replace": True});
    }
    def jump(fd: any) {
        nav(
            "/reviews/"
                + pr_id
                + "?tab=files&file="
                + encodeURIComponent(fd.path)
                + "&line="
                + str(fd.line)
        );
    }
    if missing {
        return
            <div className="mx-auto max-w-3xl p-8">
                <Empty
                    title="Pull request not found"
                    hint={"No branch, GitHub PR, or worktree matches " + pr_id + "."}
                >
                    <Link
                        to="/reviews"
                        className="text-sm text-primary hover:underline"
                    >
                        Back to the queue
                    </Link>
                </Empty>
            </div>;
    }
    if not detail {
        return
            <div className="mx-auto max-w-7xl space-y-4 p-4 sm:p-6">
                <Skeleton className="h-24"/>
                <Skeleton className="h-40"/>
                <Skeleton className="h-96"/>
            </div>;
    }
    p = detail.pr;
    rv = detail.review;
    live_run = run.current;
    running = bool(live_run and live_run["active"])
        or is_running(pr_id)
        or bool(not live_run and rv and rv.status == "running");
    stages = live_run["stages"]
        if live_run
        else (
            [
                {
                    "key": s.key,
                    "label": s.label,
                    "status": s.status,
                    "detail": s.detail
                } for s in rv.stages
            ]
                if rv
                else []
        );
    findings = detail.findings;
    open_count = len(
        [
            f
            for f in findings
            if f.status == "open"
        ]
    );
    shown = [
        f
        for f in findings
        if (not sev or f.severity == sev)
            and (not cat or f.category == cat)
            and (not status or f.status == status)
    ];
    shown = sorted(
        shown,
        key=lambda (f: any) -> int { return sev_order().index(f.severity) * 100000
            + f.line
            if f.severity in sev_order()
            else 999999; }
    );
    sev_counts = [
        float(
            len(
                [
                    f
                    for f in findings
                    if f.severity == s
                ]
            )
        ) for s in sev_order()
    ];
    cats: list[str] = [];
    for f in findings {
        if f.category not in cats {
            cats.append(f.category);
        }
    }
    active_file = file;
    if not active_file and len(detail.files) > 0 {
        ranked = sorted(
            detail.risks, key=lambda (r: any) -> int { return 0 - r.score; }
        );
        active_file = ranked[0].path if len(ranked) > 0 else detail.files[0].path;
    }
    current = [
        f
        for f in detail.files
        if f.path == active_file
    ];
    file_findings = [
        f
        for f in findings
        if f.path == active_file and f.status != "dismissed"
    ];
    <div className="@container mx-auto max-w-[1400px] p-4 sm:p-6">
        <Link
            to="/reviews"
            className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
        >
            <ArrowLeft className="size-3.5"/>
            Review queue
        </Link>
        <div className="mt-2 flex flex-wrap items-start gap-4">
            <div className="min-w-[min(100%,26rem)] flex-1">
                <div className="flex flex-wrap items-center gap-2">
                    <KindBadge kind={p.kind} number={p.number}/>
                    <VerdictPill
                        verdict={rv.verdict if rv and rv.status == "done" else ""}
                        reviewing={running}
                    />
                    {if rv and rv.status == "done" {
                        <span
                            className="inline-flex items-center gap-1 text-[11px] text-muted-foreground"
                        >
                            <Clock className="size-3"/>
                            {"reviewed " + ago(rv.finished)}
                        </span>
                    }}
                </div>
                <h1
                    className="mt-2 text-xl font-semibold leading-snug tracking-tight sm:text-2xl"
                >
                    {p.title}
                </h1>
                <div
                    className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground"
                >
                    <span className="font-mono">{p.head + " → " + p.base}</span>
                    <span>{p.author}</span>
                    <span className="tabular">
                        <span className="text-[var(--status-good)]">
                            {"+" + fmt_num(p.additions)}
                        </span>{" "}
                        <span className="text-[var(--status-critical)]">
                            {"−" + fmt_num(p.deletions)}
                        </span>
                        {" · " + str(len(detail.files)) + " files"}
                    </span>
                    {if p.url {
                        <a
                            href={p.url}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center gap-1 text-primary hover:underline"
                        >
                            <ExternalLink className="size-3"/>
                            GitHub
                        </a>
                    }}
                </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
                <button
                    type="button"
                    onClick={lambda { ask_copilot(
                        "Walk me through pull request "
                            + pr_id
                            + ": what it changes, the riskiest part, and whether the findings hold up. Show me the code as you go."
                    ); }}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-muted"
                >
                    <Sparkles className="size-4 text-primary"/>
                    Walk me through
                </button>
                {if rv and rv.status == "done" {
                    <button
                        type="button"
                        onClick={do_export}
                        className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-muted"
                    >
                        <FileDown className="size-4"/>
                        Export
                    </button>
                }}
                {if rv and rv.status == "done" and p.kind == "github" {
                    <button
                        type="button"
                        onClick={lambda { publish(
                            "confirm-publish",
                            {"pr_id": pr_id, "number": p.number, "url": p.url}
                        ); }}
                        className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-muted"
                    >
                        <Github className="size-4"/>
                        Publish
                    </button>
                }}
                <button
                    type="button"
                    disabled={running}
                    onClick={kick}
                    className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-60"
                >
                    {(<LoaderCircle className="size-4 animate-spin"/>)
                        if running
                        else (
                            (<RotateCw className="size-4"/>)
                                if rv
                                else (<Play className="size-4"/>)
                        )}{"Reviewing…"
                        if running
                        else ("Re-run review" if rv else "Run review")}
                </button>
            </div>
        </div>
        <div
            className="mt-4 flex gap-1 overflow-x-auto border-b border-border thin-scroll"
        >
            <TabButton
                name="overview"
                label="Overview"
                active={tab == "overview"}
                count={-1}
                onPick={pick_tab}
            />
            <TabButton
                name="files"
                label="Files"
                active={tab == "files"}
                count={len(detail.files)}
                onPick={pick_tab}
            />
            <TabButton
                name="findings"
                label="Findings"
                active={tab == "findings"}
                count={open_count}
                onPick={pick_tab}
            />
            <TabButton
                name="commits"
                label="Commits"
                active={tab == "commits"}
                count={len(detail.commits)}
                onPick={pick_tab}
            />
            <TabButton
                name="history"
                label="History"
                active={tab == "history"}
                count={len(detail.history)}
                onPick={pick_tab}
            />
        </div>
        {if tab == "overview" {
            <div className="@container mt-5 space-y-5">
                {if not rv and not running {
                    <div
                        className="grid-bg relative overflow-hidden rounded-2xl border border-border bg-card p-5 sm:p-6"
                    >
                        <div className="max-w-2xl">
                            <div
                                className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary"
                            >
                                Not reviewed yet
                            </div>
                            <h2 className="mt-1 text-lg font-semibold">
                                Run the eight-stage agentic review
                            </h2>
                            <p className="mt-1 text-sm text-muted-foreground">
                                Deterministic triage scores every file and maps its callers, tests, and co-changing files; a planner assigns lenses; specialist reviewers cover every file in parallel; a cross-file pass hunts for broken callers; an investigator walker lets the model choose which related code to read; an adversarial verifier throws out false positives; and the verdict follows from what survives.
                            </p>
                            <div className="mt-4 flex flex-wrap gap-2">
                                <label
                                    className="flex h-9 min-w-[220px] flex-1 items-center gap-2 rounded-lg border border-border bg-background px-2.5"
                                >
                                    <Target className="size-4 text-muted-foreground"/>
                                    <input
                                        value={focus}
                                        onChange={lambda (e: any) { focus = e.target.value; }}
                                        placeholder="Optional focus, e.g. concurrency, error handling"
                                        className="min-w-0 flex-1 bg-transparent text-sm outline-none"
                                    />
                                </label>
                                <button
                                    type="button"
                                    onClick={kick}
                                    className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground"
                                >
                                    <Play className="size-4"/>
                                    Start review
                                </button>
                            </div>
                        </div>
                    </div>
                }}
                {if rv or running {
                    <Panel
                        title="Review pipeline"
                        subtitle={("Running live · " if running else "")
                            + (
                                (
                                    rv.model
                                    + " · "
                                    + str(rv.llm_calls)
                                    + " model calls · "
                                    + fmt_num(rv.tokens)
                                    + " tokens · $"
                                    + str(round(rv.cost * 1000) / 1000)
                                    + " · "
                                    + str(rv.dropped)
                                    + " rejected by the verifier"
                                )
                                    if rv and rv.status in ("done", "failed")
                                    else "Eight stages, streamed as they happen"
                            )}
                    >
                        <Pipeline stages={stages}/>
                        {if rv and rv.status == "failed" and rv.error {
                            <div className="mt-4 rounded-lg border border-[var(--status-critical)]/40 bg-[var(--status-critical)]/10 px-3 py-2 text-xs">
                                {"Review failed: " + rv.error}
                            </div>
                        }}
                        {if not live_run and rv and len(rv.feed) > 0 {
                            <div
                                className="mt-5 rounded-xl border border-border bg-background/50 p-3"
                            >
                                <div
                                    className="mb-2 text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
                                >
                                    Reviewer activity
                                </div>
                                <div className="max-h-56 space-y-2 overflow-y-auto pr-1 thin-scroll">
                                    {for (i, item) in enumerate(rv.feed[:40]) {
                                        <FeedRow
                                            key={str(i)}
                                            item={{"kind": "file" if item.kind == "investigate" else item.kind, "title": item.title, "detail": item.detail}}
                                        />
                                    }}
                                </div>
                            </div>
                        }}
                        {if live_run and len(live_run["feed"]) > 0 {
                            <div
                                className="mt-5 rounded-xl border border-border bg-background/50 p-3"
                            >
                                <div
                                    className="mb-2 text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
                                >
                                    Reviewer activity
                                </div>
                                <div
                                    className="max-h-56 space-y-2 overflow-y-auto pr-1 thin-scroll"
                                >
                                    {for (i, item) in enumerate(
                                        live_run["feed"][:40]
                                    ) {
                                        <FeedRow
                                            key={str(len(live_run["feed"]) - i)}
                                            item={item}
                                        />
                                    }}
                                </div>
                            </div>
                        }}
                    </Panel>
                }}
                {if rv and rv.status == "done" {
                    <div className="grid gap-5 @3xl:grid-cols-[minmax(0,1fr)_300px]">
                        <Panel
                            title="Review summary"
                            subtitle={"Review "
                                + rv.id
                                + (" · focus: " + rv.focus if rv.focus else "")}
                        >
                            {if rv.intent {
                                <div
                                    className="mb-3 rounded-lg bg-muted/50 px-3 py-2 text-sm"
                                >
                                    <span className="font-medium">Intent. </span>
                                    <span className="text-muted-foreground">
                                        {rv.intent}
                                    </span>
                                </div>
                            }}
                            <Markdown text={rv.summary}/>
                            <div className="mt-4 grid gap-4 @xl:grid-cols-2">
                                {if len(rv.concerns) > 0 {
                                    <div>
                                        <div
                                            className="mb-1.5 text-xs font-semibold uppercase tracking-wider text-[var(--status-serious)]"
                                        >
                                            Concerns
                                        </div>
                                        <ul className="space-y-1.5 text-sm">
                                            {for (i, c) in enumerate(rv.concerns) {
                                                <li key={str(i)} className="flex gap-2">
                                                    <span
                                                        className="mt-2 inline-block size-1.5 shrink-0 rounded-full bg-[var(--status-serious)]"
                                                    ></span>
                                                    {c}
                                                </li>
                                            }}
                                        </ul>
                                    </div>
                                }}
                                {if len(rv.highlights) > 0 {
                                    <div>
                                        <div
                                            className="mb-1.5 text-xs font-semibold uppercase tracking-wider text-[var(--status-good)]"
                                        >
                                            Done well
                                        </div>
                                        <ul className="space-y-1.5 text-sm">
                                            {for (i, c) in enumerate(rv.highlights) {
                                                <li key={str(i)} className="flex gap-2">
                                                    <span
                                                        className="mt-2 inline-block size-1.5 shrink-0 rounded-full bg-[var(--status-good)]"
                                                    ></span>
                                                    {c}
                                                </li>
                                            }}
                                        </ul>
                                    </div>
                                }}
                            </div>
                            {if len(rv.tests) > 0 {
                                <div className="mt-4">
                                    <div
                                        className="mb-1.5 text-xs font-semibold uppercase tracking-wider text-muted-foreground"
                                    >
                                        Suggested tests
                                    </div>
                                    <ul
                                        className="space-y-1 text-sm text-muted-foreground"
                                    >
                                        {for (i, t) in enumerate(rv.tests) {
                                            <li key={str(i)}>{"• " + t}</li>
                                        }}
                                    </ul>
                                </div>
                            }}
                        </Panel>
                        <div className="space-y-5">
                            <Panel title="Merge risk">
                                <div className="flex items-center justify-center">
                                    <Gauge value={rv.risk} size={190}/>
                                </div>
                            </Panel>
                            <Panel
                                title="Findings"
                                subtitle={str(len(findings))
                                    + " total · "
                                    + str(open_count)
                                    + " open"}
                            >
                                {if len(findings) == 0 {
                                    <p className="text-sm text-muted-foreground">
                                        Nothing survived verification. Clean change.
                                    </p>
                                } else {
                                    <Donut
                                        labels={[
                                            "Critical",
                                            "High",
                                            "Medium",
                                            "Low",
                                            "Info"
                                        ]}
                                        values={sev_counts}
                                        colors={[sev_color(s) for s in sev_order()]}
                                        center={str(len(findings))}
                                        sub="findings"
                                        size={130}
                                    />
                                } }
                            </Panel>
                        </div>
                    </div>
                }}
                {if rv and len(rv.costs) > 0 {
                    <CostPanel rv={rv}/>
                }}
                {if rv and rv.status == "done" and len(rv.walkthrough) > 0 {
                    <Panel
                        title="Walkthrough"
                        subtitle="Every changed file, its triage risk, and what the specialist reviewer saw"
                    >
                        <div className="overflow-x-auto thin-scroll">
                            <table className="w-full text-sm">
                                <thead
                                    className="text-left text-[11px] uppercase tracking-wider text-muted-foreground"
                                >
                                    <tr>
                                        <th className="pb-2 pr-3 font-medium">File</th>
                                        <th className="pb-2 pr-3 font-medium">Risk</th>
                                        <th className="pb-2 pr-3 font-medium">
                                            Lenses
                                        </th>
                                        <th className="pb-2 pr-3 font-medium">Change</th>
                                        <th className="pb-2 font-medium">Context read</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {for n in rv.walkthrough[:60] {
                                        <tr
                                            key={n.path}
                                            className="border-t border-border/60 align-top"
                                        >
                                            <td className="py-2 pr-3">
                                                <button
                                                    type="button"
                                                    onClick={lambda { nav(
                                                        "/reviews/"
                                                            + pr_id
                                                            + "?tab=files&file="
                                                            + encodeURIComponent(n.path)
                                                    ); }}
                                                    className="text-left font-mono text-xs text-primary hover:underline"
                                                >
                                                    {base_name(n.path)}
                                                </button>
                                                <div
                                                    className="max-w-[260px] truncate font-mono text-[10px] text-muted-foreground"
                                                >
                                                    {dir_name(n.path)}
                                                </div>
                                            </td>
                                            <td className="py-2 pr-3">
                                                <RiskMeter score={n.risk} width="w-12"/>
                                            </td>
                                            <td className="py-2 pr-3">
                                                <div
                                                    className="flex max-w-[180px] flex-wrap gap-1"
                                                >
                                                    {for l in n.lenses[:3] {
                                                        <span
                                                            key={l}
                                                            className="rounded bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground"
                                                        >
                                                            {l}
                                                        </span>
                                                    }}
                                                    {if len(n.lenses) == 0 {
                                                        <span
                                                            className="text-[10px] text-muted-foreground"
                                                        >
                                                            skimmed
                                                        </span>
                                                    }}
                                                </div>
                                            </td>
                                            <td
                                                className="py-2 text-xs leading-relaxed text-muted-foreground"
                                            >
                                                {n.summary
                                                    or ("Skipped (" + n.status + ")" if n.status in ("skipped", "failed") else "Not reviewed.")}
                                            </td>
                                            <td className="py-2 font-mono text-[10px] text-muted-foreground">
                                                {if len(n.read) > 0 {
                                                    <span className="text-primary">{", ".join([base_name(x) for x in n.read])}</span>
                                                } elif len(n.related) > 0 {
                                                    <span>{str(len(n.related)) + " linked"}</span>
                                                } else {
                                                    <span>—</span>
                                                } }
                                            </td>
                                        </tr>
                                    }}
                                </tbody>
                            </table>
                        </div>
                    </Panel>
                }}
                <Panel
                    title="Triage risk by file"
                    subtitle="Deterministic, computed before any model call: size, history hotspots, sensitive paths, static patterns"
                >
                    <HBars
                        labels={[base_name(r.path) for r in detail.risks[:12]]}
                        sub={[", ".join(r.signals[:3]) for r in detail.risks[:12]]}
                        values={[float(r.score) for r in detail.risks[:12]]}
                        colors={[risk_color(r.score) for r in detail.risks[:12]]}
                        onPick={lambda (i: int) { nav(
                            "/reviews/"
                                + pr_id
                                + "?tab=files&file="
                                + encodeURIComponent(detail.risks[i].path)
                        ); }}
                    />
                </Panel>
            </div>
        } elif tab == "files" {
            <div className="mt-5 grid gap-4 @4xl:grid-cols-[260px_minmax(0,1fr)]">
                <div
                    className="@4xl:sticky @4xl:top-4 @4xl:max-h-[calc(100dvh-180px)] @4xl:overflow-y-auto thin-scroll"
                >
                    <FileList
                        files={detail.files}
                        risks={detail.risks}
                        findings={findings}
                        active={active_file}
                        onPick={lambda (path: str) { nav(
                            "/reviews/"
                                + pr_id
                                + "?tab=files&file="
                                + encodeURIComponent(path),
                            {"replace": True}
                        ); }}
                    />
                </div>
                <div className="min-w-0">
                    {if len(current) > 0 {
                        <FileDiffView
                            key={active_file}
                            pr_id={pr_id}
                            f={current[0]}
                            findings={file_findings}
                            focusLine={line}
                            flashKey={flashKey}
                            onChanged={load}
                        />
                    } else {
                        <Empty title="No file selected"/>
                    } }
                </div>
            </div>
        } elif tab == "findings" {
            <div className="mt-5">
                <div className="mb-4 flex flex-wrap items-center gap-2">
                    <div className="flex flex-wrap gap-1">
                        <button
                            type="button"
                            onClick={lambda { sev = ""; }}
                            className={"rounded-full border px-2.5 py-1 text-xs "
                                + (
                                    "border-primary bg-primary/10 text-foreground"
                                        if not sev
                                        else "border-border text-muted-foreground"
                                )}
                        >
                            All severities
                        </button>
                        {for (i, s) in enumerate(sev_order()) {
                            <button
                                key={s}
                                type="button"
                                onClick={lambda { sev = "" if sev == s else s; }}
                                className={"inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-xs "
                                    + (
                                        "border-primary bg-primary/10 text-foreground"
                                            if sev == s
                                            else "border-border text-muted-foreground"
                                    )}
                            >
                                <span
                                    className="inline-block size-2 rounded-full"
                                    style={{"background": sev_color(s)}}
                                ></span>
                                {s + " " + str(int(sev_counts[i]))}
                            </button>
                        }}
                    </div>
                    <select
                        value={cat}
                        onChange={lambda (e: any) { cat = e.target.value; }}
                        className="h-8 rounded-lg border border-border bg-background px-2 text-xs"
                        aria-label="Category"
                    >
                        <option value="">All categories</option>
                        {for c in cats {
                            <option key={c} value={c}>{c}</option>
                        }}
                    </select>
                    <select
                        value={status}
                        onChange={lambda (e: any) { status = e.target.value; }}
                        className="h-8 rounded-lg border border-border bg-background px-2 text-xs"
                        aria-label="Status"
                    >
                        <option value="open">Open</option>
                        <option value="resolved">Resolved</option>
                        <option value="dismissed">Dismissed</option>
                        <option value="">Any status</option>
                    </select>
                    <span className="ml-auto text-xs text-muted-foreground">
                        {str(len(shown)) + " shown"}
                    </span>
                </div>
                {if len(shown) == 0 {
                    <Empty
                        title="No findings match"
                        hint={"Nothing here. "
                            + (
                                "Run a review first."
                                    if not rv
                                    else "Try another filter."
                            )}
                    />
                } else {
                    <div className="grid gap-3 xl:grid-cols-2">
                        {for f in shown {
                            <FindingCard
                                key={f.id}
                                f={f}
                                onChanged={load}
                                onJump={jump}
                            />
                        }}
                    </div>
                } }
            </div>
        } elif tab == "commits" {
            <div className="mt-5">
                {if len(detail.commits) == 0 {
                    <Empty
                        title="No commit list"
                        hint="Worktree and GitHub pull requests show the diff only."
                    />
                } else {
                    <Panel bodyClass="pt-2">
                        {for c in detail.commits {
                            <div
                                key={c.sha}
                                className="flex items-start gap-3 border-b border-border/60 py-2.5 last:border-0"
                            >
                                <GitCommitHorizontal
                                    className="mt-0.5 size-4 text-muted-foreground"
                                />
                                <div className="min-w-0 flex-1">
                                    <div className="text-sm">{c.subject}</div>
                                    <div
                                        className="font-mono text-[11px] text-muted-foreground"
                                    >
                                        {c.sha + " · " + c.author + " · " + ago(c.ts)}
                                    </div>
                                </div>
                            </div>
                        }}
                    </Panel>
                } }
            </div>
        } else {
            <div className="mt-5">
                {if len(detail.history) == 0 {
                    <Empty title="No reviews yet"/>
                } else {
                    <Panel bodyClass="pt-2">
                        {for h in detail.history {
                            <button
                                key={h.id}
                                type="button"
                                onClick={lambda { nav("/reviews/" + pr_id + "?tab=overview&review=" + h.id); }}
                                className={"flex w-full items-center gap-3 border-b border-border/60 py-2.5 text-left last:border-0 hover:bg-muted/40 "
                                    + ("bg-primary/5" if rv and rv.id == h.id else "")}
                            >
                                <span className="font-mono text-xs">{h.id}</span>
                                <VerdictPill
                                    verdict={h.verdict if h.status == "done" else ""}
                                    reviewing={h.status == "running"}
                                />
                                <RiskMeter
                                    score={h.risk if h.status == "done" else -1}
                                />
                                <span className="text-xs text-muted-foreground">
                                    {str(h.findings) + " findings · by " + h.trigger}
                                </span>
                                <span className="ml-auto text-xs text-muted-foreground tabular">
                                    {("$" + str(round(h.cost * 1000) / 1000) + " · " if h.cost else "") + ago(h.started)}
                                </span>
                            </button>
                        }}
                    </Panel>
                } }
            </div>
        }    }
    </div>
}
