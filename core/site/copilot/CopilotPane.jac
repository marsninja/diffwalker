import from "@jac/runtime" { RemoteRejected }
import from "lucide-react" {
    Sparkles,
    X,
    SquarePen,
    ArrowUp,
    Compass,
    GitPullRequest,
    FileCode2,
    Filter,
    Activity,
    Bell,
    FolderGit2,
    List,
    FileDiff,
    Search,
    History,
    Flame,
    Users,
    Network,
    MessageSquarePlus,
    CircleCheck,
    MessageCircle,
    BarChart3,
    Table2,
    Workflow,
    FileDown,
    Github,
    ScanSearch,
    ChevronRight,
    LoaderCircle,
    Brain,
    Terminal,
    Square,
}

obj ToolMeta {
    has label: str,
        icon: any;
}

obj Usage {
    has tokens: int = 0,
        cost: float = 0.0,
        requests: int = 0;
}

obj Item {
    has kind: str,
        tool: str = "",
        id: str = "",
        args: any = None,
        result: str = "",
        done: bool = False,
        card: Card = Card(),
        text: str = "";
}

obj Message {
    has role: str,
        text: str = "",
        items: list[Item] = [],
        done: bool = True,
        usage: Usage | None = None;
    def having(
        text: str | None = None,
        items: list[Item] | None = None,
        done: bool | None = None,
        usage: Usage | None = None,
    ) -> Message;
}

obj Shown {
    has messages: list[Message] = [],
        busy: bool = False,
        tid: str = "",
        path: str = "",
        search: str = "";
}

glob NL: str = chr(10),
     TOOL_META: dict[str, ToolMeta] = {
         "navigate": ToolMeta(label="Navigating", icon=Compass),
         "open_pull_request": ToolMeta(label="Opening pull request", icon=GitPullRequest),
         "focus_file": ToolMeta(label="Jumping to code", icon=FileCode2),
         "filter_findings": ToolMeta(label="Filtering findings", icon=Filter),
         "show_insights": ToolMeta(label="Opening analytics", icon=Activity),
         "notify": ToolMeta(label="Notifying", icon=Bell),
         "switch_repository": ToolMeta(label="Switching repository", icon=FolderGit2),
         "list_pull_requests": ToolMeta(label="Scanning pull requests", icon=List),
         "pull_request_details": ToolMeta(label="Inspecting pull request", icon=GitPullRequest),
         "file_diff": ToolMeta(label="Reading diff", icon=FileDiff),
         "read_file": ToolMeta(label="Reading file", icon=FileCode2),
         "search_code": ToolMeta(label="Searching code", icon=Search),
         "blame": ToolMeta(label="Running blame", icon=History),
         "repo_overview": ToolMeta(label="Profiling repository", icon=FolderGit2),
         "hotspot_report": ToolMeta(label="Ranking hotspots", icon=Flame),
         "contributor_report": ToolMeta(label="Analyzing contributors", icon=Users),
         "ownership_report": ToolMeta(label="Mapping ownership", icon=Users),
         "coupling_report": ToolMeta(label="Finding coupled files", icon=Network),
         "activity_report": ToolMeta(label="Reading activity", icon=Activity),
         "list_findings": ToolMeta(label="Listing findings", icon=List),
         "review_pull_request": ToolMeta(label="Running full agentic review", icon=ScanSearch),
         "post_comment": ToolMeta(label="Posting review comment", icon=MessageSquarePlus),
         "update_finding": ToolMeta(label="Updating finding", icon=CircleCheck),
         "reply_to_finding": ToolMeta(label="Replying in thread", icon=MessageCircle),
         "render_chart": ToolMeta(label="Rendering chart", icon=BarChart3),
         "render_table": ToolMeta(label="Rendering table", icon=Table2),
         "render_diagram": ToolMeta(label="Drawing diagram", icon=Workflow),
         "export_review": ToolMeta(label="Exporting review", icon=FileDown),
         "publish_to_github": ToolMeta(label="Preparing GitHub publish", icon=Github),
     };
def tool_args(text: str) -> any;

def tool_detail(tool: str, args: any) -> str;

def suggestions_for(path: str) -> list[str];

def ToolChip(item: Item) -> JsxElement;

def AssistantMsg(msg: Message, onPin: Callable[[Card], Coroutine[any, any, None]]) -> JsxElement;

def from_transcript(transcript: list[ChatMsg]) -> list[Message];

def:pub CopilotPane(path: str, search: str) -> JsxElement;
