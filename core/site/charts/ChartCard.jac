import from "lucide-react" {
    Pin,
    PinOff,
    BarChart3,
    Table2,
    Workflow,
    PieChart,
    LineChart as LineIcon,
}

def kind_icon(kind: str) -> any {
    if kind == "table" {
        return Table2;
    }
    if kind == "mermaid" {
        return Workflow;
    }
    if kind == "donut" {
        return PieChart;
    }
    if kind in ("line", "area") {
        return LineIcon;
    }
    return BarChart3;
}

"""The body of a card of `kind`. `spec` is the card's parsed JSON: `labels` and
`series[{name, values}]` for a chart, `columns` and `rows` for a table, `code` for a diagram;
a key it lacks reads as `None`."""
def:pub ChartBody(kind: str, spec: any) -> JsxElement {
    labels: list[str] = [str(l) for l in (spec["labels"] or [])];
    series = spec["series"] or [];
    if kind == "mermaid" {
        return <MermaidDiagram code={spec["code"] or ""} />;
    }
    if kind == "table" {
        cols = spec["columns"] or [];
        rows = spec["rows"] or [];
        return <div className="overflow-x-auto thin-scroll rounded-lg border border-border">
            <table className="w-full text-xs">
                <thead className="bg-muted/50 text-muted-foreground">
                    <tr>
                        {
                            for (ci, c) in enumerate(cols) {
                                <th key={str(ci)} className="px-2.5 py-1.5 text-left font-medium">
                                    {c}
                                </th>
                            }
                        }
                    </tr>
                </thead>
                <tbody>
                    {
                        for (ri, r) in enumerate(rows) {
                            <tr key={str(ri)} className="border-t border-border">
                                {
                                    for (ci, c) in enumerate(r) {
                                        <td
                                            key={str(ci)}
                                            className={"px-2.5 py-1.5 align-top " + ("font-mono text-[11px]" if ci == 0 else "tabular")}
                                        >{str(c)}</td>
                                    }
                                }
                            </tr>
                        }
                    }
                </tbody>
            </table>
        </div>;
    }
    if len(series) == 0 {
        return <p className="text-xs text-muted-foreground">No data.</p>;
    }
    colored = [
        Series(
            name=str(s["name"] or ""),
            values=[float(v or 0) for v in s["values"]],
            color=series_color(i),
        )
        for (i, s) in enumerate(series)
    ];
    first: list[float] = [float(v or 0) for v in series[0]["values"]];
    sev_names = ["critical", "high", "medium", "low", "info"];
    by_severity = len(labels) > 0
        and len([l for l in labels if l.lower() in sev_names]) == len(labels);
    palette = [sev_color(l.lower()) for l in labels]
        if by_severity
        else [series_color(i) for (i, _) in enumerate(labels)];
    if kind == "donut" {
        return <Donut
            labels={labels}
            values={first}
            colors={palette}
            size={150}
            center={str(len(labels))}
            sub="parts"
        />;
    }
    if kind == "hbar" {
        return <HBars
            labels={labels}
            values={first}
            colors={palette if by_severity else [series_color(0) for _ in labels]}
        />;
    }
    if kind in ("line", "area") {
        return <LineChart labels={labels} series={colored} area={kind == "area"} height={200} />;
    }
    if kind == "stacked" or len(colored) > 1 {
        return <StackedBars labels={labels} series={colored} height={200} />;
    }
    return <BarChart labels={labels} values={first} color={series_color(0)} height={190} />;
}

"""A card Copilot rendered: a chart, a table or a diagram, by `kind`, with `spec` its JSON text.
`onPin` shows a button that pins a card not yet pinned, `onUnpin` one that unpins it."""
def:pub ChartCard(
    title: str,
    kind: str,
    spec: str,
    caption: str = "",
    pinned: bool = False,
    created: float = 0.0,
    onPin: Callable[[], Coroutine[any, any, None]] | None = None,
    onUnpin: Callable[[], Coroutine[any, any, None]] | None = None,
    compact: bool = False,
) -> JsxElement {
    parsed: any = JSON.parse("{}");
    try {
        parsed = JSON.parse(spec or "{}");
    } except Exception {
        parsed = JSON.parse("{}");
    }
    Icon = kind_icon(kind);
    return <div
        className={"fade-up rounded-xl border border-border bg-card " + ("p-3" if compact else "p-4")}
    >
        <div className="mb-3 flex items-start gap-2">
            <span
                className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-md bg-primary/15 text-primary"
            ><Icon className="size-3.5" /></span>
            <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{title}</div>
                {
                    if caption {
                        <div className="mt-0.5 text-xs leading-relaxed text-muted-foreground">
                            {caption}
                        </div>
                    }
                }
            </div>
            {
                if onPin and not pinned {
                    <button
                        type="button"
                        className="inline-flex items-center gap-1 rounded-md border border-border px-1.5 py-0.5 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                        onClick={lambda { onPin() }}
                    ><Pin className="size-3" />
                    Pin
                </button>
                } elif onUnpin {
                    <button
                        type="button"
                        title="Unpin from board"
                        className="rounded-md p-1 text-muted-foreground hover:bg-muted hover:text-foreground"
                        onClick={lambda { onUnpin() }}
                    ><PinOff className="size-3.5" /></button>
                } elif pinned {
                    <span className="inline-flex items-center gap-1 text-[11px] text-primary"><Pin
                        className="size-3"
                    />
                    Pinned
                </span>
                }
            }
        </div>
        <ChartBody kind={kind} spec={parsed} />
        {
            if not compact and created {
                <div className="mt-3 text-[10px] uppercase tracking-wider text-muted-foreground/70">
                    {"Copilot · " + ago(created)}
                </div>
            }
        }
    </div>;
}
