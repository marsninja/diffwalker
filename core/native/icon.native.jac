import from "lucide-react-native" {
    Inbox,
    ScanSearch,
    Activity,
    Sparkles,
    GitBranch,
    Github,
    PencilLine,
    Check,
    X,
    RotateCcw,
    Send,
    ChevronRight,
    ChevronLeft,
    Play,
    CircleCheck,
    CircleX,
    MessageSquare,
    Flame,
    Wrench,
    LoaderCircle,
    Minus,
    Circle
}

glob LUCIDE: dict[str, any] = {
         "inbox": Inbox,
         "review": ScanSearch,
         "insights": Activity,
         "copilot": Sparkles,
         "branch": GitBranch,
         "github": Github,
         "worktree": PencilLine,
         "check": Check,
         "close": X,
         "reopen": RotateCcw,
         "send": Send,
         "next": ChevronRight,
         "back": ChevronLeft,
         "play": Play,
         "approve": CircleCheck,
         "request_changes": CircleX,
         "comment": MessageSquare,
         "flame": Flame,
         "tool": Wrench,
         "running": LoaderCircle,
         "skipped": Minus,
         "pending": Circle,
         "done": Check,
         "failed": X
     };

def:pub Icon(name: str, size: int, color: str) -> JsxElement {
    Glyph = LUCIDE[name] or LUCIDE["pending"];
    return <Glyph size={size} color={color} strokeWidth={2}/>;
}
