impl set_agent(ctx: AgentCtx, sink: list[Card]) {
    _ctx.set(ctx);
    _sink.set(sink);
}

impl _repo -> str {
    c = _ctx.get();
    return c.repo if c is not None else "";
}

impl _pr(pr_id: str) -> PullRequestRef | None {
    return find_pr(_repo(), pr_id.strip());
}

impl request_stop(thread: str) {
    with _stops_lock {
        _stops.add(current_user() + "|" + thread);
    }
}

impl clear_stop(thread: str) {
    with _stops_lock {
        _stops.discard(current_user() + "|" + thread);
    }
}

impl turn_guard(ctx: IterationContext) -> IterationAction {
    c = _ctx.get();
    if c is not None {
        with _stops_lock {
            stop = (c.user + "|" + c.thread) in _stops;
        }
        if stop {
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }
    if TURN_BUDGET > 0 and over_budget(ctx.usage, TURN_BUDGET) {
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}

impl navigate(page: str) -> str {
    target = page.strip().lower().lstrip("/");
    if target in ("", "home", "dashboard") {
        ui("navigate", UiArgs(to="/"));
        return "Opened the dashboard.";
    }
    if target in PAGES or target.startswith("reviews/") {
        ui("navigate", UiArgs(to="/" + target));
        return f"Opened /{target}.";
    }
    return f"Unknown page '{page}'. Pages: {', '.join(PAGES)} or reviews/<pr_id>.";
}

impl open_pull_request(pr_id: str, tab: str) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}. Call list_pull_requests first.";
    }
    t = tab if tab in ("overview", "files", "findings") else "overview";
    ui("navigate", UiArgs(to="/reviews/" + pr.id, tab=t));
    return f"Opened {pr.id} ({pr.title}) on the {t} tab.";
}

impl focus_file(pr_id: str, path: str, line: int) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}.";
    }
    ui("navigate", UiArgs(to="/reviews/" + pr.id, tab="files", file=path, line=line));
    return f"Showing {path}:{line} in the diff viewer.";
}

impl filter_findings(severity: str, category: str, status: str) -> str {
    ui("filter", UiArgs(severity=severity, category=category, status=status));
    return f"Finding filters set: severity={severity or 'all'}, category={category or 'all'}, status={status or 'all'}.";
}

impl show_insights(view: str) -> str {
    v = view if view in ("activity", "hotspots", "people", "structure", "coupling") else "activity";
    ui("navigate", UiArgs(to="/insights", view=v));
    return f"Showing the {v} analytics view.";
}

impl notify(message: str, tone: str) -> str {
    ui("toast", UiArgs(message=message[:240], tone=tone));
    return "Shown.";
}

impl switch_repository(path: str) -> str {
    top = choose_repo(path);
    if not top {
        return f"{path} is not a git repository.";
    }
    info = repo_info(top);
    c = _ctx.get();
    if c is not None {
        c.repo = top;
    }
    ui("repo", UiArgs(path=top));
    return f"Switched to {info.name} ({info.commits} commits, base {info.base}).";
}

impl list_pull_requests -> str {
    repo = _repo();
    prs = discover_prs(repo);
    r = repo_node(repo);
    rows: list[str] = [];
    for p in prs {
        n = pr_node(r, p.id) if r else None;
        reviewed = f" reviewed: {n.verdict} risk {n.risk} open {n.open_findings}"
            if n and n.verdict
            else " not reviewed";
        rows.append(
            f"{p.id} [{p.kind}] {p.title[:80]} | {p.head} -> {p.base} | {p.author} | {p.files_changed} files +{p.additions}/-{p.deletions} | updated {p.updated[:10]} |{reviewed}",
        );
    }
    return "\n".join(rows) or "No open branches, GitHub PRs, or uncommitted changes.";
}

impl pull_request_details(pr_id: str) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}.";
    }
    files = parse_unified_diff(pr_diff_text(_repo(), pr));
    risks = triage(files, [h.path for h in hotspots(_repo(), 60)]);
    lines = [
        f"{pr.id}: {pr.title}",
        f"{pr.head} -> {pr.base}, by {pr.author}, {len(files)} files",
        "Description: " + (pr.body[:800] or "(none)"),
        "Commits:",
    ];
    lines = lines + [f"  {c.sha} {c.subject}" for c in pr_commits(_repo(), pr, 15)];
    lines.append("Files by triage risk:");
    lines = lines + [
        f"  {r.score:>3} {r.path} (+{r.additions}/-{r.deletions}) {', '.join(r.signals[:3])}"
        for r in risks[:40]
    ];
    return "\n".join(lines);
}

impl file_diff(pr_id: str, path: str) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}.";
    }
    for f in parse_unified_diff(pr_diff_text(_repo(), pr)) {
        if f.path == path or f.path.endswith("/" + path) {
            return render_file_patch(f, 12000);
        }
    }
    return f"{path} is not part of {pr_id}.";
}

impl read_file(path: str, start_line: int, end_line: int) -> str {
    text = read_text(_repo(), path);
    if not text {
        return f"Cannot read {path}.";
    }
    lines = text.split("\n");
    a = max(1, start_line);
    b = min(len(lines), max(a, end_line), a + 200);
    return f"{path} ({len(lines)} lines)\n"
        + "\n".join([f"{i}: {lines[i - 1]}" for i in range(a, b + 1)]);
}

impl search_code(regex: str, path_glob: str) -> str {
    rows = grep(_repo(), regex, path_glob, 60);
    return "\n".join(rows) if rows else "(no matches)";
}

impl blame(path: str, start_line: int, end_line: int) -> str {
    rows = blame_summary(_repo(), path, start_line, min(end_line, start_line + 60));
    return "\n".join(rows) or "(no blame)";
}

impl repo_overview -> str {
    info = repo_info(_repo());
    s = stats(_repo());
    langs = languages(_repo())[:8];
    total = sum([l.size for l in langs]) or 1;
    return "\n".join([
        f"{info.name} at {info.path}; branch {info.branch}, base {info.base}, github {info.github or 'n/a'}",
        f"{info.commits} commits, {info.files} files, {info.contributors} contributors, since {info.first_commit[:10]}",
        f"Last 90 days: {s.commits_90d} commits by {s.authors_90d} authors, +{s.additions_90d}/-{s.deletions_90d}; busiest day {s.busiest_day} ({s.busiest_count}); bus factor {s.bus_factor}; median commit {s.median_commit_size} lines; test-file ratio {s.test_ratio}",
        "Languages: " + ", ".join([f"{l.language} {round(100 * l.size / total)}%" for l in langs]),
    ]);
}

impl hotspot_report(limit: int) -> str {
    return "\n".join([
        f"{h.score:>7} {h.path} changes={h.changes} churn={h.churn} authors={h.authors} size={h.size}B"
        for h in hotspots(_repo(), max(5, min(limit, 40)))
    ]);
}

impl contributor_report -> str {
    return "\n".join([
        f"{c.name}: {c.commits} commits, +{c.additions}/-{c.deletions}, {c.files} files, mostly {c.top_area}"
        for c in contributors(_repo(), 15)
    ]);
}

impl ownership_report -> str {
    return "\n".join([
        f"{o.area}: {o.owner} owns {round(o.share * 100)}% of {o.commits} commits ({o.authors} authors)"
        for o in ownership(_repo(), 16)
    ]);
}

impl coupling_report -> str {
    g = coupling(_repo());
    return "\n".join([
        f"{e.a} <-> {e.b}: {e.weight} co-changes (strength {e.strength})"
        for e in g.edges[:30]
    ])
        or "(no strong coupling)";
}

impl activity_report -> str {
    rows = [
        f"week {w.week}: {w.commits} commits +{w.additions}/-{w.deletions}"
        for w in weekly(_repo(), 12)
    ];
    for k in kinds_by_month(_repo(), 6) {
        rows.append(f"{k.month}: " + ", ".join([f"{n} {c}" for (n, c) in k.counts.items() if c]));
    }
    return "\n".join(rows);
}

impl _latest_review(pr_id: str) -> Review | None {
    r = repo_node(_repo());
    n = pr_node(r, pr_id) if r else None;
    return review_of(n, "done") if n else None;
}

impl list_findings(pr_id: str, status: str) -> str {
    rv = _latest_review(pr_id);
    if rv is None {
        return f"{pr_id} has no completed review yet.";
    }
    fs = [f for f in review_findings(rv) if not status or f.status == status];
    head = f"Review {rv.id}: verdict {rv.verdict}, risk {rv.risk}, {rv.llm_calls} model calls, ${rv.cost}. {rv.summary[:400]}";
    return head
        + "\n"
        + "\n".join([
            f"{f.id} [{f.severity}/{f.category}/{f.status}] {f.path}:{f.line} {f.title}"
            for f in fs
        ]);
}

impl review_pull_request(pr_id: str, focus: str) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}.";
    }
    if pr_running(pr.id) {
        return f"A review of {pr.id} is already running; watch it on the overview tab.";
    }
    ui("navigate", UiArgs(to="/reviews/" + pr.id, tab="overview"));
    run_review(_repo(), pr, focus, "copilot");
    return list_findings(pr.id, "");
}

impl post_comment(
    pr_id: str,
    path: str,
    line: int,
    severity: str,
    category: str,
    title: str,
    body: str,
    suggestion: str,
) -> str {
    pr = _pr(pr_id);
    if pr is None {
        return f"No pull request {pr_id}.";
    }
    made = add_finding(
        _repo(), pr, path, line, severity, category, title, body, suggestion, "copilot"
    );
    if made is None {
        return f"{path} is not part of {pr_id}; comments anchor to changed files.";
    }
    ui("navigate", UiArgs(to="/reviews/" + pr.id, tab="files", file=made.path, line=made.line));
    return f"Posted {made.id} on {made.path}:{made.line}.";
}

impl update_finding(finding_id: str, status: str, note: str) -> str {
    if status not in ("open", "resolved", "dismissed") {
        return "status must be open, resolved, or dismissed.";
    }
    f = set_status(finding_id, status, note, "Copilot");
    return f"{finding_id} is now {status}." if f else f"No finding {finding_id}.";
}

impl reply_to_finding(finding_id: str, text: str) -> str {
    f = add_reply(finding_id, text, "Copilot");
    return "Replied." if f else f"No finding {finding_id}.";
}

impl _card(kind: str, title: str, caption: str, spec: dict[str, any], pin: bool) -> str {
    payload = json.dumps(spec);
    card = Card(
        id=new_id("I"),
        title=title,
        kind=kind,
        caption=caption,
        spec=payload,
        pinned=pin,
        created=now(),
    );
    if pin {
        card.id = pin_insight(_repo(), title, kind, caption, payload).id;
    }
    sink = _sink.get();
    if sink is not None {
        sink.append(card);
    }
    return f"Rendered {kind} '{title}' as card {card.id}"
        + (" and pinned it to the board." if pin else ".");
}

impl render_chart(
    title: str, kind: str, labels: list[str], series: list[Series], caption: str, pin: bool
) -> str {
    k = kind if kind in ("bar", "hbar", "line", "area", "donut", "stacked") else "bar";
    spec: dict[str, any] = {
        "labels": labels[:60],
        "series": [{"name": s.name, "values": s.values[:60]} for s in series[:6]],
    };
    return _card(k, title, caption, spec, pin);
}

impl render_table(
    title: str, columns: list[str], rows: list[list[str]], caption: str, pin: bool
) -> str {
    return _card(
        "table", title, caption, {"columns": columns[:8], "rows": [r[:8] for r in rows[:40]]}, pin
    );
}

impl render_diagram(title: str, mermaid: str, caption: str, pin: bool) -> str {
    return _card("mermaid", title, caption, {"code": mermaid}, pin);
}

impl export_review(pr_id: str) -> str {
    rv = _latest_review(pr_id);
    if rv is None {
        return f"{pr_id} has no completed review to export.";
    }
    ui("export", UiArgs(pr_id=pr_id, markdown=review_markdown(rv, review_findings(rv))));
    return "Opened the export panel with the review as Markdown.";
}

impl publish_to_github(pr_id: str) -> str {
    pr = _pr(pr_id);
    if pr is None or pr.kind != "github" {
        return "Only GitHub pull requests can be published; this one is local.";
    }
    ui("confirm_publish", UiArgs(pr_id=pr.id, number=pr.number, url=pr.url));
    return "Asked the user to confirm publishing in the UI. Nothing is posted until they click Publish.";
}
