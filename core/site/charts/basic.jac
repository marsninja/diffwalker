glob TAU: float = 6.283185307179586;

def:pub vmax(xs: list[float]) -> float {
    m = 0.0;
    for x in xs {
        if float(x or 0) > m {
            m = float(x or 0);
        }
    }
    return m;
}

def:pub nice_max(v: float) -> float {
    if v <= 0 {
        return 1;
    }
    mag = Math.pow(10, Math.floor(Math.log10(v)));
    for step in [1, 2, 2.5, 5, 10] {
        if step * mag >= v {
            return step * mag;
        }
    }
    return 10 * mag;
}

def:pub bar_path(x: float, y: float, w: float, h: float, r: float) -> str {
    if h <= 0 {
        return "";
    }
    rr = Math.min(r, w / 2, h);
    return "M"
        + str(x)
        + ","
        + str(y + h)
        + " L"
        + str(x)
        + ","
        + str(y + rr)
        + " Q"
        + str(x)
        + ","
        + str(y)
        + " "
        + str(x + rr)
        + ","
        + str(y)
        + " L"
        + str(x + w - rr)
        + ","
        + str(y)
        + " Q"
        + str(x + w)
        + ","
        + str(y)
        + " "
        + str(x + w)
        + ","
        + str(y + rr)
        + " L"
        + str(x + w)
        + ","
        + str(y + h)
        + " Z";
}

def:pub Tooltip(tip: any) -> JsxElement {
    if not tip {
        return <span></span>;
    }
    left = str(tip["x"]) + "%";
    top = str(tip["y"]) + "%";
    flip = tip["x"] > 62;
    <div
        className="pointer-events-none absolute z-20 min-w-[120px] max-w-[260px] rounded-lg border border-border bg-popover/95 px-2.5 py-1.5 text-xs shadow-xl backdrop-blur"
        style={{
            "left": left,
            "top": top,
            "transform": "translate("
                + ("-100%" if flip else "0")
                + ", -110%) translateX("
                + ("-8px" if flip else "8px")
                + ")"
        }}
    >
        <div className="font-medium text-foreground">{tip["title"]}</div>
        {for (i, row) in enumerate(tip["lines"]) {
            <div
                key={str(i)}
                className="mt-0.5 flex items-center gap-1.5 text-muted-foreground tabular"
            >
                {if row["color"] {
                    <span
                        className="inline-block size-2 rounded-full"
                        style={{"background": row["color"]}}
                    ></span>
                }}
                <span className="truncate">{row["label"]}</span>
                <span className="ml-auto pl-3 font-medium text-foreground">
                    {row["value"]}
                </span>
            </div>
        }}
    </div>
}

def:pub Legend(items: list[any], className: str = "") -> JsxElement {
    <div
        className={"flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground "
            + className}
    >
        {for (i, it) in enumerate(items) {
            <span key={str(i)} className="inline-flex items-center gap-1.5">
                <span
                    className="inline-block size-2.5 rounded-[3px]"
                    style={{"background": it["color"]}}
                ></span>
                {it["name"]}
            </span>
        }}
    </div>
}

def:pub BarChart(
    labels: list[str],
    values: list[float],
    color: str = "var(--series-1)",
    height: int = 180,
    unit: str = "",
    tick_every: int = 0
) -> JsxElement {
    has tip: any = None,
        hover: int = -1;
    W = 520;
    H = height;
    padL = 34;
    padB = 22;
    padT = 8;
    plotW = W - padL - 6;
    plotH = H - padB - padT;
    n = Math.max(1, len(values));
    top = nice_max(Math.max(1, vmax(values)));
    slot = plotW / n;
    bw = Math.max(2, slot * 0.7);
    every = tick_every or Math.max(1, Math.ceil(n / 8));
    ticks = [0, 0.25, 0.5, 0.75, 1];
    <div className="relative w-full">
        <svg
            viewBox={"0 0 " + str(W) + " " + str(H)}
            className="block h-auto w-full"
            role="img"
        >
            {for t in ticks {
                <g key={"t" + str(t)}>
                    <line
                        x1={padL}
                        x2={W - 4}
                        y1={padT + plotH - t * plotH}
                        y2={padT + plotH - t * plotH}
                        stroke={"var(--axis)" if t == 0 else "var(--grid)"}
                        strokeWidth={1}
                    />
                    <text
                        x={padL - 6}
                        y={padT + plotH - t * plotH + 3}
                        textAnchor="end"
                        fontSize={11}
                        fill="var(--ink-muted)"
                        className="tabular"
                    >
                        {str(Math.round(top * t))}
                    </text>
                </g>
            }}
            {for (i, v) in enumerate(values) {
                <g key={str(i)}>
                    <path
                        d={bar_path(
                            padL + i * slot + (slot - bw) / 2,
                            padT + plotH - (v / top) * plotH,
                            bw,
                            (v / top) * plotH,
                            3
                        )}
                        fill={color}
                        opacity={1 if hover == -1 or hover == i else 0.45}
                    />
                    <rect
                        x={padL + i * slot}
                        y={padT}
                        width={slot}
                        height={plotH}
                        fill="transparent"
                        onMouseEnter={lambda {
                            hover = i;
                            tip = {
                                "x": 100 * (padL + i * slot + slot / 2) / W,
                                "y": 100 * (padT + plotH - (v / top) * plotH) / H,
                                "title": labels[i],
                                "lines": [
                                    {
                                        "label": unit or "value",
                                        "value": str(v),
                                        "color": color
                                    }
                                ]
                            };
                        }}
                        onMouseLeave={lambda {
                            hover = -1;
                            tip = None;
                        }}
                    />
                    {if i % every == 0 {
                        <text
                            x={padL + i * slot + slot / 2}
                            y={H - 6}
                            textAnchor="middle"
                            fontSize={11}
                            fill="var(--ink-muted)"
                        >
                            {labels[i]}
                        </text>
                    }}
                </g>
            }}
        </svg>
        <Tooltip tip={tip}/>
    </div>
}

def:pub StackedBars(
    labels: list[str], series: list[any], height: int = 200
) -> JsxElement {
    has tip: any = None,
        hover: int = -1;
    W = 520;
    H = height;
    padL = 34;
    padB = 22;
    padT = 8;
    plotW = W - padL - 6;
    plotH = H - padB - padT;
    n = Math.max(1, len(labels));
    totals = [
        sum([float(s["values"][i] or 0) for s in series]) for i in range(len(labels))
    ];
    top = nice_max(Math.max(1, vmax(totals)));
    slot = plotW / n;
    bw = Math.max(3, slot * 0.62);
    every = Math.max(1, Math.ceil(n / 9));
    <div className="relative w-full">
        <svg
            viewBox={"0 0 " + str(W) + " " + str(H)}
            className="block h-auto w-full"
            role="img"
        >
            {for t in [0, 0.5, 1] {
                <g key={"t" + str(t)}>
                    <line
                        x1={padL}
                        x2={W - 4}
                        y1={padT + plotH - t * plotH}
                        y2={padT + plotH - t * plotH}
                        stroke={"var(--axis)" if t == 0 else "var(--grid)"}
                    />
                    <text
                        x={padL - 6}
                        y={padT + plotH - t * plotH + 3}
                        textAnchor="end"
                        fontSize={11}
                        fill="var(--ink-muted)"
                    >
                        {str(Math.round(top * t))}
                    </text>
                </g>
            }}
            {for i in range(len(labels)) {
                <g key={str(i)} opacity={1 if hover == -1 or hover == i else 0.5}>
                    {for (si, s) in enumerate(series) {
                        <rect
                            key={str(si)}
                            x={padL + i * slot + (slot - bw) / 2}
                            y={padT + plotH
                                - (
                                    sum(
                                        [
                                            float(series[k]["values"][i] or 0)
                                            for k in range(si + 1)
                                        ]
                                    )
                                    / top
                                )
                                    * plotH}
                            width={bw}
                            height={Math.max(
                                0,
                                (float(s["values"][i] or 0) / top) * plotH
                                    - (1.5 if s["values"][i] else 0)
                            )}
                            rx={1.5}
                            fill={s["color"] or ("var(--series-" + str(si + 1) + ")")}
                        />
                    }}
                    <rect
                        x={padL + i * slot}
                        y={padT}
                        width={slot}
                        height={plotH}
                        fill="transparent"
                        onMouseEnter={lambda {
                            hover = i;
                            tip = {
                                "x": 100 * (padL + i * slot + slot / 2) / W,
                                "y": 100 * (padT + plotH - (totals[i] / top) * plotH)
                                    / H,
                                "title": labels[i] + " · " + str(totals[i]),
                                "lines": [
                                    {
                                        "label": s["name"],
                                        "value": str(s["values"][i] or 0),
                                        "color": s["color"]
                                            or ("var(--series-" + str(si + 1) + ")")
                                    }
                                    for (si, s) in enumerate(series)
                                    if s["values"][i]
                                ]
                            };
                        }}
                        onMouseLeave={lambda {
                            hover = -1;
                            tip = None;
                        }}
                    />
                    {if i % every == 0 {
                        <text
                            x={padL + i * slot + slot / 2}
                            y={H - 6}
                            textAnchor="middle"
                            fontSize={11}
                            fill="var(--ink-muted)"
                        >
                            {labels[i]}
                        </text>
                    }}
                </g>
            }}
        </svg>
        <Tooltip tip={tip}/>
        <Legend
            className="mt-2"
            items={[
                {
                    "name": s["name"],
                    "color": s["color"] or ("var(--series-" + str(si + 1) + ")")
                } for (si, s) in enumerate(series)
            ]}
        />
    </div>
}

def:pub LineChart(
    labels: list[str], series: list[any], height: int = 200, area: bool = True
) -> JsxElement {
    has tip: any = None,
        hover: int = -1;
    W = 520;
    H = height;
    padL = 40;
    padB = 22;
    padT = 10;
    plotW = W - padL - 10;
    plotH = H - padB - padT;
    n = Math.max(2, len(labels));
    peak = 1.0;
    for s in series {
        for v in s["values"] {
            peak = Math.max(peak, float(v or 0));
        }
    }
    top = nice_max(peak);
    every = Math.max(1, Math.ceil(n / 8));
    def px(i: int) -> float {
        return padL + i * plotW / (n - 1);
    }
    def py(v: float) -> float {
        return padT + plotH - (v / top) * plotH;
    }
    def line_d(vals: list[float]) -> str {
        return " ".join(
            [
                ("M" if i == 0 else "L") + str(px(i)) + "," + str(py(float(v or 0)))
                for (i, v) in enumerate(vals)
            ]
        );
    }
    <div className="relative w-full">
        <svg
            viewBox={"0 0 " + str(W) + " " + str(H)}
            className="block h-auto w-full"
            role="img"
        >
            {for t in [0, 0.25, 0.5, 0.75, 1] {
                <g key={"t" + str(t)}>
                    <line
                        x1={padL}
                        x2={W - 6}
                        y1={py(top * t)}
                        y2={py(top * t)}
                        stroke={"var(--axis)" if t == 0 else "var(--grid)"}
                    />
                    <text
                        x={padL - 6}
                        y={py(top * t) + 3}
                        textAnchor="end"
                        fontSize={11}
                        fill="var(--ink-muted)"
                    >
                        {fmt_num(Math.round(top * t))}
                    </text>
                </g>
            }}
            {for (si, s) in enumerate(series) {
                <g key={str(si)}>
                    {if area {
                        <path
                            d={line_d(s["values"])
                                + " L"
                                + str(px(len(s["values"]) - 1))
                                + ","
                                + str(py(0))
                                + " L"
                                + str(px(0))
                                + ","
                                + str(py(0))
                                + " Z"}
                            fill={s["color"] or ("var(--series-" + str(si + 1) + ")")}
                            opacity={0.12}
                        />
                    }}
                    <path
                        d={line_d(s["values"])}
                        fill="none"
                        stroke={s["color"] or ("var(--series-" + str(si + 1) + ")")}
                        strokeWidth={2}
                        strokeLinejoin="round"
                        strokeLinecap="round"
                    />
                </g>
            }}
            {if hover >= 0 {
                <g>
                    <line
                        x1={px(hover)}
                        x2={px(hover)}
                        y1={padT}
                        y2={padT + plotH}
                        stroke="var(--ink-muted)"
                        strokeDasharray="3 3"
                    />
                    {for (si, s) in enumerate(series) {
                        <circle
                            key={str(si)}
                            cx={px(hover)}
                            cy={py(float(s["values"][hover] or 0))}
                            r={4}
                            fill={s["color"] or ("var(--series-" + str(si + 1) + ")")}
                            stroke="var(--chart-surface)"
                            strokeWidth={2}
                        />
                    }}
                </g>
            }}
            {for (i, lab) in enumerate(labels) {
                <g key={"h" + str(i)}>
                    <rect
                        x={px(i) - plotW / (n - 1) / 2}
                        y={padT}
                        width={plotW / (n - 1)}
                        height={plotH}
                        fill="transparent"
                        onMouseEnter={lambda {
                            hover = i;
                            tip = {
                                "x": 100 * px(i) / W,
                                "y": 100 * padT / H + 8,
                                "title": lab,
                                "lines": [
                                    {
                                        "label": s["name"],
                                        "value": fmt_num(float(s["values"][i] or 0)),
                                        "color": s["color"]
                                            or ("var(--series-" + str(si + 1) + ")")
                                    } for (si, s) in enumerate(series)
                                ]
                            };
                        }}
                        onMouseLeave={lambda {
                            hover = -1;
                            tip = None;
                        }}
                    />
                    {if i % every == 0 {
                        <text
                            x={px(i)}
                            y={H - 6}
                            textAnchor="middle"
                            fontSize={11}
                            fill="var(--ink-muted)"
                        >
                            {lab}
                        </text>
                    }}
                </g>
            }}
        </svg>
        <Tooltip tip={tip}/>
        {if len(series) > 1 {
            <Legend
                className="mt-2"
                items={[
                    {
                        "name": s["name"],
                        "color": s["color"] or ("var(--series-" + str(si + 1) + ")")
                    } for (si, s) in enumerate(series)
                ]}
            />
        }}
    </div>
}

def:pub arc_path(
    cx: float, cy: float, r0: float, r1: float, a0: float, a1: float
) -> str {
    large = 1 if a1 - a0 > TAU / 2 else 0;
    x0 = cx + r1 * Math.cos(a0);
    y0 = cy + r1 * Math.sin(a0);
    x1 = cx + r1 * Math.cos(a1);
    y1 = cy + r1 * Math.sin(a1);
    x2 = cx + r0 * Math.cos(a1);
    y2 = cy + r0 * Math.sin(a1);
    x3 = cx + r0 * Math.cos(a0);
    y3 = cy + r0 * Math.sin(a0);
    return "M"
        + str(x0)
        + ","
        + str(y0)
        + " A"
        + str(r1)
        + ","
        + str(r1)
        + " 0 "
        + str(large)
        + " 1 "
        + str(x1)
        + ","
        + str(y1)
        + " L"
        + str(x2)
        + ","
        + str(y2)
        + " A"
        + str(r0)
        + ","
        + str(r0)
        + " 0 "
        + str(large)
        + " 0 "
        + str(x3)
        + ","
        + str(y3)
        + " Z";
}

def:pub Donut(
    labels: list[str],
    values: list[float],
    colors: list[str] = [],
    center: str = "",
    sub: str = "",
    size: int = 168,
    fmt: str = ""
) -> JsxElement {
    has hover: int = -1;
    total = sum([float(v) for v in values]) or 1;
    cx = 100;
    cy = 100;
    acc = 0 - TAU / 4;
    arcs: list[any] = [];
    for (i, v) in enumerate(values) {
        span = TAU * float(v) / total;
        gap = 0.012 if len(values) > 1 else 0;
        arcs.append({"i": i, "a0": acc + gap, "a1": acc + span - gap});
        acc = acc + span;
    }
    <div className="flex items-center gap-5">
        <svg
            viewBox="0 0 200 200"
            style={{"width": str(size) + "px", "height": str(size) + "px"}}
            className="shrink-0"
        >
            {for a in arcs {
                <path
                    key={str(a["i"])}
                    d={arc_path(
                        cx,
                        cy,
                        62 if hover != a["i"] else 60,
                        92 if hover != a["i"] else 96,
                        a["a0"],
                        Math.max(a["a0"] + 0.001, a["a1"])
                    )}
                    fill={colors[a["i"]]
                        if len(colors) > a["i"]
                        else series_color(a["i"])}
                    opacity={1 if hover == -1 or hover == a["i"] else 0.45}
                    onMouseEnter={lambda { hover = a["i"]; }}
                    onMouseLeave={lambda { hover = -1; }}
                />
            }}
            <text
                x={cx}
                y={cy - 2}
                textAnchor="middle"
                fontSize={22 if hover >= 0 else 26}
                fontWeight={600}
                fill="var(--ink-1)"
            >
                {(
                    fmt_num(float(values[hover]))
                        if fmt != "pct"
                        else str(Math.round(100 * values[hover] / total)) + "%"
                )
                    if hover >= 0
                    else center}
            </text>
            <text
                x={cx}
                y={cy + 18}
                textAnchor="middle"
                fontSize={11}
                fill="var(--ink-muted)"
            >
                {labels[hover] if hover >= 0 else sub}
            </text>
        </svg>
        <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            {for (i, lab) in enumerate(labels) {
                <div
                    key={str(i)}
                    className={"flex items-center gap-2 rounded-md px-1.5 py-0.5 text-xs transition-colors "
                        + ("bg-muted" if hover == i else "")}
                    onMouseEnter={lambda { hover = i; }}
                    onMouseLeave={lambda { hover = -1; }}
                >
                    <span
                        className="inline-block size-2.5 shrink-0 rounded-[3px]"
                        style={{
                            "background": colors[i]
                                if len(colors) > i
                                else series_color(i)
                        }}
                    ></span>
                    <span className="truncate text-muted-foreground">{lab}</span>
                    <span className="ml-auto font-medium tabular text-foreground">
                        {str(Math.round(100 * values[i] / total)) + "%"}
                    </span>
                </div>
            }}
        </div>
    </div>
}

def:pub HBars(
    labels: list[str],
    values: list[float],
    colors: list[str] = [],
    fmt: str = "",
    sub: list[str] = [],
    onPick: any = None,
    mono: bool = True
) -> JsxElement {
    top = Math.max(1, vmax(values));
    <div className="flex flex-col gap-1.5">
        {for (i, lab) in enumerate(labels) {
            <button
                key={str(i)}
                type="button"
                className="group grid w-full grid-cols-[minmax(0,1fr)_minmax(80px,42%)_56px] items-center gap-3 rounded-md px-1.5 py-1 text-left text-xs hover:bg-muted/60"
                onClick={lambda { if onPick { onPick(i); }}}
                title={lab}
            >
                <span className="min-w-0">
                    <span
                        className={"block truncate text-foreground "
                            + ("font-mono text-[11px]" if mono else "")}
                    >
                        {lab}
                    </span>
                    {if len(sub) > i and sub[i] {
                        <span
                            className="block truncate text-[10px] text-muted-foreground"
                        >
                            {sub[i]}
                        </span>
                    }}
                </span>
                <span className="relative h-2.5 rounded-full bg-muted">
                    <span
                        className="absolute inset-y-0 left-0 rounded-full transition-all duration-500"
                        style={{
                            "width": str(Math.max(2, 100 * values[i] / top)) + "%",
                            "background": colors[i]
                                if len(colors) > i
                                else "var(--series-1)"
                        }}
                    ></span>
                </span>
                <span className="text-right font-medium tabular text-foreground">
                    {(str(Math.round(values[i] * 100)) + "%")
                        if fmt == "pct"
                        else fmt_num(values[i])}
                </span>
            </button>
        }}
    </div>
}

def:pub Gauge(value: int, label: str = "", size: int = 150) -> JsxElement {
    v = int(max(0, min(100, value)));
    a0 = TAU / 2;
    a1 = TAU / 2 + (TAU / 2) * v / 100;
    color = risk_color(v);
    <svg viewBox="0 0 200 118" style={{"width": str(size) + "px"}}>
        <path d={arc_path(100, 104, 70, 88, a0, TAU - 0.0001)} fill="var(--muted)"/>
        {if v > 0 {
            <path d={arc_path(100, 104, 70, 88, a0, a1)} fill={color}/>
        }}
        <text
            x={100}
            y={94}
            textAnchor="middle"
            fontSize={34}
            fontWeight={650}
            fill="var(--ink-1)"
        >
            {str(v)}
        </text>
        <text x={100} y={113} textAnchor="middle" fontSize={11} fill="var(--ink-muted)">
            {label or risk_label(v) + " risk"}
        </text>
    </svg>
}

def:pub Sparkline(
    values: list[float],
    color: str = "var(--series-1)",
    width: int = 120,
    height: int = 32
) -> JsxElement {
    n = len(values);
    if n < 2 {
        return <svg width={width} height={height}></svg>;
    }
    top = Math.max(1, vmax(values));
    pts = " ".join(
        [
            str(i * width / (n - 1))
                + ","
                + str(height - 2 - (float(v) / top) * (height - 4))
            for (i, v) in enumerate(values)
        ]
    );
    <svg
        width={width}
        height={height}
        viewBox={"0 0 " + str(width) + " " + str(height)}
        className="overflow-visible"
    >
        <polyline
            points={pts}
            fill="none"
            stroke={color}
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
        />
    </svg>
}
