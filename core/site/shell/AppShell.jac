import from "@jac/runtime" { Navigate, Outlet, Link, jacIsLoggedIn, useNavigate, useLocation }
import from "lucide-react" {
    LayoutDashboard,
    GitPullRequest,
    Activity,
    LayoutGrid,
    Hammer,
    Sparkles,
    Sun,
    Moon,
    FolderGit2,
    Menu,
    X,
    Check,
    Copy,
    Github,
    Zap,
    Info,
    TriangleAlert,
    CircleCheck,
    LogOut,
}

obj NavEntry {
    has to: str,
        label: str,
        icon: any;
}

obj AgentAction {
    has label: str,
        detail: str,
        origin: str,
        id: str = "";
}

glob NAV: list[NavEntry] = [
         NavEntry(to="/", label="Dashboard", icon=LayoutDashboard),
         NavEntry(to="/reviews", label="Reviews", icon=GitPullRequest),
         NavEntry(to="/insights", label="Insights", icon=Activity),
         NavEntry(to="/board", label="Insight board", icon=LayoutGrid),
         NavEntry(to="/built", label="How it's built", icon=Hammer),
     ],
     ACTION_LABEL: dict[str, str] = {
         "navigate": "navigated",
         "filter": "filtered findings",
         "export": "opened the export",
         "confirm_publish": "asked to publish",
         "repo": "switched repository",
     };

def is_active(path: str, to: str) -> bool;

def:pub handle_ui_action(action: str, args: UiArgs, nav: Callable[[str], None], origin: str);

def NavItem(item: NavEntry, active: bool, onPick: Callable[[], None] | None = None) -> JsxElement;

def NavLinks(path: str, onPick: Callable[[], None] | None = None) -> JsxElement;

def Sidebar(path: str, ws: WorkspaceView | None) -> JsxElement;

def RepoSwitcher(ws: WorkspaceView | None) -> JsxElement;

def LiveDot -> JsxElement;

def Topbar(ws: WorkspaceView | None, path: str) -> JsxElement;

def Toaster -> JsxElement;

def AgentBeacon -> JsxElement;

def ExportDialog -> JsxElement;

def PublishDialog -> JsxElement;
def:pub RootLayout -> JsxElement;

def:pub AppShell -> JsxElement;
