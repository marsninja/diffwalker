import from "@jac/runtime" { useLocation, useNavigate, Link }
import from "lucide-react" {
    ArrowLeft,
    Play,
    RotateCw,
    FileDown,
    Github,
    Sparkles,
    GitCommitHorizontal,
    ShieldX,
    FileSearch,
    CircleCheck,
    LoaderCircle,
    Target,
    ExternalLink,
    Clock,
    Info,
    TriangleAlert,
}

glob TABS: list[str] = ["overview", "files", "findings", "commits", "history"];

def parse_query(search: str) -> dict[str, str];

obj LiveRun {
    has review_id: str = "",
        stages: list[StageState] = [],
        files: dict[str, str] = {},
        feed: list[FeedItem] = [],
        active: bool = True,
        triage: list[FileRisk] = [],
        risk: int = 0;
}

def fresh_run(review_id: str) -> LiveRun;

def FeedRow(item: FeedItem) -> JsxElement;

def TabButton(
    name: str, label: str, active: bool, count: int, onPick: Callable[[str], None]
) -> JsxElement;

glob STAGE_LABELS: dict[str, str] = {
    "plan": "Plan",
    "review": "Specialist lenses",
    "cross": "Cross-file",
    "investigate": "Investigate (routing)",
    "verify": "Verify",
    "synthesize": "Synthesize",
};
def CostPanel(rv: ReviewView) -> JsxElement;

def:pub ReviewWorkspace(pr_id: str) -> JsxElement;
