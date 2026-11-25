impl sev_tone(sev: str) -> str {
    if sev == "critical" {
        return C.critical;
    }
    if sev == "high" {
        return C.serious;
    }
    if sev == "medium" {
        return C.warning;
    }
    if sev == "low" {
        return C.low;
    }
    return C.info;
}

impl risk_tone(score: int) -> str {
    if score >= 70 {
        return C.critical;
    }
    if score >= 45 {
        return C.serious;
    }
    if score >= 25 {
        return C.warning;
    }
    return C.good;
}

impl verdict_tone(v: str) -> str {
    if v == "approve" {
        return C.good;
    }
    if v == "request_changes" {
        return C.critical;
    }
    if v == "comment" {
        return C.warning;
    }
    return C.muted;
}
