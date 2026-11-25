import from "@jac/runtime" { useNavigate }
import from "lucide-react" { RefreshCw, Search, GitBranch, Github, PencilLine, Layers }

obj Filter {
    has key: str,
        label: str,
        icon: any;
}

glob FILTERS: list[Filter] = [
    Filter(key="all", label="All", icon=Layers),
    Filter(key="branch", label="Branches", icon=GitBranch),
    Filter(key="github", label="GitHub", icon=Github),
    Filter(key="worktree", label="Worktree", icon=PencilLine),
];

def FilterTab(item: Filter, active: bool, count: int, onPick: Callable[[str], None]) -> JsxElement;

def:pub Reviews -> JsxElement;
