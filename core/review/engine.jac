import os;
import time;
import tomllib;
import from concurrent.futures { as_completed }
import from jaclang.runtime.exceptions { WriteConflict }

"""The review pipeline, written as walkers over the review's own graph.

    Review --Covers--> FileChange --CalledFrom/TestedBy/ChangesWith--> CodeRef
                                  --Raised--> Finding

`ReviewRun` is spawned on a fresh Review node. Its Review entry ingests, triages, and
plans; its FileChange entry launches each file's specialist reviewer into a `flow`
worker (or into a batch of small files); its Review exit, which fires once every file
has been visited, gathers the results, anchors and dedupes them in code, runs the
cross-file pass, spawns an `Investigate` walker per flagged file (the model routes it
over the CodeRef neighbourhood with `visit ... by llm()`), verifies per file in
parallel, enforces the verdict rule, and synthesizes. Model calls happen in workers
and never touch the graph; every graph write happens in the walker and is committed
stage by stage so other screens can follow along.
"""
glob STAGES: list[list[str]] = [
         ["ingest", "Ingest diff"],
         ["triage", "Risk triage"],
         ["plan", "Plan review"],
         ["review", "Specialist lenses"],
         ["cross", "Cross-file analysis"],
         ["investigate", "Investigate context"],
         ["verify", "Adversarial verify"],
         ["synthesize", "Synthesize verdict"]
     ],
     MAX_SOLO: int = 8,
     BATCH_FILES: int = 6,
     BATCH_CHARS: int = 9000,
     MAX_FILES: int = 80,
     VERIFY_BATCH: int = 8,
     ANCHOR_SLACK: int = 8,
     REVIEW_DEADLINE: float = float(os.environ.get("DIFFWALKER_REVIEW_DEADLINE", "900") or 900),
     SKIP_KINDS: list[str] = ["generated"],
     ACTIVE: dict[str, str] = {},
     _model: list[str] = [""];

"""The model jac.toml configures for `by llm()`; the one place it is named."""
def model_name -> str {
    if not _model[0] {
        name = os.environ.get("BYLLM_DEFAULT_MODEL", "");
        if not name {
            try {
                with open(os.path.join(PROJECT_DIR, "jac.toml"), "rb") as fh {
                    cfg = tomllib.load(fh);
                }
                name = str(((cfg.get("byllm") or {}).get("model") or {}).get("default_model", ""));
            } except Exception {
                name = "";
            }
        }
        _model[0] = name or "gpt-4o-mini";
    }
    return _model[0];
}

def model_label -> str {
    return model_name().split("/")[-1];
}

"""Whether the configured provider has credentials, checked per provider."""
def llm_ready -> bool {
    m = model_name().lower();
    if m.startswith(("ollama/", "local:", "hosted_vllm/")) {
        return True;
    }
    if m.startswith("anthropic/") or m.startswith("claude") {
        return bool(os.environ.get("ANTHROPIC_API_KEY"));
    }
    if m.startswith(("gemini/", "google/")) {
        return bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"));
    }
    if m.startswith("systemone:") {
        return bool(os.environ.get("TYPESAFE_API_KEY"));
    }
    return bool(os.environ.get("OPENAI_API_KEY"));
}

obj Draft {
    has id: str = "",
        path: str = "",
        line: int = 0,
        end_line: int = 0,
        severity: str = "medium",
        category: str = "correctness",
        title: str = "",
        body: str = "",
        suggestion: str = "",
        evidence: str = "",
        confidence: float = 0.6,
        source: str = "agent",
        verified: bool = False,
        note: str = "",
        anchored: bool = True,
        looked_at: list[str] = [];
}

"""The inputs of one model call. Jobs are stored once under a fresh key and never changed,
so a `flow` worker can read its job lazily without racing the walker."""
obj Job {
    has kind: str = "file",
        paths: list[str] = [],
        lenses: list[str] = [],
        patch: str = "",
        signals: list[str] = [],
        checks: list[DraftCheck] = [],
        context: str = "",
        intent: str = "",
        meter: Meter = Meter(),
        reviewer: Reviewer = Reviewer(repo="", ref="", repo_name="", intent="");
}

"""What the walker keeps about a job in flight."""
obj Pending {
    has kind: str = "file",
        paths: list[str] = [],
        drafts: list[Draft] = [],
        future: any = None;
}

"""Run one job in a worker: a pure model call, billed to its stage, touching no graph."""
def run_job(job: Job) -> any {
    if job.kind == "file" {
        return metered(job.meter, "review", job.reviewer.review_file, job.paths[0], job.lenses, job.patch, job.signals);
    }
    if job.kind == "batch" {
        return metered(job.meter, "review", job.reviewer.review_batch, job.paths, job.patch);
    }
    if job.kind == "cross" {
        return metered(job.meter, "cross", job.reviewer.cross_file_review, job.patch, job.signals);
    }
    return metered(job.meter, "verify", verify_file, job.intent, job.paths[0], job.patch, job.checks, job.context);
}

glob SEV_RANK: dict[str, int] = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4};

def finding_dict(f: Finding) -> dict[str, any] {
    return {
        "id": f.id,
        "review_id": f.review_id,
        "pr_id": f.pr_id,
        "path": f.path,
        "line": f.line,
        "end_line": f.end_line,
        "severity": f.severity,
        "category": f.category,
        "title": f.title,
        "body": f.body,
        "suggestion": f.suggestion,
        "evidence": f.evidence,
        "confidence": f.confidence,
        "status": f.status,
        "source": f.source,
        "verified": f.verified,
        "verifier_note": f.verifier_note,
        "looked_at": f.looked_at,
        "anchored": f.anchored,
        "created": f.created,
        "replies": [{"author": r.author, "text": r.text, "ts": r.ts} for r in f.replies]
    };
}

def draft_dict(d: Draft) -> dict[str, any] {
    return {
        "id": d.id,
        "path": d.path,
        "line": d.line,
        "severity": d.severity,
        "category": d.category,
        "title": d.title,
        "body": d.body,
        "source": d.source,
        "confidence": d.confidence
    };
}

def _stage_list -> list[StageState] {
    return [StageState(key=s[0], label=s[1]) for s in STAGES];
}

def _draft_from(d: DraftFinding, path: str, source: str) -> Draft {
    return Draft(
        id=new_id("D"),
        path=(d.path or path).strip().lstrip("./"),
        line=max(0, d.line),
        end_line=max(d.line, d.end_line),
        severity=str(d.severity.value if hasattr(d.severity, "value") else d.severity),
        category=str(d.category.value if hasattr(d.category, "value") else d.category),
        title=d.title[:140],
        body=d.body,
        suggestion=d.suggestion,
        evidence=d.evidence[:600],
        confidence=float(d.confidence),
        source=source
    );
}

"""Pin a draft to a line the diff actually shows; drop it when its file is not in the change."""
def anchor(d: Draft, files: dict[str, FileDiff]) -> bool {
    f = files.get(d.path);
    if f is None {
        for (p, cand) in files.items() {
            if p.endswith("/" + d.path) or d.path.endswith("/" + p) {
                f = cand;
                d.path = p;
                break;
            }
        }
    }
    if f is None {
        return False;
    }
    valid = commentable_lines(f);
    if not valid {
        return False;
    }
    if d.line in valid {
        d.end_line = max(d.line, d.end_line);
        return True;
    }
    nearest = min(valid, key=lambda (n: int) -> int { return abs(n - d.line); });
    span = max(0, d.end_line - d.line);
    d.anchored = abs(nearest - d.line) <= ANCHOR_SLACK;
    d.line = nearest;
    d.end_line = nearest + span;
    return True;
}

def _words(t: str) -> set[str] {
    return set([w for w in t.lower().split() if len(w) > 2]);
}

def _same_issue(a: Draft, b: Draft) -> bool {
    if a.path != b.path {
        return False;
    }
    if b.line > a.end_line + 2 or b.end_line < a.line - 2 {
        return False;
    }
    wa = _words(a.title);
    wb = _words(b.title);
    overlap = len(wa & wb) / max(1, min(len(wa), len(wb)));
    return a.category == b.category or overlap >= 0.5;
}

"""Merge drafts about the same lines and problem; the more severe, more confident one wins."""
def dedupe(drafts: list[Draft]) -> list[Draft] {
    ranked = sorted(
        drafts,
        key=lambda (d: Draft) -> float { return SEV_RANK.get(d.severity, 5) * 10 - d.confidence; }
    );
    kept: list[Draft] = [];
    for d in ranked {
        twin: Draft | None = None;
        for k in kept {
            if _same_issue(k, d) {
                twin = k;
                break;
            }
        }
        if twin is None {
            kept.append(d);
        } elif d.source not in twin.source {
            twin.source = twin.source + "+" + d.source;
            twin.confidence = min(1.0, twin.confidence + 0.1);
        }
    }
    return kept;
}

"""The verdict follows from the surviving findings, whatever the synthesizer wrote."""
def verdict_for(drafts: list[Draft]) -> str {
    if any([d.severity in ("critical", "high") for d in drafts]) {
        return "request_changes";
    }
    if any([d.severity == "medium" for d in drafts]) {
        return "comment";
    }
    return "approve";
}

def _context_lines(repo: str, ref: str, d: Draft, span: int = 12) -> str {
    text = read_text(repo, d.path, ref);
    if not text {
        return "";
    }
    lines = text.split("\n");
    a = max(1, d.line - span);
    b = min(len(lines), max(d.line, d.end_line) + span);
    return "\n".join([f"{i}: {lines[i - 1]}" for i in range(a, b + 1)]);
}

"""Investigate the code around one flagged file: the model chooses which related code to read."""
walker:priv Investigate {
    has repo: str = "",
        ref: str = "",
        concerns: list[str] = [],
        notes: list[str] = [],
        looked: list[str] = [];

    can route with FileChange entry {
        if not [here-->][?:CodeRef] {
            disengage;
        }
        visit [here-->][?:CodeRef] by llm(
            select=(1, 3),
            intent="Read the related code most likely to confirm or refute these concerns about the change"
        );
    }

    can read with CodeRef entry {
        excerpt = ref_excerpt(self.repo, self.ref, here);
        if excerpt {
            self.notes.append(f"--- {here.path} ({here.preview[:80]})\n{excerpt}");
            self.looked.append(f"{here.path}:{here.line}");
            here.inspected = True;
        }
    }
}

sem Investigate.concerns = "The draft findings about the changed file that need confirming or refuting.";

walker:priv ReviewRun {
    has pr: PullRequestRef,
        focus: str = "",
        use_llm: bool = False,
        meter: Meter = Meter(),
        reviewer: Reviewer = Reviewer(repo="", ref="", repo_name="", intent=""),
        diffs: dict[str, FileDiff] = {},
        nodes: dict[str, FileChange] = {},
        plan: ReviewPlan = ReviewPlan(intent="", change_type="", focus_areas=[], files=[], cross_cutting=[]),
        commits: list[CommitInfo] = [],
        drafts: list[Draft] = [],
        pending: list[Pending] = [],
        jobs: dict[str, Job] = {},
        batch: list[str] = [],
        solo: int = 0,
        t0: float = 0.0,
        failed: str = "";

    def stage(rv: Review, key: str, status: str, detail: str = "") {
        for s in rv.stages {
            if s.key == key {
                s.status = status;
                s.detail = detail[:300];
                if status == "running" {
                    s.started = now();
                } elif status in ("done", "failed", "skipped") {
                    s.finished = now();
                }
            }
        }
        rv.stages = list(rv.stages);
        commit();
        emit(
            "review",
            {
                "phase": "stage",
                "review_id": rv.id,
                "pr_id": rv.pr_id,
                "stage": key,
                "status": status,
                "detail": detail[:300],
                "stages": [
                    {"key": s.key, "label": s.label, "status": s.status, "detail": s.detail}
                    for s in rv.stages
                ]
            }
        );
    }

    def feed(rv: Review, kind: str, title: str, detail: str = "", extra: dict[str, any] = {}) {
        rv.feed = [FeedItem(kind=kind, title=title[:200], detail=detail[:400], ts=now())] + rv.feed[:79];
        emit("review", {"phase": kind, "review_id": rv.id, "pr_id": rv.pr_id, "title": title, "detail": detail} | extra);
    }

    def note_file(rv: Review, fc: FileChange) {
        commit();
        emit(
            "review",
            {
                "phase": "file",
                "review_id": rv.id,
                "pr_id": rv.pr_id,
                "path": fc.path,
                "status": fc.state,
                "summary": fc.summary,
                "findings": fc.findings,
                "risk": fc.risk
            }
        );
    }

    can start with Review entry {
        self.t0 = time.time();
        rv = here;
        emit("review", {"phase": "start", "review_id": rv.id, "pr_id": rv.pr_id, "title": self.pr.title, "trigger": rv.trigger});
        self.stage(rv, "ingest", "running");
        files = [
            f
            for f in parse_unified_diff(pr_diff_text(rv.repo, self.pr))
            if f.path
        ][:MAX_FILES];
        if not files {
            self.stage(rv, "ingest", "failed", "No diff between head and base");
            self.failed = "No changes to review";
            return;
        }
        self.commits = pr_commits(rv.repo, self.pr);
        self.diffs = {f.path: f for f in files};
        ref_note = "" if rv.ref != "WORKTREE" or self.pr.kind == "worktree" else " · PR head unavailable, reading the worktree";
        self.stage(
            rv,
            "ingest",
            "done",
            f"{len(files)} files, +{sum([f.additions for f in files])} -{sum([f.deletions for f in files])}, {len(self.commits)} commits{ref_note}"
        );
        self.stage(rv, "triage", "running");
        risks = triage(files, [h.path for h in hotspots(rv.repo, 60)]);
        refs = 0;
        for r in risks {
            f = self.diffs[r.path];
            fc = FileChange(
                path=f.path,
                old_path=f.old_path,
                status=f.status,
                language=f.language,
                kind=r.kind,
                additions=f.additions,
                deletions=f.deletions,
                risk=r.score,
                signals=r.signals[:6]
            );
            rv +>:Covers:+> fc;
            self.nodes[f.path] = fc;
            if not f.binary and f.status != "deleted" and r.kind not in SKIP_KINDS {
                refs += build_context(rv.repo, rv.ref, fc, f);
            }
            for hit in static_hits(f) {
                self.drafts.append(
                    Draft(
                        id=new_id("D"),
                        path=hit.path,
                        line=hit.line,
                        end_line=hit.line,
                        severity=hit.severity,
                        category=hit.category,
                        title=hit.title,
                        body=hit.body,
                        confidence=0.5,
                        source="static"
                    )
                );
            }
        }
        rv.triage_risk = overall_risk(risks);
        emit(
            "review",
            {
                "phase": "triage",
                "review_id": rv.id,
                "pr_id": rv.pr_id,
                "risk": rv.triage_risk,
                "files": [
                    {"path": r.path, "risk": r.score, "kind": r.kind, "signals": r.signals, "additions": r.additions, "deletions": r.deletions}
                    for r in risks
                ]
            }
        );
        self.stage(
            rv,
            "triage",
            "done",
            f"Top risk {risks[0].path.split('/')[-1]} ({risks[0].score}); {len(self.drafts)} static hits; {refs} related-code links"
        );
        self.stage(rv, "plan", "running");
        self.plan = ReviewPlan(intent=self.pr.title, change_type="mixed", focus_areas=[], files=[], cross_cutting=[]);
        if self.use_llm {
            try {
                self.plan = metered(
                    self.meter,
                    "plan",
                    plan_review,
                    self.pr.title,
                    self.pr.body[:3000],
                    [c.subject for c in self.commits[:30]],
                    [
                        FileBrief(path=r.path, status=self.diffs[r.path].status, additions=r.additions, deletions=r.deletions, risk=r.score, signals=r.signals[:4])
                        for r in risks[:60]
                    ],
                    self.focus
                );
                self.stage(rv, "plan", "done", self.plan.intent[:220]);
            } except Exception as e {
                self.stage(rv, "plan", "failed", "Planner unavailable: " + str(e)[:160]);
            }
        } else {
            self.stage(rv, "plan", "skipped", "No model credentials; heuristic plan");
        }
        planned: dict[str, FilePlan] = {fp.path: fp for fp in self.plan.files if fp.path in self.diffs};
        ranked = sorted(risks, key=lambda (r: FileRisk) -> int { return 0 - r.score; });
        for (i, r) in enumerate(ranked) {
            fc = self.nodes[r.path];
            fp = planned.get(r.path);
            if fp {
                fc.priority = max(1, min(3, fp.priority));
                fc.lenses = fp.lenses[:4];
                fc.why = fp.why;
            } else {
                fc.priority = 1 if i < 4 and r.kind in ("code", "config") else (2 if r.score >= 25 else 3);
                fc.lenses = ["correctness", "reliability", "security"];
            }
        }
        rv.intent = self.plan.intent;
        self.reviewer = Reviewer(
            repo=rv.repo,
            ref=rv.ref,
            repo_name=os.path.basename(rv.repo),
            intent=self.plan.intent,
            focus=self.focus
        );
        commit();
        self.stage(rv, "review", "running", "Every reviewable file, riskiest first");
        visit sorted(
            [here->:Covers:->][?:FileChange],
            key=lambda (n: FileChange) -> int { return n.priority * 1000 - n.risk; }
        );
    }

    can lens with FileChange entry {
        f = self.diffs.get(here.path);
        if f is None or f.binary or here.status == "deleted" or here.kind in SKIP_KINDS {
            here.state = "skipped";
            return;
        }
        if not self.use_llm {
            here.state = "triaged";
            return;
        }
        if here.priority == 1 and self.solo < MAX_SOLO {
            self.solo += 1;
            here.state = "reviewing";
            job = Job(kind="file", paths=[here.path], lenses=here.lenses or ["correctness"], patch=render_file_patch(f, 9000), signals=here.signals[:4], meter=self.meter, reviewer=self.reviewer);
            self.pending.append(Pending(kind="file", paths=[here.path], future=self.submit(job)));
            return;
        }
        here.state = "batched";
        self.batch.append(here.path);
        size = sum([len(render_file_patch(self.diffs[p], 3000)) for p in self.batch]);
        if len(self.batch) >= BATCH_FILES or size >= BATCH_CHARS {
            self.launch_batch();
        }
    }

    """Start a job in a `flow` worker. `flow` evaluates its call lazily in the worker, so the
    job is parked under a key it never leaves; only the scalar key crosses (jaseci-labs/jac#10234)."""
    def submit(job: Job) -> any {
        key = new_id("J");
        self.jobs[key] = job;
        return flow run_job(self.jobs[key]);
    }

    def launch_batch {
        if not self.batch {
            return;
        }
        names = list(self.batch);
        self.batch = [];
        job = Job(kind="batch", paths=list(names), patch="\n\n".join([render_file_patch(self.diffs[p], 3000) for p in names]), meter=self.meter, reviewer=self.reviewer);
        self.pending.append(Pending(kind="batch", paths=names, future=self.submit(job)));
    }

    def gather(rv: Review) {
        self.launch_batch();
        if not self.pending {
            self.stage(rv, "review", "skipped", "No model credentials" if not self.use_llm else "Nothing reviewable");
            return;
        }
        by_future: dict[any, Pending] = {p.future: p for p in self.pending};
        done = 0;
        left = max(30.0, REVIEW_DEADLINE - (time.time() - self.t0));
        try {
            for fut in as_completed(list(by_future.keys()), timeout=left) {
                job = by_future[fut];
                done += 1;
                try {
                    result = fut.result();
                } except Exception as e {
                    for p in job.paths {
                        self.nodes[p].state = "failed";
                        self.note_file(rv, self.nodes[p]);
                    }
                    self.feed(rv, "warn", "Reviewer failed on " + ", ".join([p.split("/")[-1] for p in job.paths]), str(e)[:200]);
                    continue;
                }
                fresh: list[Draft] = [];
                if job.kind == "file" {
                    fc = self.nodes[job.paths[0]];
                    fc.summary = result.summary;
                    fresh = [_draft_from(d, fc.path, "lens:" + (fc.lenses[0] if fc.lenses else "general")) for d in result.findings if d.confidence >= 0.35];
                } else {
                    for s in result.files {
                        if s.path in self.nodes {
                            self.nodes[s.path].summary = s.summary;
                        }
                    }
                    fresh = [_draft_from(d, job.paths[0], "lens:batch") for d in result.findings if d.confidence >= 0.35];
                }
                for p in job.paths {
                    fc = self.nodes[p];
                    fc.state = "reviewed";
                    fc.findings = len([d for d in fresh if d.path == p]);
                    self.note_file(rv, fc);
                }
                self.drafts = self.drafts + fresh;
                if fresh {
                    emit("review", {"phase": "drafts", "review_id": rv.id, "pr_id": rv.pr_id, "path": job.paths[0], "drafts": [draft_dict(d) for d in fresh]});
                }
                self.stage(rv, "review", "running", f"{done}/{len(by_future)} reviewer calls back · {len(self.drafts)} drafts");
            }
        } except TimeoutError {
            self.feed(rv, "warn", "Reviewers ran past the deadline", f"{len(by_future) - done} calls abandoned");
        }
        reviewed = len([n for n in self.nodes.values() if n.state == "reviewed"]);
        self.stage(rv, "review", "done", f"{reviewed}/{len(self.nodes)} files reviewed ({self.solo} solo, {len(by_future) - self.solo} batches) · {len(self.drafts)} drafts");
    }

    def anchor_all(rv: Review) {
        kept: list[Draft] = [];
        for d in self.drafts {
            if anchor(d, self.diffs) {
                kept.append(d);
            } else {
                self.feed(rv, "drop", d.title, "Not in this change: " + d.path);
            }
        }
        before = len(kept);
        self.drafts = dedupe(kept);
        if before != len(self.drafts) {
            self.feed(rv, "info", f"Merged {before - len(self.drafts)} duplicate drafts");
        }
    }

    def cross(rv: Review) {
        self.stage(rv, "cross", "running");
        if not self.use_llm or len(self.diffs) < 2 {
            self.stage(rv, "cross", "skipped", "Single file" if self.use_llm else "No model credentials");
            return;
        }
        overview = "\n".join([
            f"- {n.path} (risk {n.risk}): {n.summary or f'+{n.additions}/-{n.deletions}'}"
            for n in sorted(self.nodes.values(), key=lambda (n: FileChange) -> int { return 0 - n.risk; })[:40]
        ]);
        try {
            job = Job(kind="cross", patch=overview, signals=self.plan.cross_cutting[:6], meter=self.meter, reviewer=self.reviewer);
            task = self.submit(job);
            extra: list[DraftFinding] = wait task;
            found = [_draft_from(d, d.path, "lens:cross-file") for d in extra if d.confidence >= 0.4];
            self.drafts = self.drafts + found;
            self.stage(rv, "cross", "done", f"{len(found)} cross-file issues");
        } except Exception as e {
            self.stage(rv, "cross", "failed", str(e)[:160]);
        }
    }

    def investigate(rv: Review) -> dict[str, str] {
        self.stage(rv, "investigate", "running");
        evidence: dict[str, str] = {};
        if not self.use_llm or not self.drafts {
            self.stage(rv, "investigate", "skipped", "Nothing to investigate" if self.use_llm else "No model credentials");
            return evidence;
        }
        paths: list[str] = [];
        for d in self.drafts {
            if d.path not in paths and d.severity in ("critical", "high", "medium") {
                paths.append(d.path);
            }
        }
        bill_to(self.meter, "investigate");
        read = 0;
        for p in paths[:MAX_SOLO] {
            fc = self.nodes.get(p);
            if fc is None {
                continue;
            }
            concerns = [d.title for d in self.drafts if d.path == p][:6];
            try {
                w = fc spawn Investigate(repo=rv.repo, ref=rv.ref, concerns=concerns);
            } except Exception as e {
                self.feed(rv, "warn", "Investigation failed on " + p.split("/")[-1], str(e)[:200]);
                continue;
            }
            if w.notes {
                evidence[p] = "\n\n".join(w.notes);
                read += len(w.looked);
                for d in self.drafts {
                    if d.path == p {
                        d.looked_at = w.looked;
                    }
                }
                self.feed(rv, "investigate", p.split("/")[-1] + ": read " + ", ".join([x.split("/")[-1] for x in w.looked]), "Chosen by the model from callers, tests, and co-changing files");
            }
        }
        unbill();
        commit();
        self.stage(rv, "investigate", "done", f"{read} related excerpts read for {len(evidence)} files");
        return evidence;
    }

    def verify(rv: Review, evidence: dict[str, str]) -> int {
        self.stage(rv, "verify", "running", f"Challenging {len(self.drafts)} drafts");
        if not self.use_llm or not self.drafts {
            self.stage(rv, "verify", "skipped", "Nothing to verify" if self.use_llm else "No model credentials");
            return 0;
        }
        jobs: list[Pending] = [];
        for p in sorted(set([d.path for d in self.drafts])) {
            mine = [d for d in self.drafts if d.path == p];
            for i in range(0, len(mine), VERIFY_BATCH) {
                chunk = mine[i:i + VERIFY_BATCH];
                around = "\n\n".join([f"[{d.id}] around line {d.line}\n" + _context_lines(rv.repo, rv.ref, d) for d in chunk]);
                job = Job(
                    kind="verify",
                    paths=[p],
                    intent=self.plan.intent,
                    patch=render_file_patch(self.diffs[p], 9000),
                    checks=[DraftCheck(id=d.id, line=d.line, severity=d.severity, category=d.category, title=d.title, body=d.body, evidence=d.evidence) for d in chunk],
                    context=(evidence.get(p, "") + "\n\n" + around)[:24000],
                    meter=self.meter,
                    reviewer=self.reviewer
                );
                jobs.append(Pending(kind="verify", paths=[p], drafts=chunk, future=self.submit(job)));
            }
        }
        dropped = 0;
        unverified = 0;
        survivors: list[Draft] = [];
        for job in jobs {
            chunk: list[Draft] = job.drafts;
            verdicts: list[Verdict] = [];
            try {
                verdicts = wait job.future;
            } except Exception as e {
                unverified += len(chunk);
                self.feed(rv, "warn", "Verifier failed on " + chunk[0].path.split("/")[-1], str(e)[:200]);
            }
            by_id: dict[str, Verdict] = {v.id: v for v in verdicts};
            for d in chunk {
                v = by_id.get(d.id);
                if v is None {
                    d.note = "Not verified";
                    survivors.append(d);
                    continue;
                }
                if v.keep {
                    d.verified = True;
                    d.severity = str(v.severity.value if hasattr(v.severity, "value") else v.severity);
                    d.note = v.reason;
                    survivors.append(d);
                } else {
                    dropped += 1;
                    self.feed(rv, "drop", d.title, "Verifier: " + v.reason);
                }
            }
        }
        self.drafts = survivors;
        tail = f", {unverified} unverified" if unverified else "";
        self.stage(rv, "verify", "done", f"Kept {len(self.drafts)}, dropped {dropped} as false positives{tail}");
        return dropped;
    }

    def conclude(rv: Review, dropped: int) {
        self.stage(rv, "synthesize", "running");
        self.drafts = sorted(self.drafts, key=lambda (d: Draft) -> int { return SEV_RANK.get(d.severity, 5) * 100000 + d.line; });
        blocking = len([d for d in self.drafts if d.severity in ("critical", "high")]);
        verdict = verdict_for(self.drafts);
        summary = ReviewSummary(
            verdict=VerdictKind(verdict),
            risk=rv.triage_risk,
            summary=f"Deterministic review of {len(self.diffs)} files: {len(self.drafts)} findings, {blocking} blocking.",
            highlights=[],
            concerns=[d.title for d in self.drafts[:4]],
            suggested_tests=[]
        );
        if self.use_llm {
            walk = "\n".join([f"- {n.path} (risk {n.risk}): {n.summary or 'not reviewed'}" for n in list(self.nodes.values())[:40]]);
            brief = "\n".join([f"- [{d.severity}/{d.category}] {d.path}:{d.line} {d.title}" for d in self.drafts[:40]]) or "(no findings)";
            stats = f"{len(self.diffs)} files, +{sum([f.additions for f in self.diffs.values()])} -{sum([f.deletions for f in self.diffs.values()])}, triage risk {rv.triage_risk}, {len(self.commits)} commits";
            try {
                summary = metered(self.meter, "synthesize", synthesize, self.plan.intent, walk, brief, stats);
            } except Exception as e {
                self.feed(rv, "warn", "Synthesizer failed", str(e)[:200]);
            }
        }
        written = str(summary.verdict.value if hasattr(summary.verdict, "value") else summary.verdict);
        risk = int(max(0, min(100, summary.risk)));
        if any([d.severity == "critical" for d in self.drafts]) {
            risk = max(risk, 80);
        } elif blocking {
            risk = max(risk, 60);
        }
        note = "" if written == verdict else f" (synthesizer said {written}; findings decide)";
        for d in self.drafts {
            fc = self.nodes.get(d.path);
            if fc is None {
                continue;
            }
            fc +>:Raised:+> Finding(
                id=new_id("F"),
                review_id=rv.id,
                pr_id=rv.pr_id,
                path=d.path,
                line=d.line,
                end_line=d.end_line,
                severity=d.severity,
                category=d.category,
                title=d.title,
                body=d.body,
                suggestion=d.suggestion,
                evidence=d.evidence,
                confidence=d.confidence,
                source=d.source,
                verified=d.verified,
                verifier_note=d.note,
                looked_at=d.looked_at,
                anchored=d.anchored,
                created=now()
            );
        }
        for fc in self.nodes.values() {
            fc.findings = len([d for d in self.drafts if d.path == fc.path]);
        }
        rv.verdict = verdict;
        rv.risk = risk;
        rv.summary = summary.summary;
        rv.highlights = summary.highlights[:3];
        rv.concerns = summary.concerns[:4];
        rv.tests = summary.suggested_tests[:4];
        rv.dropped = dropped;
        self.close(rv, "done");
        self.stage(rv, "synthesize", "done", verdict + note);
        pr = review_pr(rv);
        if pr {
            refresh_pr_rollup(pr);
        }
        commit();
        emit(
            "review",
            {
                "phase": "done",
                "review_id": rv.id,
                "pr_id": rv.pr_id,
                "verdict": verdict,
                "risk": risk,
                "findings": [finding_dict(f) for f in review_findings(rv)],
                "seconds": round(time.time() - self.t0, 1),
                "cost": rv.cost
            }
        );
    }

    def close(rv: Review, status: str) {
        rv.status = status;
        rv.finished = now();
        if self.meter.order or self.use_llm {
            rv.costs = self.meter.breakdown();
            rv.llm_calls = self.meter.total_calls();
            rv.tokens = self.meter.total_tokens();
            rv.cost = round(self.meter.total_cost(), 5);
        }
    }

    can finish with Review exit {
        rv = here;
        if self.failed {
            rv.error = self.failed;
            self.close(rv, "failed");
            commit();
            emit("review", {"phase": "failed", "review_id": rv.id, "pr_id": rv.pr_id, "error": self.failed});
            return;
        }
        self.gather(rv);
        self.cross(rv);
        self.anchor_all(rv);
        evidence = self.investigate(rv);
        dropped = self.verify(rv, evidence);
        self.conclude(rv, dropped);
    }
}

"""Create the Review under the caller's PR node and run the pipeline on it. Returns its id."""
def run_review(repo: str, pr: PullRequestRef, focus: str = "", trigger: str = "user") -> str {
    info = repo_info(repo);
    pr_n = ensure_pr(ensure_repo(info.path, info.name), pr.id, pr.kind, pr.title, pr.head, pr.base, pr.author, pr.url, pr.number);
    rv = Review(
        id=new_id("R"),
        pr_id=pr.id,
        repo=info.path,
        ref=pr_head_ref(info.path, pr) or "WORKTREE",
        status="running",
        focus=focus,
        stages=_stage_list(),
        started=now(),
        model=model_label(),
        trigger=trigger
    );
    pr_n +>:HasReview:+> rv;
    commit();
    ACTIVE[rv.id] = current_user() + "|" + pr.id;
    meter = Meter(budget=REVIEW_BUDGET);
    try {
        rv spawn ReviewRun(pr=pr, focus=focus, use_llm=llm_ready(), meter=meter);
    } except WriteConflict as wc {
        raise wc;
    } except Exception as e {
        rv.error = "Review crashed: " + str(e)[:300];
        rv.status = "failed";
        rv.finished = now();
        rv.costs = meter.breakdown();
        rv.cost = round(meter.total_cost(), 5);
        commit();
        emit("review", {"phase": "failed", "review_id": rv.id, "pr_id": rv.pr_id, "error": rv.error});
    } finally {
        unbill();
        ACTIVE.pop(rv.id, None);
    }
    return rv.id;
}

def is_active(review_id: str) -> bool {
    return review_id in ACTIVE;
}

def pr_running(pr_id: str) -> bool {
    return current_user() + "|" + pr_id in ACTIVE.values();
}
