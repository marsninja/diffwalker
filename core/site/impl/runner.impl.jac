impl is_running(pr_id: str) -> bool {
    return _running.get(pr_id, False);
}

impl launch_review(pr_id: str, focus: str = "") -> bool {
    if _running.get(pr_id, False) {
        toast("A review of this pull request is already running", "info");
        return False;
    }
    _running[pr_id] = True;
    publish("review-started", pr_id);
    toast("Review started: watch the pipeline live", "info");
    brief: ReviewBrief | None = None;
    try {
        brief = await start_review(pr_id, focus, session_id());
    } except RemoteRejected {
        signed_out();
    } except Exception as e {
        toast("Review request dropped: " + str(e), "warning");
    }
    _running[pr_id] = False;
    publish("review-finished", pr_id);
    if brief and brief.status == "done" {
        toast(
            "Review complete · "
                + str(brief.findings)
                + " findings · $"
                + num_text(round(brief.cost * 1000) / 1000),
            "success",
        );
        return True;
    }
    if brief and brief.status == "busy" {
        toast("A review of this pull request is already running", "info");
    } elif brief and brief.status == "failed" {
        toast("Review failed; the pipeline panel shows where", "warning");
    }
    return False;
}
