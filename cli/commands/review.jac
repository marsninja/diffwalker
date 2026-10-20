import json;
import threading;

glob STAGE_GLYPH: dict[str, str] = {
         "running": "◌",
         "done": "✓",
         "failed": "✗",
         "skipped": "–"
     };

def show_event(evt: dict[str, any], pr_id: str) -> bool {
    if evt.get("kind") != "review" {
        return True;
    }
    d: dict[str, any] = evt.get("data") or {};
    if d.get("pr_id") and d.get("pr_id") != pr_id {
        return True;
    }
    ph = d.get("phase", "");
    if ph == "start" {
        print(
            bold(violet("▸ review " + str(d.get("review_id", ""))))
                + dim("  " + str(d.get("title", ""))[:70])
        );
    } elif ph == "stage" and d.get("status") in ("done", "failed", "skipped") {
        status = str(d.get("status", ""));
        label = STAGE_GLYPH.get(status, "·") + " " + str(d.get("stage", "")).ljust(12);
        if status == "done" {
            label = green(label);
        } elif status == "failed" {
            label = red(label);
        } else {
            label = dim(label);
        }
        print("  " + label + dim(str(d.get("detail", ""))[:96]));
    } elif ph == "drafts" {
        drafts: list[dict[str, any]] = d.get("drafts", []) or [];
        for x in drafts {
            sev = str(x.get("severity", ""));
            print(
                "      "
                    + sev_paint(sev, "draft " + sev.ljust(9))
                    + str(x.get("title", ""))[:80]
            );
        }
    } elif ph == "drop" {
        print("      " + red("✗ dropped: ") + dim(str(d.get("title", ""))[:60] + "  " + str(d.get("detail", ""))[:60]));
    } elif ph == "investigate" {
        print("      " + violet("⌕ ") + dim(str(d.get("title", ""))[:100]));
    } elif ph == "warn" {
        print("      " + yellow("! ") + dim(str(d.get("title", ""))[:100]));
    } elif ph == "failed" {
        print(red("✗ review failed: ") + str(d.get("error", "")));
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
                        "llm_calls": rv.llm_calls
                    },
                    "findings": [
                        {
                            "id": f.id,
                            "severity": f.severity,
                            "category": f.category,
                            "path": f.path,
                            "line": f.line,
                            "title": f.title,
                            "body": f.body
                        } for f in fs
                    ]
                },
                indent=2
            )
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
                f"   risk {rv.risk}/100   {len(fs)} findings   {rv.llm_calls} model calls   {rv.tokens} tokens   ${rv.cost}"
            )
    );
    for c in rv.costs {
        print(dim(f"    {c.stage:<12} {c.calls:>3} calls {c.tokens:>8} tokens  ${round(c.cost, 4)}"));
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
            "  "
                + sev_paint(f.severity, f"[{f.severity}]")
                + " "
                + bold(f.title)
                + dim(f"  {f.id}")
        );
        print(dim(f"    {f.path}:{f.line} · {f.category}"));
        print("    " + f.body.replace("\n", "\n    ")[:600]);
    }
    return EXIT_OK if rv.verdict != "request_changes" else EXIT_FAILURE;
}

def run_review_offline(repo: str, pr_id: str, focus: str, as_json: bool) -> int {
    pr = find_pr(repo, pr_id);
    if pr is None {
        warn(
            red("diffwalker: no pull request " + pr_id)
                + dim("  (list them with `prs`)")
        );
        return EXIT_USAGE;
    }
    if not llm_ready() {
        warn(yellow("no ANTHROPIC_API_KEY: running the deterministic stages only"));
    }
    pid = pr.id;
    if not as_json {
        tap(lambda (evt: dict[str, any]) { show_event(evt, pid); });
    }
    rid = run_review(repo, pr, focus, "cli");
    return print_result(rid, as_json);
}

"""Run the review on a server: the walker runs there, this terminal and every open
browser of the same user follow it on the live stream."""
def run_review_live(server: str, pr_id: str, focus: str) -> int {
    session = "cli-review";
    outcome: dict[str, any] = {};
    def trigger {
        try {
            outcome["brief"] = post_json(server, "start_review", {"pr_id": pr_id, "focus": focus, "session": session}, 1800);
        } except Exception as e {
            outcome["error"] = str(e);
        }
    }
    worker: list[any] = [None];
    def on_live(evt: dict[str, any]) -> bool {
        if evt.get("kind") == "hello" and worker[0] is None {
            worker[0] = threading.Thread(target=trigger, daemon=True);
            worker[0].start();
            print(dim("watching " + server + " · the browser shows the same run"));
            return True;
        }
        if evt.get("kind") == "ping" and worker[0] is not None and not worker[0].is_alive() {
            return False;
        }
        return show_event(evt, pr_id);
    }
    try {
        post_sse(server, "live", {"after": 0}, on_live);
    } except Exception as e {
        return unreachable(server, e);
    }
    if worker[0] is not None {
        worker[0].join(5);
    }
    if "error" in outcome {
        warn(red("diffwalker: " + str(outcome["error"])[:200]));
        return EXIT_USAGE if "UNAUTHORIZED" not in str(outcome["error"]) else EXIT_UNAVAILABLE;
    }
    brief: dict[str, any] = outcome.get("brief") or {};
    status = str(brief.get("status", ""));
    if status == "missing" {
        warn(red("diffwalker: no pull request " + pr_id) + dim("  (list them with `prs`)"));
        return EXIT_USAGE;
    }
    if status == "busy" {
        warn(yellow("a review of " + pr_id + " is already running on the server"));
        return EXIT_FAILURE;
    }
    print(
        green("done") + dim(f" · {brief.get('verdict', status)} · risk {brief.get('risk', 0)} · {brief.get('findings', 0)} findings · ${brief.get('cost', 0)} · open " + server + "/reviews/" + pr_id)
    );
    return EXIT_OK if brief.get("verdict") != "request_changes" else EXIT_FAILURE;
}
