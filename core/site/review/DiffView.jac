import from "lucide-react" {
    Plus,
    FileCode2,
    FilePlus2,
    FileMinus2,
    FileSymlink,
    MessageSquare,
    X,
    ChevronDown,
    ChevronRight,
}

def status_icon(status: str) -> any;

def FileRow(
    f: FileDiff, risk: int, count: int, active: bool, onPick: Callable[[str], None]
) -> JsxElement;

def CommentForm(
    pr_id: str, path: str, line: int, onDone: Callable[[bool], Coroutine[any, any, None]]
) -> JsxElement;

def:pub FileDiffView(
    pr_id: str,
    f: FileDiff,
    findings: list[Finding],
    focusLine: int = 0,
    flashKey: str = "",
    onChanged: Callable[[], Coroutine[any, any, None]] | None = None,
) -> JsxElement;

def:pub FileList(
    files: list[FileDiff],
    risks: list[FileRisk],
    findings: list[Finding],
    active: str,
    onPick: Callable[[str], None],
) -> JsxElement;
