glob ICONS: dict[str, str] = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🔵", "info": "⚪"},
     VERDICTS: dict[str, str] = {
         "approve": "✅ Approve",
         "comment": "💬 Comment",
         "request_changes": "⛔ Request changes",
     };

def review_markdown(rv: Review, findings: list[Finding]) -> str;
