impl default_stages -> list[StageState] {
    return [
        StageState(key=k[0], label=k[1], status="pending", detail="")
        for k in [
            ["ingest", "Ingest diff"],
            ["triage", "Risk triage"],
            ["plan", "Plan review"],
            ["review", "Specialist lenses"],
            ["cross", "Cross-file analysis"],
            ["investigate", "Investigate context"],
            ["verify", "Adversarial verify"],
            ["synthesize", "Synthesize verdict"],
        ]
    ];
}

impl StatusGlyph(status: str) -> JsxElement {
    if status == "running" {
        return <LoaderCircle className="size-3.5 animate-spin text-primary" />;
    }
    if status == "done" {
        return <Check className="size-3.5 text-[var(--status-good)]" />;
    }
    if status == "failed" {
        return <X className="size-3.5 text-[var(--status-critical)]" />;
    }
    if status == "skipped" {
        return <Minus className="size-3.5 text-muted-foreground" />;
    }
    return <span
        className="inline-block size-2 rounded-full border border-muted-foreground/50"
    ></span>;
}

impl StageNode(stage: StageState, index: int, last: bool) -> JsxElement {
    meta = STAGE_META.get(stage.key, StageMeta(icon=Sparkles, hint=""));
    Icon = meta.icon;
    running = stage.status == "running";
    done = stage.status == "done";
    return <div className="relative flex min-w-0 flex-1 flex-col">
        <div className="flex items-center">
            <span
                className={"relative z-10 grid size-9 shrink-0 place-items-center rounded-xl border transition-all duration-500 " + ("glow-ring border-primary bg-primary/20 text-primary" if running else ("border-[var(--status-good)]/50 bg-[var(--status-good)]/10 text-[var(--status-good)]" if done else ("border-border bg-muted/40 text-muted-foreground" if stage.status != "failed" else "border-[var(--status-critical)]/50 text-[var(--status-critical)]")))}
            ><Icon className="size-4" /></span>
            {
                if not last {
                    <svg
                        className="mx-1 h-2 min-w-0 flex-1"
                        preserveAspectRatio="none"
                        viewBox="0 0 100 2"
                    >
                        <line
                            x1="0"
                            y1="1"
                            x2="100"
                            y2="1"
                            stroke={"var(--status-good)" if done else ("var(--primary)" if running else "var(--border)")}
                            strokeWidth="2"
                            className={"dash-flow" if running else ""}
                            vectorEffect="non-scaling-stroke"
                        />
                    </svg>
                }
            }
        </div>
        <div className="mt-2 pr-2">
            <div className="flex items-center gap-1.5 text-xs font-medium">
                <StatusGlyph status={stage.status} />
                <span className="truncate">{str(index + 1) + ". " + stage.label}</span>
            </div>
            <div
                className="mt-0.5 line-clamp-3 text-[11px] leading-snug text-muted-foreground"
                title={stage.detail or meta.hint}
            >{stage.detail or meta.hint}</div>
        </div>
    </div>;
}

impl Pipeline(stages: list[StageState]) -> JsxElement {
    rows = stages if len(stages) > 0 else default_stages();
    return <div className="overflow-x-auto thin-scroll">
        <div className="flex min-w-[940px] gap-0">
            {
                for (i, s) in enumerate(rows) {
                    <StageNode key={s.key} stage={s} index={i} last={i == len(rows) - 1} />
                }
            }
        </div>
    </div>;
}
