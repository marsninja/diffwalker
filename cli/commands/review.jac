"""`review`: the pipeline run in this program, or on the server while this terminal follows
its live stream."""
import json;
import threading;
import from stdjac.remote { RemoteError, RemoteRejected }

glob STAGE_GLYPH: dict[str, str] = {"running": "◌", "done": "✓", "failed": "✗", "skipped": "–"};

"""Print what a review's event says. False once the review has ended."""
def show_event(evt: LiveEvent, pr_id: str) -> bool {
    if evt.kind != "review" {
        return True;
    }
    d = evt.data;
    if d.pr_id and d.pr_id != pr_id {
        return True;
    }
    ph = d.phase;
    if ph == "start" {
        print(bold(violet("▸ review " + d.review_id)) + dim("  " + d.title[:70]));
    } elif ph == "stage" and d.status in ("done", "failed", "skipped") {
        label = STAGE_GLYPH.get(d.status, "·") + " " + d.stage.ljust(12);
        if d.status == "done" {
            label = green(label);
        } elif d.status == "failed" {
            label = red(label);
        } else {
            label = dim(label);
        }
        print("  " + label + dim(d.detail[:96]));
    } elif ph == "drafts" {
        for x in d.drafts {
            print("      " + sev_paint(x.severity, "draft " + x.severity.ljust(9)) + x.title[:80]);
        }
    } elif ph == "drop" {
        print("      " + red("✗ dropped: ") + dim(d.title[:60] + "  " + d.detail[:60]));
    } elif ph == "investigate" {
        print("      " + violet("⌕ ") + dim(d.title[:100]));
    } elif ph == "warn" {
        print("      " + yellow("! ") + dim(d.title[:100]));
    } elif ph == "failed" {
        print(red("✗ review failed: ") + d.error);
        return False;
    } elif ph == "done" {
        return False;
    }
    return True;
}

def print_result(review_id: str, as_json: bool) -> int {
    rv = find_review(review_id);
    if rv is None {
        warn(red("diffwalker: review vanished"));
        return EXIT_FAILURE;
    }
    fs = review_findings(rv);
    if as_json {
        print(
            json.dumps(
                {
                    "review": {
                        "id": rv.id,
                        "status": rv.status,
                        "verdict": rv.verdict,
                        "risk": rv.risk,
                        "summary": rv.summary,
                        "cost": rv.cost,
                        "tokens": rv.tokens,
                        "llm_calls": rv.llm_calls,
                    },
                    "findings": [
                        {
                            "id": f.id,
                            "severity": f.severity,
                            "category": f.category,
                            "path": f.path,
                            "line": f.line,
                            "title": f.title,
                            "body": f.body,
                        }
                        for f in fs
                    ],
                },
                indent=2,
            ),
        );
        return EXIT_OK;
    }
    print("");
    tone = green
        if rv.verdict == "approve"
        else (red if rv.verdict == "request_changes" else yellow);
    print(
        bold("verdict: ")
            + tone(rv.verdict or rv.status)
            + dim(
                f"   risk {rv.risk}/100   {len(fs)} findings   {rv.llm_calls} model calls   {rv.tokens} tokens   ${rv.cost}",
            ),
    );
    for c in rv.costs {
        print(
            dim(f"    {c.stage:<12} {c.calls:>3} calls {c.tokens:>8} tokens  ${round(c.cost, 4)}")
        );
    }
    if rv.error {
        print(red("  " + rv.error));
    }
    if rv.summary {
        print("");
        print("  " + rv.summary.replace("\n", "\n  "));
    }
    for f in fs {
        print("");
        print(
            "  " + sev_paint(f.severity, f"[{f.severity}]") + " " + bold(f.title) + dim(f"  {f.id}")
        );
        print(dim(f"    {f.path}:{f.line} · {f.category}"));
        print("    " + f.body.replace("\n", "\n    ")[:600]);
    }
    return EXIT_OK if rv.verdict != "request_changes" else EXIT_FAILURE;
}

def run_review_offline(repo: str, pr_id: str, focus: str, as_json: bool) -> int {
    pr = find_pr(repo, pr_id);
    if pr is None {
        warn(red("diffwalker: no pull request " + pr_id) + dim("  (list them with `prs`)"));
        return EXIT_USAGE;
    }
    if not llm_ready() {
        warn(yellow("no ANTHROPIC_API_KEY: running the deterministic stages only"));
    }
    pid = pr.id;
    if not as_json {
        tap(lambda (evt: LiveEvent) { show_event(evt, pid) });
    }
    rid = run_review(repo, pr, focus, "cli");
    return print_result(rid, as_json);
}

"""What became of the call that started a review on the server."""
obj Started {
    has brief: ReviewBrief | None = None,
        error: str = "",
        rejected: bool = False;
}

"""Start the review on the server and note how the call ended. The call returns when the
review does, however long that takes."""
def start_on_server(pr_id: str, focus: str, session: str, started: Started) {
    try {
        started.brief = start_review(pr_id, focus, session);
    } except RemoteError as e {
        started.error = str(e);
        started.rejected = isinstance(e, RemoteRejected);
    }
}

"""Run the review on a server: the walker runs there, this terminal and every open
browser of the same user follow it on the live stream."""
def run_review_live(server: str, pr_id: str, focus: str) -> int {
    use_server(server);
    started = Started();
    worker: threading.Thread | None = None;
    try {
        for evt in live(0) {
            if worker is None {
                if evt.kind == "hello" {
                    worker = threading.Thread(
                        target=start_on_server,
                        args=(pr_id, focus, "cli-review", started),
                        daemon=True,
                    );
                    worker.start();
                    print(dim("watching " + server + " · the browser shows the same run"));
                    continue;
                }
            } elif evt.kind == "ping" and not worker.is_alive() {
                break;
            }
            if not show_event(evt, pr_id) {
                break;
            }
        }
    } except RemoteError as e {
        return unreachable(server, e);
    }
    if worker is not None {
        worker.join(5);
    }
    if started.error {
        warn(red("diffwalker: " + started.error[:200]));
        return EXIT_UNAVAILABLE if started.rejected else EXIT_USAGE;
    }
    brief = started.brief;
    if brief is None {
        brief = ReviewBrief();
    }
    if brief.status == "missing" {
        warn(red("diffwalker: no pull request " + pr_id) + dim("  (list them with `prs`)"));
        return EXIT_USAGE;
    }
    if brief.status == "busy" {
        warn(yellow("a review of " + pr_id + " is already running on the server"));
        return EXIT_FAILURE;
    }
    print(
        green("done")
            + dim(
                f" · {brief.verdict} · risk {brief.risk} · {brief.findings} findings · ${brief.cost} · open "
                    + server
                    + "/reviews/"
                    + pr_id,
            ),
    );
    return EXIT_OK if brief.verdict != "request_changes" else EXIT_FAILURE;
}
