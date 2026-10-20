import math;
import re;

obj FileRisk {
    has path: str = "",
        score: int = 0,
        kind: str = "code",
        signals: list[str] = [],
        additions: int = 0,
        deletions: int = 0,
        language: str = "";
}

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
         "config"
     ],
     LOW_RISK_LANGS: list[str] = ["Markdown", "Docs", "Text", "Lockfile", "SVG"],
     PATTERNS: list[list[str]] = [
         [
             "(?<![A-Za-z0-9_-])(?:sk-ant-[A-Za-z0-9_-]{20,}|sk-(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|xox[bpas]-[A-Za-z0-9-]{10,})",
             "critical",
             "security",
             "Possible hard-coded credential"
         ],
         [
             "(?i)(password|passwd|secret|api_key)\\s*[=:]\\s*['\"][^'\"]{4,}",
             "high",
             "security",
             "Literal secret assigned in code"
         ],
         ["(?<![.\\w])(?:eval|exec)\\(", "high", "security", "Dynamic code execution"],
         [
             "shell\\s*=\\s*True|os\\.system\\(",
             "high",
             "security",
             "Shell command execution"
         ],
         [
             "pickle\\.loads?\\(|yaml\\.load\\((?!.*Loader)",
             "medium",
             "security",
             "Unsafe deserialization"
         ],
         [
             "innerHTML\\s*=|dangerouslySetInnerHTML|unsafe_html\\(",
             "medium",
             "security",
             "Raw HTML injection point"
         ],
         [
             "except\\s*(Exception)?\\s*(as \\w+)?\\s*[:{]\\s*(pass|\\{\\s*\\})",
             "medium",
             "reliability",
             "Exception swallowed silently"
         ],
         [
             "\\b(TODO|FIXME|HACK|XXX)\\b",
             "info",
             "maintainability",
             "New TODO/FIXME left in code"
         ],
         [
             "console\\.log\\(|\\bbreakpoint\\(\\)|\\bpdb\\.set_trace",
             "low",
             "style",
             "Debug statement left in"
         ],
         [
             "verify\\s*=\\s*False|rejectUnauthorized\\s*:\\s*false",
             "high",
             "security",
             "TLS verification disabled"
         ]
     ];

def file_kind(path: str, language: str) -> str {
    p = path.lower();
    name = p.rsplit("/", 1)[-1];
    stem = name.rsplit(".", 1)[0];
    if name.startswith("test_")
        or stem.endswith("_test")
        or stem.endswith("_tests")
        or stem == "tests"
        or stem == "conftest"
        or ".test." in name
        or ".spec." in name
        or "/tests/" in "/" + p
        or "/test/" in "/" + p
        or "/__tests__/" in "/" + p {
        return "test";
    }
    if language in ("Markdown", "Docs", "Text") {
        return "docs";
    }
    if language in ("Lockfile", )
        or name.endswith(".lock")
        or "generated" in p
        or name.endswith(".min.js") {
        return "generated";
    }
    if language in ("JSON", "TOML", "YAML") {
        return "config";
    }
    return "code";
}

def static_hits(f: FileDiff) -> list[StaticHit] {
    hits: list[StaticHit] = [];
    if f.binary or file_kind(f.path, f.language) in ("docs", "generated") {
        return hits;
    }
    seen: set = set();
    for h in f.hunks {
        for ln in h.lines {
            if ln.kind != "add" {
                continue;
            }
            for pat in PATTERNS {
                if pat[3] in seen {
                    continue;
                }
                try {
                    matched = re.search(pat[0], ln.text);
                } except Exception {
                    matched = None;
                }
                if matched {
                    seen.add(pat[3]);
                    hits.append(
                        StaticHit(
                            path=f.path,
                            line=ln.new_no,
                            severity=pat[1],
                            category=pat[2],
                            title=pat[3],
                            body="Pattern `"
                                + matched.group(0)[:60]
                                + "` on an added line."
                        )
                    );
                }
            }
        }
    }
    return hits;
}

def score_file(f: FileDiff, has_tests: bool, hotspot_rank: dict[str, int]) -> FileRisk {
    kind = file_kind(f.path, f.language);
    signals: list[str] = [];
    size = f.additions + f.deletions;
    score = min(30.0, 7.0 * math.log2(1 + size / 8.0));
    if size > 400 {
        signals.append(f"large change ({size} lines)");
    }
    low = f.path.lower();
    for word in SENSITIVE {
        if word in low {
            score += 18;
            signals.append("sensitive area: " + word);
            break;
        }
    }
    if f.path in hotspot_rank {
        rank = hotspot_rank[f.path];
        score += max(4, 22 - rank);
        signals.append(f"history hotspot #{rank + 1}");
    }
    branching = 0;
    for h in f.hunks {
        for ln in h.lines {
            if ln.kind == "add" {
                t = ln.text.strip();
                if t.startswith(
                    (
                        "if ",
                        "elif ",
                        "for ",
                        "while ",
                        "try",
                        "except",
                        "match ",
                        "case ",
                        "switch"
                    )
                ) {
                    branching += 1;
                }
            }
        }
    }
    if branching >= 8 {
        score += min(15, branching);
        signals.append(f"{branching} new branch points");
    }
    if f.status == "added" {
        score += 4;
        signals.append("new file");
    }
    if f.status == "deleted" {
        score = score * 0.4;
        signals.append("deleted file");
    }
    if kind == "code" and not has_tests and size > 20 {
        score += 8;
        signals.append("no tests changed alongside");
    }
    hits = static_hits(f);
    for hit in hits {
        score += {"critical": 30, "high": 16, "medium": 8, "low": 3, "info": 1}.get(
            hit.severity, 0
        );
        signals.append(hit.title.lower());
    }
    if kind in ("docs", "generated") or f.language in LOW_RISK_LANGS {
        score = score * 0.25;
    } elif kind == "test" {
        score = score * 0.6;
    } elif kind == "config" {
        score = score * 0.8;
    }
    return FileRisk(
        path=f.path,
        score=int(min(100.0, score)),
        kind=kind,
        signals=signals,
        additions=f.additions,
        deletions=f.deletions,
        language=f.language
    );
}

def triage(files: list[FileDiff], hotspot_paths: list[str]) -> list[FileRisk] {
    has_tests = len(
        [
            f
            for f in files
            if file_kind(f.path, f.language) == "test"
        ]
    )
        > 0;
    ranks: dict[str, int] = {};
    for (i, p) in enumerate(hotspot_paths) {
        ranks[p] = i;
    }
    scored = [score_file(f, has_tests, ranks) for f in files];
    return sorted(scored, key=lambda (r: FileRisk) -> int { return 0 - r.score; });
}

def overall_risk(risks: list[FileRisk]) -> int {
    if not risks {
        return 0;
    }
    top = sorted([r.score for r in risks], reverse=True)[:5];
    blended = 0.55 * top[0] + 0.45 * (sum(top) / len(top));
    breadth = min(15.0, len(risks) / 3.0);
    return int(min(100.0, blended + breadth));
}
