glob SEV_COLOR: dict[str, str] = {
    "critical": "var(--status-critical)",
    "high": "var(--status-serious)",
    "medium": "var(--status-warning)",
    "low": "var(--sev-low)",
    "info": "var(--sev-info)",
};

glob:pub SEV_LABEL: dict[str, str] = {
    "critical": "Critical",
    "high": "High",
    "medium": "Medium",
    "low": "Low",
    "info": "Info",
};

glob VERDICT_LABEL: dict[str, str] = {
         "approve": "Approve",
         "comment": "Comment",
         "request_changes": "Changes requested",
         "": "Not reviewed",
     },
     SERIES: list[str] = [
         "var(--series-1)",
         "var(--series-2)",
         "var(--series-3)",
         "var(--series-4)",
         "var(--series-5)",
         "var(--series-6)",
         "var(--series-7)",
         "var(--series-8)",
     ],
     LANG_COLOR_ORDER: list[str] = [
         "Python",
         "Jac",
         "TypeScript",
         "JavaScript",
         "Markdown",
         "Rust",
         "Zig",
         "C",
     ];

def:pub sev_order -> list[str];

def:pub now_s -> float;

def:pub series_color(i: int) -> str;

def:pub sev_color(sev: str) -> str;

def:pub risk_color(score: int) -> str;

def:pub risk_label(score: int) -> str;

def:pub verdict_label(v: str) -> str;

def:pub verdict_color(v: str) -> str;
def:pub num_text(n: float) -> str;

def:pub fixed1(n: float) -> str;

def:pub fmt_num(n: float) -> str;

def:pub fmt_bytes(n: int) -> str;

def:pub ago(ts: float) -> str;

def:pub ago_iso(iso: str) -> str;

def:pub base_name(path: str) -> str;

def:pub dir_name(path: str) -> str;

def:pub short_path(path: str, keep: int = 2) -> str;

def:pub pct(part: float, whole: float) -> str;
