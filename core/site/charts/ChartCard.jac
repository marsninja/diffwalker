import from "lucide-react" {
    Pin,
    PinOff,
    BarChart3,
    Table2,
    Workflow,
    PieChart,
    LineChart as LineIcon
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

def:pub ChartBody(kind: str, spec: any) -> JsxElement {
    labels = spec["labels"] or [];
    series = spec["series"] or [];
    if kind == "mermaid" {
        return <MermaidDiagram code={spec["code"] or ""}/>;
    }
    if kind == "table" {
        cols = spec["columns"] or [];
        rows = spec["rows"] or [];
        return
            <div
                className="overflow-x-auto thin-scroll rounded-lg border border-border"
            >
                <table className="w-full text-xs">
                    <thead className="bg-muted/50 text-muted-foreground">
                        <tr>
                            {for (ci, c) in enumerate(cols) {
                                <th
                                    key={str(ci)}
                                    className="px-2.5 py-1.5 text-left font-medium"
                                >
                                    {c}
                                </th>
                            }}
                        </tr>
                    </thead>
                    <tbody>
                        {for (ri, r) in enumerate(rows) {
                            <tr key={str(ri)} className="border-t border-border">
                                {for (ci, c) in enumerate(r) {
                                    <td
                                        key={str(ci)}
                                        className={"px-2.5 py-1.5 align-top "
                                            + (
                                                "font-mono text-[11px]"
                                                    if ci == 0
                                                    else "tabular"
                                            )}
                                    >
                                        {str(c)}
                                    </td>
                                }}
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>;
    }
    if len(series) == 0 {
        return <p className="text-xs text-muted-foreground">No data.</p>;
    }
    colored = [
        {
            "name": s["name"],
            "values": [float(v or 0) for v in s["values"]],
            "color": series_color(i)
        } for (i, s) in enumerate(series)
    ];
    first: list[float] = [float(v or 0) for v in series[0]["values"]];
    sev_names = ["critical", "high", "medium", "low", "info"];
    by_severity = len(labels) > 0
        and len([l for l in labels if str(l).lower() in sev_names]) == len(labels);
    palette = [sev_color(str(l).lower()) for l in labels]
        if by_severity
        else [series_color(i) for (i, _) in enumerate(labels)];
    if kind == "donut" {
        return
            <Donut
                labels={labels}
                values={first}
                colors={palette}
                size={150}
                center={str(len(labels))}
                sub="parts"
            />;
    }
    if kind == "hbar" {
        return
            <HBars
                labels={labels}
                values={first}
                colors={palette if by_severity else [series_color(0) for _ in labels]}
            />;
    }
    if kind in ("line", "area") {
        return
            <LineChart
                labels={labels}
                series={colored}
                area={kind == "area"}
                height={200}
            />;
    }
    if kind == "stacked" or len(colored) > 1 {
        return <StackedBars labels={labels} series={colored} height={200}/>;
    }
    return
        <BarChart labels={labels} values={first} color={series_color(0)} height={190}/>;
}

def:pub ChartCard(
    card: any, onPin: any = None, onUnpin: any = None, compact: bool = False
) -> JsxElement {
    spec: any = {};
    try {
        spec = JSON.parse(card.spec or "{}");
    } except Exception {
        spec = {};
    }
    Icon = kind_icon(card.kind);
    <div
        className={"fade-up rounded-xl border border-border bg-card "
            + ("p-3" if compact else "p-4")}
    >
        <div className="mb-3 flex items-start gap-2">
            <span
                className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-md bg-primary/15 text-primary"
            >
                <Icon className="size-3.5"/>
            </span>
            <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{card.title}</div>
                {if card.caption {
                    <div
                        className="mt-0.5 text-xs leading-relaxed text-muted-foreground"
                    >
                        {card.caption}
                    </div>
                }}
            </div>
            {if onPin and not card.pinned {
                <button
                    type="button"
                    className="inline-flex items-center gap-1 rounded-md border border-border px-1.5 py-0.5 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                    onClick={lambda { onPin(card); }}
                >
                    <Pin className="size-3"/>
                    Pin
                </button>
            } elif onUnpin {
                <button
                    type="button"
                    title="Unpin from board"
                    className="rounded-md p-1 text-muted-foreground hover:bg-muted hover:text-foreground"
                    onClick={lambda { onUnpin(card); }}
                >
                    <PinOff className="size-3.5"/>
                </button>
            } elif card.pinned {
                <span
                    className="inline-flex items-center gap-1 text-[11px] text-primary"
                >
                    <Pin className="size-3"/>
                    Pinned
                </span>
            }  }
        </div>
        <ChartBody kind={card.kind} spec={spec}/>
        {if not compact and card.created {
            <div
                className="mt-3 text-[10px] uppercase tracking-wider text-muted-foreground/70"
            >
                {"Copilot · " + ago(card.created)}
            </div>
        }}
    </div>
}
