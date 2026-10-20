import time;
import uuid;

obj Reply {
    has author: str = "",
        text: str = "",
        ts: float = 0.0;
}

obj StageState {
    has key: str = "",
        label: str = "",
        status: str = "pending",
        detail: str = "",
        started: float = 0.0,
        finished: float = 0.0;
}

obj StageCost {
    has stage: str = "",
        calls: int = 0,
        tokens: int = 0,
        cached: int = 0,
        cost: float = 0.0,
        ms: float = 0.0;
}

obj FeedItem {
    has kind: str = "info",
        title: str = "",
        detail: str = "",
        ts: float = 0.0;
}

obj ToolTrace {
    has tool: str = "",
        args: str = "",
        result: str = "",
        ok: bool = True;
}

obj ChatMsg {
    has role: str = "user",
        text: str = "",
        ts: float = 0.0,
        tools: list[ToolTrace] = [],
        cards: list[str] = [],
        tokens: int = 0,
        cost: float = 0.0;
}

node Workspace {
    has active_repo: str = "",
        recent: list[str] = [];
}

node Repo {
    has path: str = "",
        name: str = "",
        added_at: float = 0.0;
}

node PullRequest {
    has id: str = "",
        kind: str = "branch",
        number: int = 0,
        title: str = "",
        head: str = "",
        base: str = "",
        author: str = "",
        url: str = "",
        last_review: str = "",
        verdict: str = "",
        risk: int = -1,
        open_findings: int = 0;
}

node Review {
    has id: str = "",
        pr_id: str = "",
        repo: str = "",
        ref: str = "",
        status: str = "running",
        verdict: str = "",
        risk: int = 0,
        triage_risk: int = 0,
        summary: str = "",
        intent: str = "",
        focus: str = "",
        highlights: list[str] = [],
        concerns: list[str] = [],
        tests: list[str] = [],
        stages: list[StageState] = [],
        feed: list[FeedItem] = [],
        costs: list[StageCost] = [],
        started: float = 0.0,
        finished: float = 0.0,
        model: str = "",
        llm_calls: int = 0,
        tokens: int = 0,
        cost: float = 0.0,
        dropped: int = 0,
        error: str = "",
        trigger: str = "user";
}

node FileChange {
    has path: str = "",
        old_path: str = "",
        status: str = "modified",
        language: str = "",
        kind: str = "code",
        additions: int = 0,
        deletions: int = 0,
        risk: int = 0,
        signals: list[str] = [],
        lenses: list[str] = [],
        priority: int = 2,
        why: str = "",
        summary: str = "",
        state: str = "queued",
        findings: int = 0;
}

sem FileChange = "A file changed by the pull request under review.";
sem FileChange.risk = "Deterministic 0-100 triage risk computed before any model call.";
sem FileChange.signals = "Why triage scored it that way: size, history hotspot rank, sensitive area, static pattern hits.";

node CodeRef {
    has path: str = "",
        line: int = 0,
        symbol: str = "",
        preview: str = "",
        inspected: bool = False;
}

sem CodeRef = "Code elsewhere in the repository that relates to a changed file. Visiting it reads that code into the investigation.";
sem CodeRef.preview = "The first matching line, as found by git grep or git history.";

node Finding {
    has id: str = "",
        review_id: str = "",
        pr_id: str = "",
        path: str = "",
        line: int = 0,
        end_line: int = 0,
        severity: str = "medium",
        category: str = "correctness",
        title: str = "",
        body: str = "",
        suggestion: str = "",
        evidence: str = "",
        confidence: float = 0.7,
        status: str = "open",
        source: str = "agent",
        verified: bool = False,
        verifier_note: str = "",
        looked_at: list[str] = [],
        anchored: bool = True,
        created: float = 0.0,
        replies: list[Reply] = [];
}

node Insight {
    has id: str = "",
        title: str = "",
        kind: str = "bar",
        caption: str = "",
        spec: str = "{}",
        created: float = 0.0,
        pinned: bool = True,
        prompt: str = "";
}

node ChatThread {
    has id: str = "",
        title: str = "",
        created: float = 0.0,
        updated: float = 0.0,
        transcript: list[ChatMsg] = [],
        history: list[dict[str, any]] = [];
}

edge HasRepo: Root --> Repo {}

edge HasPR: Repo --> PullRequest {}

edge HasReview: PullRequest --> Review {}

edge Covers: Review --> FileChange {}

edge Raised: FileChange --> Finding {}

edge CalledFrom: FileChange --> CodeRef {
    has symbol: str = "";
}

edge TestedBy: FileChange --> CodeRef {}

edge ChangesWith: FileChange --> CodeRef {
    has times: int = 0;
}

sem CalledFrom = "The target uses a function, class, or constant that this change defines or modifies. A broken caller lives here.";
sem TestedBy = "The target is a test that exercises the changed file. It shows the expected behaviour.";
sem ChangesWith = "The target historically changes in the same commits as the changed file (temporal coupling). It may need a matching edit.";
sem ChangesWith.times = "How many past commits touched both files.";

edge Pinned: Repo --> Insight {}

edge Talked: Root --> ChatThread {}

glob SEVERITIES: list[str] = ["critical", "high", "medium", "low", "info"],
     CATEGORIES: list[str] = [
         "correctness",
         "security",
         "performance",
         "reliability",
         "maintainability",
         "testing",
         "api",
         "style"
     ];

def new_id(prefix: str) -> str {
    return prefix + "-" + uuid.uuid4().hex[:8];
}

def now -> float {
    return time.time();
}

"""The caller's workspace: active repository and recent ones, one per user root."""
def workspace -> Workspace {
    found = [root-->][?:Workspace];
    if found {
        return found[0];
    }
    ws = Workspace();
    root ++> ws;
    return ws;
}

def repo_node(repo_path: str) -> Repo | None {
    found = [root->:HasRepo:->][?:Repo, path == repo_path];
    return found[0] if found else None;
}

def ensure_repo(path: str, name: str) -> Repo {
    r = repo_node(path);
    if r {
        return r;
    }
    fresh = Repo(path=path, name=name, added_at=now());
    root +>:HasRepo:+> fresh;
    return fresh;
}

def pr_node(repo: Repo, pr_id: str) -> PullRequest | None {
    found = [repo->:HasPR:->][?:PullRequest, id == pr_id];
    return found[0] if found else None;
}

def ensure_pr(
    repo: Repo,
    pr_id: str,
    kind: str,
    title: str,
    head: str,
    base: str,
    author: str,
    url: str,
    number: int
) -> PullRequest {
    p = pr_node(repo, pr_id);
    if p is None {
        p = PullRequest(id=pr_id);
        repo +>:HasPR:+> p;
    }
    p.kind = kind;
    p.title = title or p.title;
    p.head = head or p.head;
    p.base = base or p.base;
    p.author = author or p.author;
    p.url = url or p.url;
    p.number = number or p.number;
    return p;
}

def pr_reviews(pr: PullRequest) -> list[Review] {
    reviews = [pr->:HasReview:->][?:Review];
    return sorted(reviews, key=lambda (r: Review) -> float { return 0 - r.started; });
}

def review_files(review: Review) -> list[FileChange] {
    files = [review->:Covers:->][?:FileChange];
    return sorted(files, key=lambda (f: FileChange) -> int { return 0 - f.risk; });
}

"""Every finding of a review, two hops away: Review -> FileChange -> Finding."""
def review_findings(review: Review) -> list[Finding] {
    return [review->:Covers:->->:Raised:->][?:Finding];
}

def file_change(review: Review, file_path: str) -> FileChange | None {
    found = [review->:Covers:->][?:FileChange, path == file_path];
    return found[0] if found else None;
}

def review_of(pr: PullRequest, status: str = "done") -> Review | None {
    for rv in pr_reviews(pr) {
        if not status or rv.status == status {
            return rv;
        }
    }
    return None;
}

"""Look a review up by id under the caller's own root; one query, never another user's."""
def find_review(review_id: str) -> Review | None {
    found = [root->:HasRepo:->->:HasPR:->->:HasReview:->][?:Review, id == review_id];
    return found[0] if found else None;
}

def find_finding(finding_id: str) -> Finding | None {
    found = [root->:HasRepo:->->:HasPR:->->:HasReview:->->:Covers:->->:Raised:->][?:Finding, id == finding_id];
    return found[0] if found else None;
}

def review_pr(review: Review) -> PullRequest | None {
    found = [review<-:HasReview:<-][?:PullRequest];
    return found[0] if found else None;
}

def finding_review(f: Finding) -> Review | None {
    found = [f<-:Raised:<-<-:Covers:<-][?:Review];
    return found[0] if found else None;
}

def repo_insights(repo: Repo) -> list[Insight] {
    found = [repo->:Pinned:->][?:Insight];
    return sorted(found, key=lambda (i: Insight) -> float { return 0 - i.created; });
}

def chat_thread(thread_id: str) -> ChatThread {
    found = [root->:Talked:->][?:ChatThread, id == thread_id];
    if found {
        return found[0];
    }
    t = ChatThread(id=thread_id, created=now(), updated=now());
    root +>:Talked:+> t;
    return t;
}

def refresh_pr_rollup(pr: PullRequest) {
    latest = review_of(pr, "done");
    if latest is None {
        return;
    }
    pr.last_review = latest.id;
    pr.verdict = latest.verdict;
    pr.risk = latest.risk;
    pr.open_findings = len(
        [
            f
            for f in review_findings(latest)
            if f.status == "open"
        ]
    );
}

def touch_rollup(f: Finding) {
    rv = finding_review(f);
    if rv {
        pr = review_pr(rv);
        if pr {
            refresh_pr_rollup(pr);
        }
    }
}

"""Collect findings across a repository's pull requests, newest finished review of each."""
walker:priv CollectFindings {
    has status: str = "",
        latest_only: bool = True,
        found: list[Finding] = [];

    can at_repo with Repo entry {
        visit [here->:HasPR:->];
    }

    can at_pr with PullRequest entry {
        done = [
            rv
            for rv in pr_reviews(here)
            if rv.status == "done"
        ];
        visit done[:1] if self.latest_only else done;
    }

    can at_review with Review entry {
        visit [here->:Covers:->];
    }

    can at_file with FileChange entry {
        visit [here->:Raised:->];
    }

    can at_finding with Finding entry {
        if not self.status or here.status == self.status {
            self.found.append(here);
        }
    }
}

def repo_findings(
    repo: Repo, status: str = "", latest_only: bool = True
) -> list[Finding] {
    w = repo spawn CollectFindings(status=status, latest_only=latest_only);
    return w.found;
}
