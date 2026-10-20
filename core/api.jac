import os;
import json;
import time;
import logging;
import threading;
import subprocess;
import from typing { Generator }
import from jaclang.byllm.lib { StreamEvent }

"""Every endpoint diffwalker serves.

All of them are `def:protect`: a signed-in caller runs on their own root, so reviews,
findings, chat threads, and the active repository are per user with no user-id
checks in the code. `server_info` is the only `def:pub` one; the sign-in screen
uses it before anyone is signed in.
"""
obj ServerInfo {
    has llm: bool = False,
        model: str = "",
        gh: bool = False;
}

obj WorkspaceView {
    has repo: RepoInfo = RepoInfo(),
        recent: list[str] = [],
        llm: bool = False,
        model: str = "",
        gh: bool = False,
        seq: int = 0,
        error: str = "";
}

obj PRRow {
    has pr: PullRequestRef = PullRequestRef(),
        verdict: str = "",
        risk: int = -1,
        open_findings: int = 0,
        last_review: str = "",
        reviewing: bool = False;
}

obj ReviewBrief {
    has id: str = "",
        status: str = "",
        verdict: str = "",
        risk: int = 0,
        started: float = 0.0,
        finished: float = 0.0,
        findings: int = 0,
        cost: float = 0.0,
        trigger: str = "";
}

obj FileNote {
    has path: str = "",
        summary: str = "",
        risk: int = 0,
        lenses: list[str] = [],
        status: str = "queued",
        findings: int = 0,
        additions: int = 0,
        deletions: int = 0,
        related: list[str] = [],
        read: list[str] = [];
}

obj ReviewView {
    has id: str = "",
        pr_id: str = "",
        status: str = "",
        verdict: str = "",
        risk: int = 0,
        triage_risk: int = 0,
        summary: str = "",
        intent: str = "",
        focus: str = "",
        highlights: list[str] = [],
        concerns: list[str] = [],
        tests: list[str] = [],
        walkthrough: list[FileNote] = [],
        stages: list[StageState] = [],
        feed: list[FeedItem] = [],
        costs: list[StageCost] = [],
        started: float = 0.0,
        finished: float = 0.0,
        model: str = "",
        ref: str = "",
        llm_calls: int = 0,
        tokens: int = 0,
        cost: float = 0.0,
        dropped: int = 0,
        error: str = "",
        trigger: str = "";
}

obj PRDetail {
    has pr: PullRequestRef = PullRequestRef(),
        files: list[FileDiff] = [],
        risks: list[FileRisk] = [],
        commits: list[CommitInfo] = [],
        review: ReviewView | None = None,
        findings: list[Finding] = [],
        history: list[ReviewBrief] = [],
        found: bool = False;
}

obj DashboardView {
    has repo: RepoInfo = RepoInfo(),
        stats: RepoStats = RepoStats(),
        activity: list[DayCount] = [],
        languages: list[LangSlice] = [],
        hotspots: list[Hotspot] = [],
        prs: list[PRRow] = [],
        findings: list[Finding] = [],
        insights: int = 0,
        spend: float = 0.0,
        reviews: int = 0;
}

obj ActivityView {
    has days: list[DayCount] = [],
        weeks: list[WeekBucket] = [],
        kinds: list[KindMonth] = [],
        stats: RepoStats = RepoStats();
}

obj PeopleView {
    has contributors: list[Contributor] = [],
        ownership: list[Ownership] = [];
}

obj StructureView {
    has cells: list[TreeCell] = [],
        languages: list[LangSlice] = [];
}

obj ChatReply {
    has text: str = "",
        tools: list[ToolTrace] = [],
        cards: list[dict[str, any]] = [],
        actions: list[dict[str, any]] = [],
        tokens: int = 0,
        cost: float = 0.0;
}

obj CodeSnippet {
    has path: str = "",
        start: int = 0,
        lines: list[str] = [],
        total: int = 0;
}

glob _env_loaded: int = load_env(),
     _warmed: set[str] = set(),
     _warm_lock: any = threading.Lock(),
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
        threading.Thread(target=lambda { warm(repo); }, daemon=True).start();
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
        trigger=rv.trigger
    );
}

def _view(rv: Review) -> ReviewView {
    notes: list[FileNote] = [];
    for fc in review_files(rv) {
        refs = [fc-->][?:CodeRef];
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
                read=[c.path for c in refs if c.inspected]
            )
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
        trigger=rv.trigger
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
        seq=latest_seq()
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
        for rv in [r->:HasPR:->->:HasReview:->][?:Review] {
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
        reviews=count
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
        found=True
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
    changed("reviewing", {"pr_id": pr.id});
    rid = run_review(repo, pr, focus, "mobile" if session.startswith("m-") else ("cli" if session.startswith("cli") else "user"));
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
    suggestion: str
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
        p = subprocess.run(["gh", "pr", "comment", str(number), "--repo", slug, "--body-file", "-"], input=body, capture_output=True, text=True, timeout=60);
        if p.returncode == 0 {
            emit("data", {"what": "published", "pr_id": pr_id, "url": p.stdout.strip()}, user=user);
            emit("ui", {"action": "toast", "args": {"message": "Published to GitHub: " + p.stdout.strip(), "tone": "success"}}, user=user);
        } else {
            emit("ui", {"action": "toast", "args": {"message": "gh failed: " + p.stderr.strip()[:200], "tone": "warning"}}, user=user);
        }
    } except Exception as e {
        emit("ui", {"action": "toast", "args": {"message": "gh failed: " + str(e)[:200], "tone": "warning"}}, user=user);
    }
}

"""Post the latest review to the GitHub PR, once: the gh call is deferred to `on_commit`, so a replayed request never posts twice."""
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
    number = pr.number;
    user = current_user();
    on_commit(lambda { threading.Thread(target=lambda { _post_to_github(slug, number, body, pr_id, user); }, daemon=True).start(); });
    return "Publishing to " + slug + "#" + str(number) + "; a toast confirms when GitHub accepts it.";
}

def:protect activity_view -> ActivityView {
    repo = active_repo();
    return ActivityView(days=activity(repo, 371), weeks=weekly(repo, 26), kinds=kinds_by_month(repo, 9), stats=stats(repo));
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

def:protect chat_history(thread_id: str) -> ChatThread {
    t = chat_thread(thread_id);
    commit();
    return t;
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

def _plain(o: object) -> object {
    dump = getattr(o, "model_dump", None);
    if dump is not None {
        return dump();
    }
    return o?.__dict__ or str(o);
}

"""byLLM's conversation list can hold provider objects (litellm tool-call records);
persist only JSON, or the stored node cannot be read back (jaseci-labs/jac#10234)."""
def _json_only(history: list[dict[str, any]]) -> list[dict[str, any]] {
    return json.loads(json.dumps(history, `default=_plain));
}

"""Translate one byLLM StreamEvent into a frame for the Copilot pane."""
def _frame(ev: StreamEvent, reply: ChatReply) -> dict[str, any] | None {
    k = ev.event_type;
    d = ev.data;
    if k == "chunk" {
        piece = str(d.get("content", ""));
        reply.text = reply.text + piece;
        return {"t": "chunk", "text": piece};
    }
    if k == "thought" {
        return {"t": "thought", "text": str(d.get("content", ""))};
    }
    if k == "tool_call" {
        args = json.loads(json.dumps(d.get("args", {}), `default=_plain));
        reply.tools = reply.tools + [ToolTrace(tool=str(d.get("tool", "")), args=json.dumps(args)[:400])];
        return {"t": "tool_call", "tool": d.get("tool", ""), "args": args, "id": d.get("call_id", "")};
    }
    if k == "tool_result" {
        res = str(d.get("result", ""));
        for tr in reversed(reply.tools) {
            if tr.tool == d.get("tool", "") and not tr.result {
                tr.result = res[:400];
                break;
            }
        }
        return {"t": "tool_result", "tool": d.get("tool", ""), "result": res[:600], "id": d.get("call_id", "")};
    }
    if k == "compaction" {
        return {"t": "thought", "text": f"Compacted older context ({d.get('tokens_before', 0)} → {d.get('tokens_after', 0)} tokens)"};
    }
    if k == "steps_done" and d.get("reason") in ("aborted", "aborted_with_summary") {
        return {"t": "thought", "text": "Stopped: wrapping up with what I have."};
    }
    if k == "usage" {
        total = d.get("total", {}) or {};
        reply.tokens = int(total.get("total_tokens", 0) or 0);
        reply.cost = float(total.get("cost", 0.0) or 0.0);
        return {"t": "usage", "tokens": reply.tokens, "cost": reply.cost, "requests": d.get("requests", 0)};
    }
    return None;
}

"""One Copilot turn as a generator of frames. Context is re-bound at every step,
because each step of a streamed generator runs in a fresh copy of the request context."""
def _turn(thread_id: str, message: str, ui_state: str, session: str, reply: ChatReply) -> Generator[dict[str, any], None, None] {
    repo = active_repo();
    user = current_user();
    t = chat_thread(thread_id);
    t.transcript = t.transcript + [ChatMsg(role="user", text=message, ts=now())];
    if not t.title {
        t.title = message[:60];
    }
    t.updated = now();
    commit();
    history: list[dict[str, any]] = list(t.history or []);
    cards: list[dict[str, any]] = [];
    ctx = AgentCtx(repo=repo, session=session, thread=thread_id, user=user);
    clear_stop(thread_id);
    if not llm_ready() {
        msg = "Copilot needs credentials for " + model_name() + " in the server environment (or the project's `.env`).";
        reply.text = msg;
        yield {"t": "chunk", "text": msg};
    } else {
        sent = 0;
        try {
            set_agent(ctx, cards);
            set_session(session);
            stream: any = iter(copilot(message, ui_state, history));
            while True {
                set_agent(ctx, cards);
                set_session(session);
                try {
                    ev = next(stream);
                } except StopIteration {
                    break;
                }
                if isinstance(ev, StreamEvent) {
                    frame = _frame(ev, reply);
                    if frame {
                        yield frame;
                    }
                }
                while sent < len(cards) {
                    yield {"t": "card", "card": cards[sent]};
                    sent += 1;
                }
            }
        } except Exception as e {
            logging.getLogger("diffwalker.copilot").exception("copilot turn failed");
            msg = "\n\n_Copilot hit an error: " + str(e)[:300] + "_";
            reply.text = reply.text + msg;
            yield {"t": "chunk", "text": msg};
        }
    }
    reply.cards = cards;
    t = chat_thread(thread_id);
    t.transcript = t.transcript + [ChatMsg(role="assistant", text=reply.text, ts=now(), tools=reply.tools, cards=[json.dumps(c) for c in cards], tokens=reply.tokens, cost=reply.cost)];
    t.history = _json_only(history);
    t.updated = now();
    commit();
    clear_stop(thread_id);
    yield {"t": "done"};
}

def:protect copilot_stream(thread_id: str, message: str, ui_state: str, session: str) {
    reply = ChatReply();
    report _turn(thread_id, message, ui_state, session, reply);
}

"""The same turn without streaming, for clients that cannot read SSE (the phone)."""
def:protect copilot_ask(thread_id: str, message: str, ui_state: str, session: str) -> ChatReply {
    reply = ChatReply();
    user = current_user();
    start = latest_seq();
    for _ in _turn(thread_id, message, ui_state, session, reply) {
        set_session(session);
    }
    for e in events_after(user, start) {
        if e["session"] == session and e["kind"] == "ui" and e["data"]["action"] != "card" {
            reply.actions = reply.actions + [e["data"]];
        }
    }
    return reply;
}

"""The caller's event stream: review progress, data changes, and UI commands from their other screens."""
def:protect live(after: int) {
    user = current_user();
    def stream -> Generator[dict[str, any], None, None] {
        cursor = after if after > 0 else latest_seq();
        yield {"kind": "hello", "seq": cursor};
        deadline = time.time() + 600;
        while time.time() < deadline {
            batch = wait_events(user, cursor, 8.0);
            if not batch {
                yield {"kind": "ping", "seq": cursor};
                continue;
            }
            for e in batch {
                cursor = e["seq"];
                yield e;
            }
        }
    }
    report stream();
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

obj AppSize {
    has app: str = "",
        files: int = 0,
        lines: int = 0;
}

obj BuildStats {
    has apps: list[AppSize] = [],
        jac_files: int = 0,
        jac_lines: int = 0,
        endpoints: int = 0,
        tools: int = 0,
        llm_functions: int = 0,
        nodes: int = 0,
        walkers: int = 0;
}

def:protect build_stats -> BuildStats {
    out = BuildStats(tools=len(TOOLS));
    sizes: dict[str, AppSize] = {};
    for (dirpath, dirnames, filenames) in os.walk(PROJECT_DIR) {
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in ("node_modules", "dist", "_probe")];
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
                } elif s.startswith("walker ") {
                    out.walkers += 1;
                }
            }
        }
    }
    out.apps = sorted(sizes.values(), key=lambda (a: AppSize) -> int { return 0 - a.lines; });
    return out;
}
