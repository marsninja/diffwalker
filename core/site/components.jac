import from "@jac/runtime" { Link }
import from "lucide-react" {
    OctagonAlert,
    TriangleAlert,
    CircleAlert,
    Info,
    CircleDot,
    GitBranch,
    Github,
    PencilLine,
    CircleCheck,
    MessageSquare,
    CircleX,
    LoaderCircle
}

def:pub Panel(
    title: str = "",
    subtitle: str = "",
    action: any = None,
    children: any = None,
    className: str = "",
    bodyClass: str = "",
    id: str = ""
) -> JsxElement {
    <section
        id={id}
        className={"min-w-0 rounded-2xl border border-border bg-card/80 " + className}
    >
        {if title or action {
            <div className="flex items-start gap-3 px-4 pt-4 sm:px-5">
                <div className="min-w-0">
                    {if title {
                        <h2 className="text-sm font-semibold tracking-tight">
                            {title}
                        </h2>
                    }}
                    {if subtitle {
                        <p className="mt-0.5 text-xs text-muted-foreground">
                            {subtitle}
                        </p>
                    }}
                </div>
                {if action {
                    <div className="ml-auto shrink-0">{action}</div>
                }}
            </div>
        }}
        <div className={"p-4 sm:p-5 " + bodyClass}>{children}</div>
    </section>
}

def:pub StatTile(
    label: str, value: str, hint: str = "", accent: str = "", children: any = None
) -> JsxElement {
    <div
        className="relative overflow-hidden rounded-2xl border border-border bg-card/80 p-4"
    >
        <div
            className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
        >
            {label}
        </div>
        <div
            className="mt-1.5 text-2xl font-semibold tracking-tight"
            style={{"color": accent} if accent else {}}
        >
            {value}
        </div>
        {if hint {
            <div className="mt-0.5 truncate text-xs text-muted-foreground">{hint}</div>
        }}
        {if children {
            <div className="mt-2">{children}</div>
        }}
    </div>
}

def:pub SevIcon(sev: str, className: str = "size-3.5") -> JsxElement {
    color = sev_color(sev);
    if sev == "critical" {
        return <OctagonAlert className={className} style={{"color": color}}/>;
    }
    if sev == "high" {
        return <TriangleAlert className={className} style={{"color": color}}/>;
    }
    if sev == "medium" {
        return <CircleAlert className={className} style={{"color": color}}/>;
    }
    if sev == "low" {
        return <CircleDot className={className} style={{"color": color}}/>;
    }
    return <Info className={className} style={{"color": color}}/>;
}

def:pub SevBadge(sev: str) -> JsxElement {
    <span
        className="inline-flex items-center gap-1 rounded-full border px-1.5 py-0.5 text-[10.5px] font-medium"
        style={{
            "borderColor": "color-mix(in oklab, "
                + sev_color(sev)
                + " 45%, transparent)",
            "background": "color-mix(in oklab, " + sev_color(sev) + " 12%, transparent)"
        }}
    >
        <SevIcon sev={sev} className="size-3"/>
        {SEV_LABEL[sev] or sev}
    </span>
}

def:pub VerdictPill(verdict: str, reviewing: bool = False) -> JsxElement {
    if reviewing {
        return
            <span
                className="inline-flex items-center gap-1 rounded-full bg-primary/15 px-2 py-0.5 text-[11px] font-medium text-primary"
            >
                <LoaderCircle className="size-3 animate-spin"/>
                Reviewing
            </span>;
    }
    if not verdict {
        return
            <span
                className="inline-flex items-center rounded-full border border-dashed border-border px-2 py-0.5 text-[11px] text-muted-foreground"
            >
                Not reviewed
            </span>;
    }
    color = verdict_color(verdict);
    <span
        className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium"
        style={{
            "background": "color-mix(in oklab, " + color + " 16%, transparent)",
            "color": color
        }}
    >
        {if verdict == "approve" {
            <CircleCheck className="size-3"/>
        } elif verdict == "request_changes" {
            <CircleX className="size-3"/>
        } else {
            <MessageSquare className="size-3"/>
        }  }
        {verdict_label(verdict)}
    </span>
}

def:pub RiskMeter(score: int, width: str = "w-16") -> JsxElement {
    if score < 0 {
        return <span className="text-xs text-muted-foreground">–</span>;
    }
    <span
        className="inline-flex items-center gap-1.5"
        title={risk_label(score) + " risk"}
    >
        <span
            className={"relative h-1.5 overflow-hidden rounded-full bg-muted " + width}
        >
            <span
                className="absolute inset-y-0 left-0 rounded-full"
                style={{
                    "width": str(max(4, score)) + "%",
                    "background": risk_color(score)
                }}
            ></span>
        </span>
        <span className="text-xs font-medium tabular">{str(score)}</span>
    </span>
}

def:pub KindBadge(kind: str, number: int = 0) -> JsxElement {
    if kind == "github" {
        return
            <span
                className="inline-flex items-center gap-1 rounded-md bg-muted px-1.5 py-0.5 text-[10.5px] text-muted-foreground"
            >
                <Github className="size-3"/>
                {"#" + str(number)}
            </span>;
    }
    if kind == "worktree" {
        return
            <span
                className="inline-flex items-center gap-1 rounded-md bg-[var(--status-warning)]/15 px-1.5 py-0.5 text-[10.5px] text-[var(--status-warning)]"
            >
                <PencilLine className="size-3"/>
                worktree
            </span>;
    }
    <span
        className="inline-flex items-center gap-1 rounded-md bg-muted px-1.5 py-0.5 text-[10.5px] text-muted-foreground"
    >
        <GitBranch className="size-3"/>
        branch
    </span>
}

def:pub PRLine(row: any, onReview: any = None, compact: bool = False) -> JsxElement {
    p = row.pr;
    <div
        className="group flex items-center gap-3 rounded-xl px-2 py-2 hover:bg-muted/50"
    >
        <Link to={"/reviews/" + p.id} className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
                <KindBadge kind={p.kind} number={p.number}/>
                <span className="truncate text-sm font-medium">{p.title}</span>
            </div>
            <div
                className="mt-0.5 flex items-center gap-2 truncate text-[11px] text-muted-foreground"
            >
                <span className="truncate font-mono">{p.head}</span>
                <span>·</span>
                <span className="shrink-0">{p.author}</span>
                {if not compact {
                    <span className="shrink-0">{"· " + ago_iso(p.updated)}</span>
                }}
                <span className="shrink-0 tabular">
                    <span className="text-[var(--status-good)]">
                        {"+" + fmt_num(p.additions)}
                    </span>{" "}
                    <span className="text-[var(--status-critical)]">
                        {"−" + fmt_num(p.deletions)}
                    </span>
                </span>
            </div>
        </Link>
        <div className="hidden shrink-0 sm:block">
            <RiskMeter score={row.risk}/>
        </div>
        <div className="shrink-0">
            <VerdictPill verdict={row.verdict} reviewing={row.reviewing}/>
        </div>
        {if onReview and not row.reviewing {
            <button
                type="button"
                onClick={lambda { onReview(p.id); }}
                className="hidden shrink-0 rounded-md border border-border px-2 py-1 text-[11px] font-medium text-muted-foreground hover:border-primary/50 hover:text-foreground group-hover:inline-block"
            >
                Review
            </button>
        }}
    </div>
}

def:pub Skeleton(className: str = "h-24") -> JsxElement {
    <div className={"shimmer rounded-xl bg-muted/40 " + className}></div>
}

def:pub Empty(title: str, hint: str = "", children: any = None) -> JsxElement {
    <div
        className="grid place-items-center rounded-xl border border-dashed border-border px-4 py-10 text-center"
    >
        <div className="text-sm font-medium">{title}</div>
        {if hint {
            <p className="mt-1 max-w-sm text-xs text-muted-foreground">{hint}</p>
        }}
        {if children {
            <div className="mt-3">{children}</div>
        }}
    </div>
}

def:pub PageHeader(
    eyebrow: str, title: str, subtitle: str = "", children: any = None
) -> JsxElement {
    <div className="flex flex-wrap items-end gap-4">
        <div className="min-w-0">
            <div
                className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary"
            >
                {eyebrow}
            </div>
            <h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-[28px]">
                {title}
            </h1>
            {if subtitle {
                <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
                    {subtitle}
                </p>
            }}
        </div>
        {if children {
            <div className="ml-auto flex flex-wrap items-center gap-2">{children}</div>
        }}
    </div>
}
