import from "@jac/mobui" { StyleSheet }

obj Colors {
    has bg: str = "#0d0c12",
        surface: str = "#16151d",
        raised: str = "#1d1c26",
        border: str = "#2a2934",
        text: str = "#ecebf3",
        muted: str = "#8f8da0",
        accent: str = "#7c5cff",
        accentSoft: str = "rgba(124,92,255,0.16)",
        accentText: str = "#ffffff",
        good: str = "#0ca30c",
        warning: str = "#fab219",
        serious: str = "#ec835a",
        critical: str = "#d03b3b",
        low: str = "#3987e5",
        info: str = "#898781",
        add: str = "#1baf7a",
        rem: str = "#e66767";
}

obj Spacing {
    has xs: int = 4,
        sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 20,
        xxl: int = 28;
}

obj Radii {
    has sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 22,
        pill: int = 999;
}

glob:pub C: Colors = Colors(),
     S: Spacing = Spacing(),
     R: Radii = Radii();

def:pub sev_tone(sev: str) -> str {
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

def:pub risk_tone(score: int) -> str {
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

def:pub verdict_tone(v: str) -> str {
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

glob:pub styles: any = StyleSheet.create(
         {
             "root": {"flex": 1, "backgroundColor": C.bg},
             "header": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": S.sm,
                 "paddingHorizontal": S.lg,
                 "paddingVertical": S.md,
                 "borderBottomWidth": 1,
                 "borderBottomColor": C.border
             },
             "brandMark": {
                 "width": 30,
                 "height": 30,
                 "borderRadius": 9,
                 "backgroundColor": C.accent,
                 "alignItems": "center",
                 "justifyContent": "center"
             },
             "title": {"color": C.text, "fontSize": 17, "fontWeight": "700"},
             "subtitle": {"color": C.muted, "fontSize": 12},
             "body": {"flex": 1},
             "scroll": {"padding": S.lg, "gap": S.md, "paddingBottom": 40},
             "card": {
                 "backgroundColor": C.surface,
                 "borderRadius": R.lg,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "padding": S.lg,
                 "gap": S.sm
             },
             "row": {"flexDirection": "row", "alignItems": "center", "gap": S.sm},
             "between": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "justifyContent": "space-between",
                 "gap": S.sm
             },
             "h1": {"color": C.text, "fontSize": 20, "fontWeight": "700"},
             "h2": {"color": C.text, "fontSize": 15, "fontWeight": "700"},
             "text": {"color": C.text, "fontSize": 14, "lineHeight": 20},
             "small": {"color": C.muted, "fontSize": 12, "lineHeight": 17},
             "tiny": {"color": C.muted, "fontSize": 10.5, "letterSpacing": 0.6},
             "mono": {
                 "color": C.muted,
                 "fontSize": 11.5,
                 "fontFamily": "Geist Mono Variable, Menlo, monospace"
             },
             "statRow": {"flexDirection": "row", "gap": S.sm},
             "stat": {
                 "flex": 1,
                 "backgroundColor": C.surface,
                 "borderRadius": R.md,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "padding": S.md
             },
             "statValue": {
                 "color": C.text,
                 "fontSize": 22,
                 "fontWeight": "700",
                 "marginTop": 2
             },
             "pill": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": 4,
                 "paddingHorizontal": 8,
                 "paddingVertical": 3,
                 "borderRadius": R.pill,
                 "alignSelf": "flex-start"
             },
             "pillText": {"fontSize": 11, "fontWeight": "700"},
             "track": {
                 "height": 6,
                 "borderRadius": 3,
                 "backgroundColor": C.raised,
                 "overflow": "hidden",
                 "flex": 1
             },
             "primaryBtn": {
                 "backgroundColor": C.accent,
                 "borderRadius": R.pill,
                 "paddingVertical": 11,
                 "paddingHorizontal": S.lg,
                 "flexDirection": "row",
                 "alignItems": "center",
                 "justifyContent": "center",
                 "gap": 6
             },
             "primaryLabel": {
                 "color": C.accentText,
                 "fontSize": 14,
                 "fontWeight": "700"
             },
             "ghostBtn": {
                 "borderRadius": R.pill,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "paddingVertical": 7,
                 "paddingHorizontal": S.md,
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": 5
             },
             "ghostLabel": {"color": C.text, "fontSize": 12, "fontWeight": "600"},
             "tabBar": {
                 "flexDirection": "row",
                 "borderTopWidth": 1,
                 "borderTopColor": C.border,
                 "backgroundColor": C.bg,
                 "paddingTop": S.sm,
                 "paddingBottom": S.md
             },
             "tab": {"flex": 1, "alignItems": "center", "gap": 3},
             "tabLabel": {"fontSize": 10.5, "fontWeight": "600"},
             "bubbleMe": {
                 "alignSelf": "flex-end",
                 "maxWidth": "85%",
                 "backgroundColor": C.accent,
                 "borderRadius": R.lg,
                 "borderBottomRightRadius": 4,
                 "paddingHorizontal": S.md,
                 "paddingVertical": S.sm
             },
             "bubbleBot": {
                 "alignSelf": "flex-start",
                 "maxWidth": "92%",
                 "backgroundColor": C.surface,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.lg,
                 "borderBottomLeftRadius": 4,
                 "padding": S.md,
                 "gap": 6
             },
             "input": {
                 "flex": 1,
                 "color": C.text,
                 "fontSize": 14,
                 "paddingVertical": 10,
                 "paddingHorizontal": S.md,
                 "backgroundColor": C.surface,
                 "borderRadius": R.pill,
                 "borderWidth": 1,
                 "borderColor": C.border
             },
             "sendBtn": {
                 "width": 40,
                 "height": 40,
                 "borderRadius": 20,
                 "backgroundColor": C.accent,
                 "alignItems": "center",
                 "justifyContent": "center"
             },
             "chip": {
                 "borderRadius": R.md,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "paddingHorizontal": S.md,
                 "paddingVertical": S.sm,
                 "backgroundColor": C.surface
             }
         }
     );
