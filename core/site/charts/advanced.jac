glob HEAT: list[str] = [
         "var(--heat-0)",
         "var(--seq-200)",
         "var(--seq-300)",
         "var(--seq-400)",
         "var(--seq-500)",
         "var(--seq-600)"
     ],
     MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

def heat_level(count: int, peak: int) -> int {
    if count <= 0 {
        return 0;
    }
    ratio = count / max(1, peak);
    if ratio > 0.75 {
        return 5;
    }
    if ratio > 0.5 {
        return 4;
    }
    if ratio > 0.25 {
        return 3;
    }
    if ratio > 0.1 {
        return 2;
    }
    return 1;
}

def:pub CalendarHeatmap(days: list[any], cell: int = 12) -> JsxElement {
    has tip: any = None;
    if not days {
        return <div className="h-24"></div>;
    }
    first = new(Date, days[0].day + "T00:00:00");
    offset = first.getDay();
    peak = 1;
    for d in days {
        peak = max(peak, d.count);
    }
    gap = 3;
    step = cell + gap;
    weeks = int((len(days) + offset + 6) / 7);
    W = 30 + weeks * step;
    H = 18 + 7 * step;
    labels: list[any] = [];
    last_month = -1;
    for (i, d) in enumerate(days) {
        col = int((i + offset) / 7);
        m = int(d.day[5:7]) - 1;
        if m != last_month and (i + offset) % 7 == 0 {
            labels.append({"x": 30 + col * step, "text": MONTHS[m]});
            last_month = m;
        }
    }
    <div className="relative w-full overflow-x-auto thin-scroll">
        <svg
            viewBox={"0 0 " + str(W) + " " + str(H)}
            className="block h-auto w-full min-w-[640px]"
        >
            {for (li, lab) in enumerate(labels) {
                <text
                    key={"m" + str(li)}
                    x={lab["x"]}
                    y={10}
                    fontSize={9}
                    fill="var(--ink-muted)"
                >
                    {lab["text"]}
                </text>
            }}
            {for (ri, rl) in enumerate(["", "Mon", "", "Wed", "", "Fri", ""]) {
                <text
                    key={"r" + str(ri)}
                    x={0}
                    y={18 + ri * step + cell - 2}
                    fontSize={9}
                    fill="var(--ink-muted)"
                >
                    {rl}
                </text>
            }}
            {for (i, d) in enumerate(days) {
                <rect
                    key={d.day}
                    x={30 + int((i + offset) / 7) * step}
                    y={18 + ((i + offset) % 7) * step}
                    width={cell}
                    height={cell}
                    rx={2.5}
                    fill={HEAT[heat_level(d.count, peak)]}
                    onMouseEnter={lambda { tip = {
                        "x": 100 * (30 + int((i + offset) / 7) * step) / W,
                        "y": 100 * (18 + ((i + offset) % 7) * step) / H,
                        "title": d.day,
                        "lines": [
                            {"label": "commits", "value": str(d.count), "color": ""}
                        ]
                    }; }}
                    onMouseLeave={lambda { tip = None; }}
                />
            }}
        </svg>
        <Tooltip tip={tip}/>
        <div
            className="mt-2 flex items-center justify-end gap-1 text-[10px] text-muted-foreground"
        >
            <span className="mr-1">Less</span>
            {for (hi, h) in enumerate(HEAT) {
                <span
                    key={str(hi)}
                    className="inline-block size-2.5 rounded-[2px]"
                    style={{"background": h}}
                ></span>
            }}
            <span className="ml-1">More</span>
        </div>
    </div>
}

def _worst(row: list[float], side: float) -> float {
    if not row {
        return 1e18;
    }
    s = 0.0;
    mx = 0.0;
    mn = 1e18;
    for v in row {
        s += v;
        mx = max(mx, v);
        mn = min(mn, v);
    }
    s2 = s * s;
    w2 = side * side;
    return max(w2 * mx / s2, s2 / (w2 * mn));
}

def:pub squarify(
    values: list[float], x: float, y: float, w: float, h: float
) -> list[any] {
    total = 0.0;
    for v in values {
        total += v;
    }
    out: list[any] = [];
    if total <= 0 {
        return out;
    }
    scale = (w * h) / total;
    areas = [v * scale for v in values];
    rx = x;
    ry = y;
    rw = w;
    rh = h;
    i = 0;
    while i < len(areas) {
        side = min(rw, rh);
        row: list[float] = [areas[i]];
        j = i + 1;
        while j < len(areas) and _worst(row + [areas[j]], side) <= _worst(row, side) {
            row.append(areas[j]);
            j += 1;
        }
        rsum = 0.0;
        for a in row {
            rsum += a;
        }
        if rw >= rh {
            colw = rsum / rh;
            cy = ry;
            for (k, a) in enumerate(row) {
                hh = a / colw;
                out.append({"i": i + k, "x": rx, "y": cy, "w": colw, "h": hh});
                cy += hh;
            }
            rx += colw;
            rw -= colw;
        } else {
            rowh = rsum / rw;
            cx = rx;
            for (k, a) in enumerate(row) {
                ww = a / rowh;
                out.append({"i": i + k, "x": cx, "y": ry, "w": ww, "h": rowh});
                cx += ww;
            }
            ry += rowh;
            rh -= rowh;
        }
        i = j;
    }
    return out;
}

def:pub Treemap(
    cells: list[any],
    color_of: any,
    height: int = 360,
    label_of: any = None,
    sub_of: any = None
) -> JsxElement {
    has tip: any = None,
        hover: int = -1;
    W = 1000;
    H = height * 2;
    rects = squarify([float(c.bytes) for c in cells], 0, 0, W, H);
    <div className="relative w-full">
        <svg
            viewBox={"0 0 " + str(W) + " " + str(H)}
            className="block h-auto w-full"
            preserveAspectRatio="none"
        >
            {for r in rects {
                <g key={str(r["i"])}>
                    <rect
                        x={r["x"] + 1.5}
                        y={r["y"] + 1.5}
                        width={max(0, r["w"] - 3)}
                        height={max(0, r["h"] - 3)}
                        rx={6}
                        fill={color_of(cells[r["i"]], r["i"])}
                        opacity={0.95 if hover == -1 or hover == r["i"] else 0.55}
                        onMouseEnter={lambda {
                            hover = r["i"];
                            c = cells[r["i"]];
                            tip = {
                                "x": 100 * (r["x"] + r["w"] / 2) / W,
                                "y": 100 * (r["y"] + r["h"] / 2) / H,
                                "title": c.path,
                                "lines": [
                                    {
                                        "label": "size",
                                        "value": fmt_bytes(c.bytes),
                                        "color": ""
                                    },
                                    {
                                        "label": "files",
                                        "value": str(c.files),
                                        "color": ""
                                    },
                                    {
                                        "label": "churn (lines)",
                                        "value": fmt_num(c.churn),
                                        "color": ""
                                    },
                                    {
                                        "label": "language",
                                        "value": c.language,
                                        "color": ""
                                    }
                                ]
                            };
                        }}
                        onMouseLeave={lambda {
                            hover = -1;
                            tip = None;
                        }}
                    />
                    {if r["w"] > 110 and r["h"] > 44 {
                        <text
                            x={r["x"] + 12}
                            y={r["y"] + 30}
                            fontSize={22}
                            fontWeight={600}
                            fill="#fff"
                            pointerEvents="none"
                        >
                            {(
                                label_of(cells[r["i"]])
                                    if label_of
                                    else cells[r["i"]].path
                            )[:int(r["w"] / 13)]}
                        </text>
                    }}
                    {if r["w"] > 170 and r["h"] > 76 {
                        <text
                            x={r["x"] + 12}
                            y={r["y"] + 56}
                            fontSize={18}
                            fill="rgba(255,255,255,0.8)"
                            pointerEvents="none"
                        >
                            {sub_of(cells[r["i"]])
                                if sub_of
                                else fmt_bytes(cells[r["i"]].bytes)}
                        </text>
                    }}
                </g>
            }}
        </svg>
        <Tooltip tip={tip}/>
    </div>
}

def:pub Scatter(
    points: list[any],
    height: int = 320,
    x_label: str = "",
    y_label: str = "",
    onPick: any = None
) -> JsxElement {
    has tip: any = None,
        hover: int = -1;
    W = 640;
    H = height;
    padL = 44;
    padB = 30;
    padT = 12;
    padR = 12;
    xs = [float(p["x"]) for p in points];
    ys = [float(p["y"]) for p in points];
    xmax = max(1.0, vmax(xs)) * 1.08;
    ymax = max(1.0, vmax(ys)) * 1.1;
    rmax = max(1.0, vmax([float(p["r"]) for p in points]));
    def sx(v: float) -> float {
        return padL + (v / xmax) * (W - padL - padR);
    }
    def sy(v: float) -> float {
        return H - padB - (v / ymax) * (H - padB - padT);
    }
    <div className="relative w-full">
        <svg viewBox={"0 0 " + str(W) + " " + str(H)} className="block h-auto w-full">
            {for t in [0, 0.25, 0.5, 0.75, 1] {
                <g key={"g" + str(t)}>
                    <line
                        x1={padL}
                        x2={W - padR}
                        y1={sy(ymax * t)}
                        y2={sy(ymax * t)}
                        stroke={"var(--axis)" if t == 0 else "var(--grid)"}
                    />
                    <text
                        x={padL - 6}
                        y={sy(ymax * t) + 3}
                        textAnchor="end"
                        fontSize={10}
                        fill="var(--ink-muted)"
                    >
                        {fmt_num(round(ymax * t))}
                    </text>
                    <text
                        x={sx(xmax * t)}
                        y={H - 14}
                        textAnchor="middle"
                        fontSize={10}
                        fill="var(--ink-muted)"
                    >
                        {fmt_num(round(xmax * t))}
                    </text>
                </g>
            }}
            <text
                x={W - padR}
                y={H - 2}
                textAnchor="end"
                fontSize={10}
                fill="var(--ink-2)"
            >
                {x_label}
            </text>
            <text x={padL} y={padT - 2} fontSize={10} fill="var(--ink-2)">
                {y_label}
            </text>
            {for (i, p) in enumerate(points) {
                <circle
                    key={str(i)}
                    cx={sx(float(p["x"]))}
                    cy={sy(float(p["y"]))}
                    r={5 + 12 * (float(p["r"]) / rmax)}
                    fill={p["color"]}
                    fillOpacity={0.75 if hover == -1 or hover == i else 0.25}
                    stroke="var(--chart-surface)"
                    strokeWidth={2}
                    className="cursor-pointer"
                    onMouseEnter={lambda {
                        hover = i;
                        tip = {
                            "x": 100 * sx(float(p["x"])) / W,
                            "y": 100 * sy(float(p["y"])) / H,
                            "title": p["label"],
                            "lines": p["lines"]
                        };
                    }}
                    onMouseLeave={lambda {
                        hover = -1;
                        tip = None;
                    }}
                    onClick={lambda { if onPick { onPick(i); }}}
                />
            }}
        </svg>
        <Tooltip tip={tip}/>
    </div>
}

def:pub layout_network(
    ids: list[str], edges: list[any], W: float, H: float
) -> dict[str, any] {
    pos: dict[str, any] = {};
    n = len(ids);
    for (i, nid) in enumerate(ids) {
        ang = 6.2831853 * i / max(1, n);
        pos[nid] = {
            "x": W / 2 + (W * 0.32) * Math.cos(ang),
            "y": H / 2 + (H * 0.32) * Math.sin(ang)
        };
    }
    k = Math.sqrt((W * H) / max(1, n)) * 0.8;
    temp = W / 6;
    for it in range(320) {
        disp: dict[str, any] = {};
        for a in ids {
            disp[a] = {"x": 0.0, "y": 0.0};
        }
        for a in ids {
            for b in ids {
                if a == b {
                    continue;
                }
                dx = pos[a]["x"] - pos[b]["x"];
                dy = pos[a]["y"] - pos[b]["y"];
                d = max(0.01, Math.sqrt(dx * dx + dy * dy));
                f = (k * k) / d;
                disp[a]["x"] = disp[a]["x"] + dx / d * f;
                disp[a]["y"] = disp[a]["y"] + dy / d * f;
            }
        }
        for e in edges {
            a = e["a"];
            b = e["b"];
            if a not in pos or b not in pos {
                continue;
            }
            dx = pos[a]["x"] - pos[b]["x"];
            dy = pos[a]["y"] - pos[b]["y"];
            d = max(0.01, Math.sqrt(dx * dx + dy * dy));
            f = (d * d) / k * 0.22 * (0.5 + float(e["strength"]));
            disp[a]["x"] = disp[a]["x"] - dx / d * f;
            disp[a]["y"] = disp[a]["y"] - dy / d * f;
            disp[b]["x"] = disp[b]["x"] + dx / d * f;
            disp[b]["y"] = disp[b]["y"] + dy / d * f;
        }
        for a in ids {
            dx = disp[a]["x"];
            dy = disp[a]["y"];
            d = max(0.01, Math.sqrt(dx * dx + dy * dy));
            pos[a]["x"] = min(
                W - 40,
                max(
                    40,
                    pos[a]["x"] + dx / d * min(d, temp) + (W / 2 - pos[a]["x"]) * 0.01
                )
            );
            pos[a]["y"] = min(
                H - 24,
                max(
                    24,
                    pos[a]["y"] + dy / d * min(d, temp) + (H / 2 - pos[a]["y"]) * 0.01
                )
            );
        }
        temp = temp * 0.985;
    }
    return pos;
}

def:pub Network(nodes: list[any], edges: list[any], height: int = 460) -> JsxElement {
    has hover: str = "",
        pos: dict[str, any] = {};
    W = 960;
    H = height;
    areas: list[str] = [];
    for nd in nodes {
        if nd.area not in areas {
            areas.append(nd.area);
        }
    }
    can with [len(nodes), len(edges)] entry {
        pos = layout_network(
            [nd.id for nd in nodes],
            [{"a": e.a, "b": e.b, "strength": e.strength} for e in edges],
            W,
            H
        );
    }
    peak = 1;
    for nd in nodes {
        peak = max(peak, nd.changes);
    }
    wpeak = 1;
    for e in edges {
        wpeak = max(wpeak, e.weight);
    }
    ranked = sorted([nd.changes for nd in nodes], reverse=True);
    cutoff = ranked[min(9, len(ranked) - 1)] if len(ranked) > 0 else 0;
    linked: list[str] = [];
    if hover {
        for e in edges {
            if e.a == hover {
                linked.append(e.b);
            } elif e.b == hover {
                linked.append(e.a);
            }
        }
    }
    def area_color(area: str) -> str {
        idx = areas.index(area) if area in areas else 8;
        return series_color(idx) if idx < 8 else "var(--ink-muted)";
    }
    <div className="w-full">
        <svg viewBox={"0 0 " + str(W) + " " + str(H)} className="block h-auto w-full">
            {for (i, e) in enumerate(edges) {
                if e.a in pos and e.b in pos {
                    <line
                        key={"e" + str(i)}
                        x1={pos[e.a]["x"]}
                        y1={pos[e.a]["y"]}
                        x2={pos[e.b]["x"]}
                        y2={pos[e.b]["y"]}
                        stroke={"var(--primary)"
                            if hover and (e.a == hover or e.b == hover)
                            else "var(--ink-muted)"}
                        strokeOpacity={0.9
                            if hover and (e.a == hover or e.b == hover)
                            else (0.08 if hover else 0.28)}
                        strokeWidth={1 + 4 * e.weight / wpeak}
                    />
                }
            }}
            {for nd in nodes {
                if nd.id in pos {
                    <g
                        key={nd.id}
                        onMouseEnter={lambda { hover = nd.id; }}
                        onMouseLeave={lambda { hover = ""; }}
                        className="cursor-pointer"
                        opacity={1
                            if not hover or hover == nd.id or nd.id in linked
                            else 0.25}
                    >
                        <circle
                            cx={pos[nd.id]["x"]}
                            cy={pos[nd.id]["y"]}
                            r={6 + 12 * nd.changes / peak}
                            fill={area_color(nd.area)}
                            stroke="var(--chart-surface)"
                            strokeWidth={2.5}
                        />
                        {if nd.changes >= cutoff or nd.id == hover or nd.id in linked {
                            <text
                                x={pos[nd.id]["x"]}
                                y={pos[nd.id]["y"] + 10 + 12 * nd.changes / peak + 10}
                                textAnchor="middle"
                                fontSize={11.5}
                                fill={"var(--ink-1)" if nd.id == hover else "var(--ink-2)"}
                                stroke="var(--card)"
                                strokeWidth={3}
                                paintOrder="stroke"
                                className="font-mono"
                            >
                                {base_name(nd.id)}
                            </text>
                        }}
                    </g>
                }
            }}
        </svg>
        <Legend
            className="mt-1"
            items={[{"name": a, "color": area_color(a)} for a in areas[:8]]}
        />
        {if hover {
            <p className="mt-2 font-mono text-xs text-muted-foreground">
                {hover + " · co-changes with " + str(len(linked)) + " files"}
            </p>
        }}
    </div>
}
