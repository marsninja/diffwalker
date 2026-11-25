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
    LoaderCircle,
}

def:pub Panel(
    title: str = "",
    subtitle: str = "",
    action: JsxElement | None = None,
    children: any = None,
    className: str = "",
    bodyClass: str = "",
    id: str = "",
) -> JsxElement;

def:pub StatTile(
    label: str, value: str, hint: str = "", accent: str = "", children: any = None
) -> JsxElement;

def:pub SevIcon(sev: str, className: str = "size-3.5") -> JsxElement;

def:pub SevBadge(sev: str) -> JsxElement;

def:pub VerdictPill(verdict: str, reviewing: bool = False) -> JsxElement;

def:pub RiskMeter(score: int, width: str = "w-16") -> JsxElement;

def:pub KindBadge(kind: str, number: int = 0) -> JsxElement;

def:pub PRLine(
    row: PRRow,
    onReview: Callable[[str], Coroutine[any, any, None]] | None = None,
    compact: bool = False,
) -> JsxElement;

def:pub Skeleton(className: str = "h-24") -> JsxElement;

def:pub Empty(title: str, hint: str = "", children: any = None) -> JsxElement;

def:pub PageHeader(
    eyebrow: str, title: str, subtitle: str = "", children: any = None
) -> JsxElement;
