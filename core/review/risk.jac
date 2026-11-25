import math;
import re;

obj StaticHit {
    has path: str = "",
        line: int = 0,
        severity: str = "medium",
        category: str = "security",
        title: str = "",
        body: str = "";
}

glob SENSITIVE: list[str] = [
         "auth",
         "security",
         "crypto",
         "password",
         "secret",
         "token",
         "session",
         "permission",
         "payment",
         "billing",
         "migration",
         "schema",
         "deploy",
         ".github/workflows",
         "dockerfile",
         "sql",
         "config",
     ],
     LOW_RISK_LANGS: list[str] = ["Markdown", "Docs", "Text", "Lockfile", "SVG"],
     PATTERNS: list[list[str]] = [
         [
             "(?<![A-Za-z0-9_-])(?:sk-ant-[A-Za-z0-9_-]{20,}|sk-(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|xox[bpas]-[A-Za-z0-9-]{10,})",
             "critical",
             "security",
             "Possible hard-coded credential",
         ],
         [
             "(?i)(password|passwd|secret|api_key)\\s*[=:]\\s*['\"][^'\"]{4,}",
             "high",
             "security",
             "Literal secret assigned in code",
         ],
         ["(?<![.\\w])(?:eval|exec)\\(", "high", "security", "Dynamic code execution"],
         ["shell\\s*=\\s*True|os\\.system\\(", "high", "security", "Shell command execution"],
         [
             "pickle\\.loads?\\(|yaml\\.load\\((?!.*Loader)",
             "medium",
             "security",
             "Unsafe deserialization",
         ],
         [
             "innerHTML\\s*=|dangerouslySetInnerHTML|unsafe_html\\(",
             "medium",
             "security",
             "Raw HTML injection point",
         ],
         [
             "except\\s*(Exception)?\\s*(as \\w+)?\\s*[:{]\\s*(pass|\\{\\s*\\})",
             "medium",
             "reliability",
             "Exception swallowed silently",
         ],
         ["\\b(TODO|FIXME|HACK|XXX)\\b", "info", "maintainability", "New TODO/FIXME left in code"],
         [
             "console\\.log\\(|\\bbreakpoint\\(\\)|\\bpdb\\.set_trace",
             "low",
             "style",
             "Debug statement left in",
         ],
         [
             "verify\\s*=\\s*False|rejectUnauthorized\\s*:\\s*false",
             "high",
             "security",
             "TLS verification disabled",
         ],
     ];

def file_kind(path: str, language: str) -> str;

def static_hits(f: FileDiff) -> list[StaticHit];

def score_file(f: FileDiff, has_tests: bool, hotspot_rank: dict[str, int]) -> FileRisk;

def triage(files: list[FileDiff], hotspot_paths: list[str]) -> list[FileRisk];

def overall_risk(risks: list[FileRisk]) -> int;
