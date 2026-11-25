import from "lucide-react" {
    Check,
    X,
    RotateCcw,
    MessageCircle,
    Sparkles,
    ShieldCheck,
    FileCode2,
    Bot,
    User,
    Send,
}

glob SOURCE_LABEL: dict[str, str] = {
    "static": "static analysis",
    "lens:batch": "batch lens",
    "lens:cross-file": "cross-file pass",
    "copilot": "Copilot",
    "you": "you",
    "agent": "agent",
};

def source_label(src: str) -> str;

def:pub FindingCard(
    f: Finding,
    onChanged: Callable[[], Coroutine[any, any, None]] | None = None,
    onJump: Callable[[Finding], None] | None = None,
    inline: bool = False,
    flash: bool = False,
) -> JsxElement;
