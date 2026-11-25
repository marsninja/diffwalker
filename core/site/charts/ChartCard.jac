import from "lucide-react" {
    Pin,
    PinOff,
    BarChart3,
    Table2,
    Workflow,
    PieChart,
    LineChart as LineIcon,
}

def kind_icon(kind: str) -> any;
def:pub ChartBody(kind: str, spec: any) -> JsxElement;
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
) -> JsxElement;
