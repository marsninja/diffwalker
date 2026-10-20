"""Graph mutations shared by the HTTP endpoints and the Copilot's tools.

One implementation per action, so a button and the agent can never drift apart.
Each runs in the caller's request context, commits, and tells the caller's screens.
"""
def _manual_review(pr_n: PullRequest, repo: str, pr_id: str, source: str) -> Review {
    rv = review_of(pr_n, "done");
    if rv {
        return rv;
    }
    rv = Review(
        id=new_id("R"),
        pr_id=pr_id,
        repo=repo,
        status="done",
        verdict="comment",
        summary="Comments added by hand.",
        started=now(),
        finished=now(),
        trigger=source
    );
    pr_n +>:HasReview:+> rv;
    return rv;
}

"""Add a comment to the PR's latest review, anchored to a line the diff shows. None if the file is not in the change."""
def add_finding(
    repo: str,
    pr: PullRequestRef,
    path: str,
    line: int,
    severity: str,
    category: str,
    title: str,
    body: str,
    suggestion: str,
    source: str
) -> Finding | None {
    diffs = {f.path: f for f in parse_unified_diff(pr_diff_text(repo, pr))};
    d = Draft(
        id=new_id("D"),
        path=path.strip().lstrip("./"),
        line=line,
        end_line=line,
        severity=severity if severity in SEVERITIES else "medium",
        category=category if category in CATEGORIES else "correctness"
    );
    if not anchor(d, diffs) {
        return None;
    }
    info = repo_info(repo);
    pr_n = ensure_pr(ensure_repo(info.path, info.name), pr.id, pr.kind, pr.title, pr.head, pr.base, pr.author, pr.url, pr.number);
    rv = _manual_review(pr_n, info.path, pr.id, source);
    fc = file_change(rv, d.path);
    if fc is None {
        f = diffs[d.path];
        fc = FileChange(path=f.path, old_path=f.old_path, status=f.status, language=f.language, additions=f.additions, deletions=f.deletions, state="reviewed");
        rv +>:Covers:+> fc;
    }
    made = Finding(
        id=new_id("F"),
        review_id=rv.id,
        pr_id=pr.id,
        path=d.path,
        line=d.line,
        end_line=d.line,
        severity=d.severity,
        category=d.category,
        title=title,
        body=body,
        suggestion=suggestion,
        source=source,
        verified=True,
        anchored=d.anchored,
        created=now()
    );
    fc +>:Raised:+> made;
    fc.findings += 1;
    refresh_pr_rollup(pr_n);
    commit();
    changed("finding", {"pr_id": pr.id, "finding": finding_dict(made)});
    return made;
}

def set_status(finding_id: str, status: str, note: str, author: str) -> Finding | None {
    f = find_finding(finding_id.strip());
    if f is None or status not in ("open", "resolved", "dismissed") {
        return None;
    }
    f.status = status;
    if note.strip() {
        f.replies = f.replies + [Reply(author=author, text=note.strip(), ts=now())];
    }
    touch_rollup(f);
    commit();
    changed("finding", {"pr_id": f.pr_id, "finding": finding_dict(f)});
    return f;
}

def add_reply(finding_id: str, text: str, author: str) -> Finding | None {
    f = find_finding(finding_id.strip());
    if f is None or not text.strip() {
        return None;
    }
    f.replies = f.replies + [Reply(author=author, text=text.strip(), ts=now())];
    commit();
    changed("finding", {"pr_id": f.pr_id, "finding": finding_dict(f)});
    return f;
}

def pin_insight(repo: str, title: str, kind: str, caption: str, spec: str) -> Insight {
    info = repo_info(repo);
    ins = Insight(id=new_id("I"), title=title, kind=kind, caption=caption, spec=spec, created=now(), pinned=True);
    ensure_repo(info.path, info.name) +>:Pinned:+> ins;
    commit();
    changed("insight", {"id": ins.id});
    return ins;
}

def unpin_insight(repo: str, insight_id: str) -> bool {
    r = repo_node(repo);
    if r is None {
        return False;
    }
    for ins in [r->:Pinned:->][?:Insight, id == insight_id] {
        del ins;
        commit();
        changed("insight", {"id": insight_id});
        return True;
    }
    return False;
}

"""Point the caller's workspace at a repository; the one place the active repo is set."""
def choose_repo(path: str) -> str {
    top = resolve_repo(path);
    if not top {
        return "";
    }
    info = repo_info(top);
    ws = workspace();
    ws.active_repo = top;
    ws.recent = [top] + [r for r in ws.recent if r != top][:7];
    ensure_repo(top, info.name);
    commit();
    changed("repo", {"path": top});
    return top;
}
