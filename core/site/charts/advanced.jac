glob HEAT: list[str] = [
         "var(--heat-0)",
         "var(--seq-200)",
         "var(--seq-300)",
         "var(--seq-400)",
         "var(--seq-500)",
         "var(--seq-600)",
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
         "Dec",
     ];

obj MonthMark {
    has x: int,
        text: str;
}

obj TreeRect {
    has i: int,
        x: float,
        y: float,
        w: float,
        h: float;
}

obj ScatterPoint {
    has x: float,
        y: float,
        r: float,
        color: str,
        label: str,
        lines: list[TipLine] = [];
}

obj XY {
    has x: float,
        y: float;
}

def heat_level(count: int, peak: int) -> int;

def:pub CalendarHeatmap(days: list[DayCount], cell: int = 12) -> JsxElement;

def _worst(row: list[float], side: float) -> float;
def:pub squarify(values: list[float], x: float, y: float, w: float, h: float) -> list[TreeRect];

def:pub Treemap(
    cells: list[TreeCell],
    color_of: Callable[[TreeCell, int], str],
    height: int = 360,
    label_of: Callable[[TreeCell], str] | None = None,
    sub_of: Callable[[TreeCell], str] | None = None,
) -> JsxElement;

def:pub Scatter(
    points: list[ScatterPoint],
    height: int = 320,
    x_label: str = "",
    y_label: str = "",
    onPick: Callable[[int], None] | None = None,
) -> JsxElement;
def:pub layout_network(
    ids: list[str], edges: list[CouplingEdge], W: float, H: float
) -> dict[str, XY];

def:pub Network(
    nodes: list[CouplingNode], edges: list[CouplingEdge], height: int = 460
) -> JsxElement;
