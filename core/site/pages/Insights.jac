import from "@jac/runtime" { useLocation, useNavigate }
import from "lucide-react" {
    Activity,
    Flame,
    Users,
    Boxes,
    Network as NetworkIcon,
    Sparkles,
    TriangleAlert,
}

obj View {
    has key: str,
        label: str,
        icon: any;
}

glob VIEWS: list[View] = [
         View(key="activity", label="Activity", icon=Activity),
         View(key="hotspots", label="Hotspots", icon=Flame),
         View(key="people", label="People", icon=Users),
         View(key="structure", label="Structure", icon=Boxes),
         View(key="coupling", label="Coupling", icon=NetworkIcon),
     ],
     KIND_NAMES: list[str] = ["feat", "fix", "refactor", "docs", "test", "chore", "perf", "other"];

def view_from(search: str) -> str;

def ViewTab(item: View, active: bool, onPick: Callable[[str], None]) -> JsxElement;

def AskButton(prompt: str, label: str = "Ask Copilot") -> JsxElement;

def ActivityPane -> JsxElement;

def HotspotsPane -> JsxElement;

def PeoplePane -> JsxElement;

def StructurePane -> JsxElement;

def CouplingPane -> JsxElement;

def:pub Insights -> JsxElement;
