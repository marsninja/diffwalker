import threading;
import time;
import uuid;
import from stdjac { Message }

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

node ChatThread {
    has id: str = "",
        title: str = "",
        created: float = 0.0,
        updated: float = 0.0,
        transcript: list[ChatMsg] = [],
        history: list[Message] = [];
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

glob _making: threading.Lock = threading.Lock(),
     SEVERITIES: list[str] = ["critical", "high", "medium", "low", "info"],
     CATEGORIES: list[str] = [
         "correctness",
         "security",
         "performance",
         "reliability",
         "maintainability",
         "testing",
         "api",
         "style",
     ];

def new_id(prefix: str) -> str;

def now -> float;
def workspace -> Workspace;

def repo_node(repo_path: str) -> Repo | None;

def ensure_repo(path: str, name: str) -> Repo;

def pr_node(repo: Repo, pr_id: str) -> PullRequest | None;

def ensure_pr(
    repo: Repo,
    pr_id: str,
    kind: str,
    title: str,
    head: str,
    base: str,
    author: str,
    url: str,
    number: int,
) -> PullRequest;

def pr_reviews(pr: PullRequest) -> list[Review];

def review_files(review: Review) -> list[FileChange];
def review_findings(review: Review) -> list[Finding];

def file_change(review: Review, file_path: str) -> FileChange | None;

def review_of(pr: PullRequest, status: str = "done") -> Review | None;
def find_review(review_id: str) -> Review | None;

def find_finding(finding_id: str) -> Finding | None;

def review_pr(review: Review) -> PullRequest | None;

def finding_review(f: Finding) -> Review | None;

def repo_insights(repo: Repo) -> list[Insight];

def chat_thread(thread_id: str) -> ChatThread;

def refresh_pr_rollup(pr: PullRequest);

def touch_rollup(f: Finding);

walker:priv CollectFindings {
    has status: str = "",
        latest_only: bool = True,
        found: list[Finding] = [];

    can at_repo with Repo entry;

    can at_pr with PullRequest entry;

    can at_review with Review entry;

    can at_file with FileChange entry;

    can at_finding with Finding entry;
}

def repo_findings(repo: Repo, status: str = "", latest_only: bool = True) -> list[Finding];
