"""Every endpoint diffwalker serves.

All of them are `def:protect`: a signed-in caller runs on their own root, so reviews,
findings, chat threads, and the active repository are per user with no user-id
checks in the code. `server_info` is the only `def:pub` one; the sign-in screen
uses it before anyone is signed in. What they return is declared in `core.wire`,
which the front ends compile in too.
"""
import os;
import json;
import time;
import logging;
import threading;
import subprocess;
import from stdjac { ByEnd, ByEvent, ByEventKind, ByUsage, commit, latest_turns }

glob _env_loaded: int = load_env(),
     _warmed: set[str] = set(),
     _warm_lock: threading.Lock = threading.Lock(),
     SNIPPET_FILES: list[str] = ["jac.toml", "README.md", "archwire.jac"];

def _default_repo -> str {
    env = os.environ.get("DIFFWALKER_REPO", "");
    if env and resolve_repo(env) {
        return resolve_repo(env);
    }
    return resolve_repo(PROJECT_DIR) or PROJECT_DIR;
}

"""The caller's active repository: their Workspace node is the only source of truth."""
def active_repo -> str {
    ws = workspace();
    repo = ws.active_repo if ws.active_repo and resolve_repo(ws.active_repo) else _default_repo();
    with _warm_lock {
        fresh = repo not in _warmed;
        _warmed.add(repo);
    }
    if fresh {
        threading.Thread(target=warm, args=(repo,), daemon=True).start();
    }
    return repo;
}

def _rows(repo: str) -> list[PRRow] {
    r = repo_node(repo);
    out: list[PRRow] = [];
    for p in discover_prs(repo) {
        row = PRRow(pr=p, reviewing=pr_running(p.id));
        n = pr_node(r, p.id) if r else None;
        if n {
            row.verdict = n.verdict;
            row.risk = n.risk;
            row.open_findings = n.open_findings;
            row.last_review = n.last_review;
        }
        out.append(row);
    }
    return out;
}

def _brief(rv: Review) -> ReviewBrief {
    return ReviewBrief(
        id=rv.id,
        status=rv.status,
        verdict=rv.verdict,
        risk=rv.risk,
        started=rv.started,
        finished=rv.finished,
        findings=len(review_findings(rv)),
        cost=rv.cost,
        trigger=rv.trigger,
    );
}

def _view(rv: Review) -> ReviewView {
    notes: list[FileNote] = [];
    for fc in review_files(rv) {
        refs = [fc --> [?:CodeRef]];
        notes.append(
            FileNote(
                path=fc.path,
                summary=fc.summary,
                risk=fc.risk,
                lenses=fc.lenses,
                status=fc.state,
                findings=fc.findings,
                additions=fc.additions,
                deletions=fc.deletions,
                related=[c.path for c in refs],
                read=[c.path for c in refs if c.inspected],
            ),
        );
    }
    return ReviewView(
        id=rv.id,
        pr_id=rv.pr_id,
        status=rv.status,
        verdict=rv.verdict,
        risk=rv.risk,
        triage_risk=rv.triage_risk,
        summary=rv.summary,
        intent=rv.intent,
        focus=rv.focus,
        highlights=rv.highlights,
        concerns=rv.concerns,
        tests=rv.tests,
        walkthrough=notes,
        stages=rv.stages,
        feed=rv.feed,
        costs=rv.costs,
        started=rv.started,
        finished=rv.finished,
        model=rv.model,
        ref=rv.ref,
        llm_calls=rv.llm_calls,
        tokens=rv.tokens,
        cost=rv.cost,
        dropped=rv.dropped,
        error=rv.error,
        trigger=rv.trigger,
    );
}

"""Mark reviews that were running when the server stopped; nothing is still working on them."""
def _settle(reviews: list[Review]) {
    stale = False;
    for rv in reviews {
        if rv.status == "running" and not is_active(rv.id) and now() - rv.started > 20 {
            rv.status = "failed";
            rv.error = "Interrupted: the server restarted mid-review";
            rv.finished = now();
            stale = True;
        }
    }
    if stale {
        commit();
    }
}

def:pub server_info -> ServerInfo {
    return ServerInfo(llm=llm_ready(), model=model_label(), gh=gh_available());
}

def:protect get_workspace -> WorkspaceView {
    repo = active_repo();
    ws = workspace();
    return WorkspaceView(
        repo=repo_info(repo),
        recent=ws.recent or [repo],
        llm=llm_ready(),
        model=model_label(),
        gh=gh_available(),
        seq=latest_seq(),
    );
}

def:protect set_repository(path: str) -> WorkspaceView {
    picked = choose_repo(path);
    view = get_workspace();
    if not picked {
        view.error = f"{path} is not a git repository";
    }
    return view;
}

def:protect list_reviews(refresh: bool) -> list[PRRow] {
    repo = active_repo();
    if refresh {
        forget("prs:" + repo);
        forget("info:" + repo);
    }
    return _rows(repo);
}

def:protect dashboard -> DashboardView {
    repo = active_repo();
    r = repo_node(repo);
    recent: list[Finding] = [];
    pins = 0;
    spend = 0.0;
    count = 0;
    if r {
        recent = repo_findings(r);
        pins = len(repo_insights(r));
        for rv in [r ->:HasPR:-> ->:HasReview:->][?:Review] {
            spend += rv.cost;
            count += 1;
        }
    }
    recent = sorted(recent, key=lambda (f: Finding) -> float { return 0 - f.created; })[:8];
    return DashboardView(
        repo=repo_info(repo),
        stats=stats(repo),
        activity=activity(repo, 182),
        languages=languages(repo)[:8],
        hotspots=hotspots(repo, 8),
        prs=_rows(repo)[:8],
        findings=recent,
        insights=pins,
        spend=round(spend, 4),
        reviews=count,
    );
}

"""A pull request with its diff, triage, and one review: `review_id`, or the latest one."""
def:protect pr_detail(pr_id: str, review_id: str) -> PRDetail {
    repo = active_repo();
    pr = find_pr(repo, pr_id);
    if pr is None {
        return PRDetail(found=False);
    }
    files = parse_unified_diff(pr_diff_text(repo, pr))[:160];
    out = PRDetail(
        pr=pr,
        files=files,
        risks=triage(files, [h.path for h in hotspots(repo, 60)]),
        commits=pr_commits(repo, pr),
        found=True,
    );
    r = repo_node(repo);
    n = pr_node(r, pr.id) if r else None;
    if n is None {
        return out;
    }
    reviews = pr_reviews(n);
    _settle(reviews);
    out.history = [_brief(rv) for rv in reviews];
    chosen: Review | None = None;
    if review_id {
        picked = [rv for rv in reviews if rv.id == review_id];
        chosen = picked[0] if picked else None;
    }
    if chosen is None {
        live_ones = [rv for rv in reviews if rv.status in ("done", "running")];
        chosen = live_ones[0] if live_ones else None;
    }
    if chosen {
        out.review = _view(chosen);
        shown = chosen if chosen.status == "done" or review_id else review_of(n, "done");
        out.findings = review_findings(shown) if shown else [];
    }
    return out;
}

"""Run the full pipeline on a pull request. Returns when it finishes; screens follow it live."""
def:protect start_review(pr_id: str, focus: str, session: str) -> ReviewBrief {
    set_session(session);
    repo = active_repo();
    pr = find_pr(repo, pr_id);
    if pr is None {
        return ReviewBrief(status="missing");
    }
    if pr_running(pr.id) {
        return ReviewBrief(status="busy");
    }
    changed("reviewing", pr_id=pr.id);
    rid = run_review(
        repo,
        pr,
        focus,
        "mobile" if session.startswith("m-") else ("cli" if session.startswith("cli") else "user"),
    );
    rv = find_review(rid);
    return _brief(rv) if rv else ReviewBrief(id=rid, status="failed");
}

def:protect set_finding_status(finding_id: str, status: str, note: str) -> Finding | None {
    return set_status(finding_id, status, note, "You");
}

def:protect reply_finding(finding_id: str, text: str) -> Finding | None {
    return add_reply(finding_id, text, "You");
}

def:protect add_comment(
    pr_id: str,
    path: str,
    line: int,
    severity: str,
    category: str,
    title: str,
    body: str,
    suggestion: str,
) -> Finding | None {
    repo = active_repo();
    pr = find_pr(repo, pr_id);
    if pr is None {
        return None;
    }
    return add_finding(repo, pr, path, line, severity, category, title, body, suggestion, "you");
}

def:protect export_markdown(pr_id: str) -> str {
    r = repo_node(active_repo());
    n = pr_node(r, pr_id) if r else None;
    rv = review_of(n, "done") if n else None;
    return review_markdown(rv, review_findings(rv)) if rv else "";
}

def _post_to_github(slug: str, number: int, body: str, pr_id: str, user: str) {
    try {
        p = subprocess.run(
            ["gh", "pr", "comment", str(number), "--repo", slug, "--body-file", "-"],
            input=body,
            capture_output=True,
            text=True,
            timeout=60,
        );
        if p.returncode == 0 {
            emit("data", LiveData(what="published", pr_id=pr_id, url=p.stdout.strip()), user=user);
            _toast("Published to GitHub: " + p.stdout.strip(), "success", user);
        } else {
            _toast("gh failed: " + p.stderr.strip()[:200], "warning", user);
        }
    } except Exception as e {
        _toast("gh failed: " + str(e)[:200], "warning", user);
    }
}

def _toast(message: str, tone: str, user: str) {
    emit("ui", LiveData(action="toast", args=UiArgs(message=message, tone=tone)), user=user);
}

"""Post the latest review to the GitHub PR. The gh call runs after this returns, and a
toast tells the user how it went."""
def:protect publish_review(pr_id: str) -> str {
    repo = active_repo();
    pr = find_pr(repo, pr_id);
    if pr is None or pr.kind != "github" or not gh_available() {
        return "Only GitHub pull requests can be published, and the gh CLI must be installed.";
    }
    body = export_markdown(pr_id);
    if not body {
        return "Run a review first.";
    }
    slug = repo_info(repo).github;
    threading.Thread(
        target=_post_to_github, args=(slug, pr.number, body, pr_id, current_user()), daemon=True
    ).start();
    return "Publishing to "
        + slug
        + "#"
        + str(pr.number)
        + "; a toast confirms when GitHub accepts it.";
}

def:protect activity_view -> ActivityView {
    repo = active_repo();
    return ActivityView(
        days=activity(repo, 371),
        weeks=weekly(repo, 26),
        kinds=kinds_by_month(repo, 9),
        stats=stats(repo),
    );
}

def:protect hotspots_view(limit: int) -> list[Hotspot] {
    return hotspots(active_repo(), max(5, min(limit or 40, 80)));
}

def:protect people_view -> PeopleView {
    repo = active_repo();
    return PeopleView(contributors=contributors(repo, 16), ownership=ownership(repo, 14));
}

def:protect structure_view -> StructureView {
    repo = active_repo();
    return StructureView(cells=structure(repo, 3, 56), languages=languages(repo)[:10]);
}

def:protect coupling_view -> CouplingGraph {
    return coupling(active_repo());
}

def:protect board -> list[Insight] {
    r = repo_node(active_repo());
    return repo_insights(r) if r else [];
}

def:protect pin_card(title: str, kind: str, caption: str, spec: str) -> Insight {
    return pin_insight(active_repo(), title, kind, caption, spec);
}

def:protect unpin_card(insight_id: str) -> bool {
    return unpin_insight(active_repo(), insight_id);
}

def:protect chat_history(thread_id: str) -> list[ChatMsg] {
    t = chat_thread(thread_id);
    commit();
    return t.transcript;
}

def:protect clear_chat(thread_id: str) -> bool {
    t = chat_thread(thread_id);
    t.transcript = [];
    t.history = [];
    commit();
    return True;
}

def:protect stop_turn(thread_id: str) -> bool {
    request_stop(thread_id);
    return True;
}

"""What the pane says of a turn that did not simply end with its answer."""
glob ENDED: dict[ByEnd, str] = {
    ByEnd.STOPPED: "Stopped: wrapping up with what I have.",
    ByEnd.ROUNDS: "Out of steps for this turn: wrapping up with what I have.",
    ByEnd.CUT: "The answer was cut at its length limit.",
};

"""One event of the Copilot's stream as a frame for the Copilot pane, noted in `reply`.
`spent` is what the turn's requests have used so far."""
def _frame(ev: ByEvent, reply: ChatReply, spent: ByUsage) -> CopilotFrame | None {
    if ev.kind == ByEventKind.TEXT {
        reply.text = reply.text + ev.text;
        return CopilotFrame(t="chunk", text=ev.text);
    }
    if ev.kind == ByEventKind.TOOL_CALL {
        args = json.dumps(ev.args);
        reply.tools = reply.tools + [ToolTrace(tool=ev.tool, args=args[:400])];
        return CopilotFrame(t="tool_call", tool=ev.tool, args=args, id=ev.call_id);
    }
    if ev.kind == ByEventKind.TOOL_RESULT {
        for tr in reversed(reply.tools) {
            if tr.tool == ev.tool and not tr.result {
                tr.result = ev.result[:400];
                break;
            }
        }
        return CopilotFrame(t="tool_result", tool=ev.tool, result=ev.result[:600], id=ev.call_id);
    }
    usage = ev.usage;
    if ev.kind == ByEventKind.USAGE and usage is not None {
        spent.add(usage);
        reply.tokens = tokens_of(spent);
        reply.cost = spent.cost or 0.0;
        return CopilotFrame(
            t="usage", tokens=reply.tokens, cost=reply.cost, requests=spent.requests
        );
    }
    if ev.kind == ByEventKind.DONE and ev.ended in ENDED {
        return CopilotFrame(t="thought", text=ENDED[ev.ended]);
    }
    return None;
}

"""One Copilot turn as the frames it makes, kept in the caller's chat thread when it ends,
and when its reader leaves before it does (the stream is closed where it paused).
A stream runs on one thread from start to end, so the session and the agent's context
set here hold for every tool the turn calls."""
def _turn(
    thread_id: str, message: str, ui_state: str, session: str, reply: ChatReply
) -> Iterator[CopilotFrame] {
    set_session(session);
    repo = active_repo();
    t = chat_thread(thread_id);
    t.transcript = t.transcript + [ChatMsg(role="user", text=message, ts=now())];
    if not t.title {
        t.title = message[:60];
    }
    t.updated = now();
    commit();
    history = latest_turns(t.history, HISTORY_CHARS);
    cards: list[Card] = [];
    set_agent(AgentCtx(repo=repo, session=session, thread=thread_id, user=current_user()), cards);
    clear_stop(thread_id);
    try {
        if not llm_ready() {
            reply.text = "Copilot needs credentials for "
                + model_name()
                + " in the server environment (or the project's `.env`).";
            yield CopilotFrame(t="chunk", text=reply.text);
        } else {
            sent = 0;
            spent = ByUsage();
            try {
                for ev in copilot(message, ui_state, history) {
                    frame = _frame(ev, reply, spent);
                    if frame is not None {
                        yield frame;
                    }
                    while sent < len(cards) {
                        yield CopilotFrame(t="card", card=cards[sent]);
                        sent += 1;
                    }
                }
            } except Exception as e {
                logging.getLogger("diffwalker.copilot").exception("copilot turn failed");
                failure = "\n\n_Copilot hit an error: " + str(e)[:300] + "_";
                reply.text = reply.text + failure;
                yield CopilotFrame(t="chunk", text=failure);
            }
        }
    } finally {
        # Kept however the turn ends: its pane may have closed in the middle of the answer.
        reply.cards = cards;
        t.transcript = t.transcript + [
            ChatMsg(
                role="assistant",
                text=reply.text,
                ts=now(),
                tools=reply.tools,
                cards=cards,
                tokens=reply.tokens,
                cost=reply.cost,
            ),
        ];
        t.history = history;
        t.updated = now();
        commit();
        clear_stop(thread_id);
    }
    yield CopilotFrame(t="done");
}

"""A Copilot turn, each frame sent as it is made."""
def:protect copilot_stream(
    thread_id: str, message: str, ui_state: str, session: str
) -> Iterator[CopilotFrame] {
    return _turn(thread_id, message, ui_state, session, ChatReply());
}

"""The same turn without streaming, for clients that take one reply (the phone)."""
def:protect copilot_ask(thread_id: str, message: str, ui_state: str, session: str) -> ChatReply {
    reply = ChatReply();
    user = current_user();
    start = latest_seq();
    for _ in _turn(thread_id, message, ui_state, session, reply) {}
    for e in events_after(user, start) {
        if e.session == session and e.kind == "ui" {
            reply.actions = reply.actions + [UiCommand(action=e.data.action, args=e.data.args)];
        }
    }
    return reply;
}

"""The caller's event stream: review progress, data changes, and UI commands from their other screens."""
def:protect live(after: int) -> Iterator[LiveEvent] {
    user = current_user();
    cursor = after if after > 0 else latest_seq();
    yield LiveEvent(kind="hello", seq=cursor);
    deadline = time.time() + 600;
    while time.time() < deadline {
        batch = wait_events(user, cursor, 8.0);
        if not batch {
            yield LiveEvent(kind="ping", seq=cursor);
            continue;
        }
        for e in batch {
            cursor = e.seq;
            yield e;
        }
    }
}

"""Source shown on the "How it's built" page: Jac files of this project and a few named
files, never dotfiles, never through a symlink."""
def:protect source_snippet(path: str, needle: str, before: int, after: int) -> CodeSnippet {
    rel = os.path.normpath(path).lstrip("/");
    parts = rel.split(os.sep);
    allowed = rel.endswith(".jac") or rel in SNIPPET_FILES;
    if not allowed or any([p.startswith(".") or p == ".." for p in parts]) {
        return CodeSnippet(path=path);
    }
    full = os.path.join(PROJECT_DIR, rel);
    if os.path.realpath(full) != os.path.abspath(full) or not os.path.isfile(full) {
        return CodeSnippet(path=path);
    }
    with open(full, "r", errors="replace") as fh {
        lines = fh.read().split("\n");
    }
    at = 0;
    if needle {
        for (i, l) in enumerate(lines) {
            if needle in l {
                at = i;
                break;
            }
        }
    }
    a = max(0, at - max(0, before));
    b = min(len(lines), at + max(1, after) + 1);
    return CodeSnippet(path=path, start=a + 1, lines=lines[a:b], total=len(lines));
}

def:protect build_stats -> BuildStats {
    out = BuildStats(tools=len(TOOLS));
    sizes: dict[str, AppSize] = {};
    for (dirpath, dirnames, filenames) in os.walk(PROJECT_DIR) {
        dirnames[:] = [
            d
            for d in dirnames
            if not d.startswith(".") and d not in ("node_modules", "dist", "_probe")
        ];
        for name in filenames {
            if not name.endswith(".jac") {
                continue;
            }
            full = os.path.join(dirpath, name);
            rel = os.path.relpath(full, PROJECT_DIR);
            top = rel.split(os.sep)[0] if os.sep in rel else "(root)";
            if top == "core" and rel.startswith(os.path.join("core", "site", "ui")) {
                top = "core/ui (shadcn)";
            }
            with open(full, "r", errors="replace") as fh {
                text = fh.read();
            }
            n = text.count("\n") + 1;
            app = sizes.get(top);
            if app is None {
                app = AppSize(app=top);
                sizes[top] = app;
            }
            app.files += 1;
            app.lines += n;
            out.jac_files += 1;
            out.jac_lines += n;
            if rel.startswith(os.path.join("core", "api")) {
                out.endpoints += text.count("def:protect ") + text.count("def:pub ");
            }
            out.llm_functions += text.count(" by llm(") + text.count("by llm(\n");
            for l in text.split("\n") {
                s = l.strip();
                if s.startswith("node ") {
                    out.nodes += 1;
                } elif (s.startswith("walker ") or s.startswith("walker:")) and s.endswith("{") {
                    out.walkers += 1;
                }
            }
        }
    }
    out.apps = sorted(sizes.values(), key=lambda (a: AppSize) -> int { return 0 - a.lines; });
    return out;
}
