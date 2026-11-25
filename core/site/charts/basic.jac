glob TAU: float = 6.283185307179586;

obj TipLine {
    has label: str,
        value: str,
        color: str = "";
}

obj Tip {
    has x: float,
        y: float,
        title: str,
        lines: list[TipLine] = [];
}

obj LegendItem {
    has name: str,
        color: str;
}

obj Arc {
    has i: int,
        a0: float,
        a1: float;
}

obj Series {
    has name: str,
        values: list[float],
        color: str = "";
}

def:pub vmax(xs: list[float]) -> float;
def value_at(values: list[float], i: int) -> float;
def label_at(labels: list[str], i: int) -> str;
def num(v: float) -> str;

def:pub nice_max(v: float) -> float;

def:pub bar_path(x: float, y: float, w: float, h: float, r: float) -> str;

def:pub Tooltip(tip: Tip | None) -> JsxElement;

def:pub Legend(items: list[LegendItem], className: str = "") -> JsxElement;

def:pub BarChart(
    labels: list[str],
    values: list[float],
    color: str = "var(--series-1)",
    height: int = 180,
    unit: str = "",
    tick_every: int = 0,
) -> JsxElement;

def:pub StackedBars(labels: list[str], series: list[Series], height: int = 200) -> JsxElement;

def:pub LineChart(
    labels: list[str], series: list[Series], height: int = 200, area: bool = True
) -> JsxElement;

def:pub arc_path(cx: float, cy: float, r0: float, r1: float, a0: float, a1: float) -> str;

def:pub Donut(
    labels: list[str],
    values: list[float],
    colors: list[str] = [],
    center: str = "",
    sub: str = "",
    size: int = 168,
    fmt: str = "",
) -> JsxElement;

def:pub HBars(
    labels: list[str],
    values: list[float],
    colors: list[str] = [],
    fmt: str = "",
    sub: list[str] = [],
    onPick: Callable[[int], None] | None = None,
    mono: bool = True,
) -> JsxElement;

def:pub Gauge(value: int, label: str = "", size: int = 150) -> JsxElement;

def:pub Sparkline(
    values: list[float], color: str = "var(--series-1)", width: int = 120, height: int = 32
) -> JsxElement;
