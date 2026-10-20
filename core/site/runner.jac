glob _running: dict[str, bool] = {};

def:pub is_running(pr_id: str) -> bool {
    return bool(_running[pr_id]);
}

"""Start a review and resolve when it finishes. The pipeline runs inside this one request;
every screen of the user follows it on the live stream, so nothing here streams."""
async def:pub launch_review(pr_id: str, focus: str = "") -> bool {
    if _running[pr_id] {
        toast("A review of this pull request is already running", "info");
        return False;
    }
    _running[pr_id] = True;
    publish("review-started", pr_id);
    toast("Review started: watch the pipeline live", "info");
    brief: any = None;
    try {
        brief = await start_review(pr_id, focus, session_id());
    } except Exception as e {
        if "UNAUTHORIZED" in str(e) {
            signed_out();
        } else {
            toast("Review request dropped: " + str(e), "warning");
        }
    }
    _running[pr_id] = False;
    publish("review-finished", pr_id);
    if brief and brief.status == "done" {
        toast("Review complete · " + str(brief.findings) + " findings · $" + str(round(brief.cost * 1000) / 1000), "success");
        return True;
    }
    if brief and brief.status == "busy" {
        toast("A review of this pull request is already running", "info");
    } elif brief and brief.status == "failed" {
        toast("Review failed; the pipeline panel shows where", "warning");
    }
    return False;
}