glob SEV_COLOR: dict[str, str] = {
         "critical": "var(--status-critical)",
         "high": "var(--status-serious)",
         "medium": "var(--status-warning)",
         "low": "var(--sev-low)",
         "info": "var(--sev-info)"
     };

glob:pub SEV_LABEL: dict[str, str] = {
         "critical": "Critical",
         "high": "High",
         "medium": "Medium",
         "low": "Low",
         "info": "Info"
     };

glob VERDICT_LABEL: dict[str, str] = {
         "approve": "Approve",
         "comment": "Comment",
         "request_changes": "Changes requested",
         "": "Not reviewed"
     },
     SERIES: list[str] = [
         "var(--series-1)",
         "var(--series-2)",
         "var(--series-3)",
         "var(--series-4)",
         "var(--series-5)",
         "var(--series-6)",
         "var(--series-7)",
         "var(--series-8)"
     ],
     LANG_COLOR_ORDER: list[str] = [
         "Python",
         "Jac",
         "TypeScript",
         "JavaScript",
         "Markdown",
         "Rust",
         "Zig",
         "C"
     ];

def:pub sev_order -> list[str] {
    return ["critical", "high", "medium", "low", "info"];
}

def:pub now_s -> float {
    return Date.now() / 1000;
}

def:pub series_color(i: int) -> str {
    return SERIES[i % 8] if i < 8 else "var(--ink-muted)";
}

def:pub sev_color(sev: str) -> str {
    return SEV_COLOR[sev] or "var(--ink-muted)";
}

def:pub risk_color(score: int) -> str {
    if score >= 70 {
        return "var(--status-critical)";
    }
    if score >= 45 {
        return "var(--status-serious)";
    }
    if score >= 25 {
        return "var(--status-warning)";
    }
    return "var(--status-good)";
}

def:pub risk_label(score: int) -> str {
    if score < 0 {
        return "–";
    }
    if score >= 70 {
        return "High";
    }
    if score >= 45 {
        return "Elevated";
    }
    if score >= 25 {
        return "Moderate";
    }
    return "Low";
}

def:pub verdict_label(v: str) -> str {
    return VERDICT_LABEL[v] or v;
}

def:pub verdict_color(v: str) -> str {
    if v == "approve" {
        return "var(--status-good)";
    }
    if v == "request_changes" {
        return "var(--status-critical)";
    }
    if v == "comment" {
        return "var(--status-warning)";
    }
    return "var(--ink-muted)";
}

def:pub fixed1(n: float) -> str {
    r = round(n * 10) / 10;
    return str(int(r)) if int(r) == r else str(r);
}

def:pub fmt_num(n: float) -> str {
    a = abs(n);
    if a >= 1000000 {
        return fixed1(n / 1000000) + "M";
    }
    if a >= 10000 {
        return str(round(n / 1000)) + "k";
    }
    if a >= 1000 {
        return fixed1(n / 1000) + "k";
    }
    if int(n) == n {
        return str(int(n));
    }
    return fixed1(n);
}

def:pub fmt_bytes(n: int) -> str {
    if n >= 1048576 {
        return fixed1(n / 1048576) + " MB";
    }
    if n >= 1024 {
        return str(round(n / 1024)) + " KB";
    }
    return str(n) + " B";
}

def:pub ago(ts: float) -> str {
    if not ts {
        return "";
    }
    secs = now_s() - ts;
    if secs < 60 {
        return "just now";
    }
    if secs < 3600 {
        return str(int(secs / 60)) + "m ago";
    }
    if secs < 86400 {
        return str(int(secs / 3600)) + "h ago";
    }
    if secs < 86400 * 45 {
        return str(int(secs / 86400)) + "d ago";
    }
    return str(int(secs / 86400 / 30)) + "mo ago";
}

def:pub ago_iso(iso: str) -> str {
    if not iso {
        return "";
    }
    t: float = Date.parse(iso);
    if not t {
        return iso[:10];
    }
    return ago(t / 1000);
}

def:pub base_name(path: str) -> str {
    parts = path.split("/");
    return parts[len(parts) - 1];
}

def:pub dir_name(path: str) -> str {
    parts = path.split("/");
    if len(parts) <= 1 {
        return "";
    }
    return "/".join(parts[:len(parts) - 1]);
}

def:pub short_path(path: str, keep: int = 2) -> str {
    parts = path.split("/");
    if len(parts) <= keep {
        return path;
    }
    return "…/" + "/".join(parts[len(parts) - keep:]);
}

def:pub pct(part: float, whole: float) -> str {
    if not whole {
        return "0%";
    }
    return str(round(100 * part / whole)) + "%";
}
