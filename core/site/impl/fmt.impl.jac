impl sev_order -> list[str] {
    return ["critical", "high", "medium", "low", "info"];
}

impl now_s -> float {
    return Date.now() / 1000;
}

impl series_color(i: int) -> str {
    return SERIES[i % 8] if i < 8 else "var(--ink-muted)";
}

impl sev_color(sev: str) -> str {
    return SEV_COLOR.get(sev, "var(--ink-muted)");
}

impl risk_color(score: int) -> str {
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

impl risk_label(score: int) -> str {
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

impl verdict_label(v: str) -> str {
    return VERDICT_LABEL.get(v, v);
}

impl verdict_color(v: str) -> str {
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

impl num_text(n: float) -> str {
    return str(int(n)) if int(n) == n else str(n);
}

impl fixed1(n: float) -> str {
    return num_text(round(n * 10) / 10);
}

impl fmt_num(n: float) -> str {
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

impl fmt_bytes(n: int) -> str {
    if n >= 1048576 {
        return fixed1(n / 1048576) + " MB";
    }
    if n >= 1024 {
        return str(round(n / 1024)) + " KB";
    }
    return str(n) + " B";
}

impl ago(ts: float) -> str {
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

impl ago_iso(iso: str) -> str {
    if not iso {
        return "";
    }
    t: float = Date.parse(iso);
    if isNaN(t) or not t {
        return iso[:10];
    }
    return ago(t / 1000);
}

impl base_name(path: str) -> str {
    parts = path.split("/");
    return parts[len(parts) - 1];
}

impl dir_name(path: str) -> str {
    parts = path.split("/");
    if len(parts) <= 1 {
        return "";
    }
    return "/".join(parts[:len(parts) - 1]);
}

impl short_path(path: str, keep: int = 2) -> str {
    parts = path.split("/");
    if len(parts) <= keep {
        return path;
    }
    return "…/" + "/".join(parts[len(parts) - keep:]);
}

impl pct(part: float, whole: float) -> str {
    if not whole {
        return "0%";
    }
    return str(round(100 * part / whole)) + "%";
}
