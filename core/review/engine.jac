import os;
import queue;
import time;
import from stdjac { commit }

glob STAGES: list[list[str]] = [
         ["ingest", "Ingest diff"],
         ["triage", "Risk triage"],
         ["plan", "Plan review"],
         ["review", "Specialist lenses"],
         ["cross", "Cross-file analysis"],
         ["investigate", "Investigate context"],
         ["verify", "Adversarial verify"],
         ["synthesize", "Synthesize verdict"],
     ],
     MAX_SOLO: int = 8,
     BATCH_FILES: int = 6,
     BATCH_CHARS: int = 9000,
     MAX_FILES: int = 80,
     VERIFY_BATCH: int = 8,
     ANCHOR_SLACK: int = 8,
     REVIEW_DEADLINE: float = float(os.environ.get("DIFFWALKER_REVIEW_DEADLINE", "900") or 900),
     SKIP_KINDS: list[str] = ["generated"],
     ACTIVE: dict[str, str] = {};
def model_name -> str;

def model_label -> str;
def llm_ready -> bool;

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

obj Pending {
    has job: Job,
        task: Task[BatchReview];
}

obj Check {
    has job: Job,
        drafts: list[Draft],
        task: Task[list[Verdict]];
}

def review_job(job: Job) -> BatchReview;
def review_and_tell(job: Job, finished: queue.Queue[int], n: int) -> BatchReview;

def cross_job(job: Job) -> list[DraftFinding];

def verify_job(job: Job) -> list[Verdict];

glob SEV_RANK: dict[str, int] = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4};

def draft_note(d: Draft) -> DraftNote;

def _stage_list -> list[StageState];

def _draft_from(d: DraftFinding, path: str, source: str) -> Draft;
def anchor(d: Draft, files: dict[str, FileDiff]) -> bool;

def _words(t: str) -> set[str];

def _same_issue(a: Draft, b: Draft) -> bool;
def dedupe(drafts: list[Draft]) -> list[Draft];
def verdict_for(drafts: list[Draft]) -> str;

def _context_lines(repo: str, ref: str, d: Draft, span: int = 12) -> str;

walker:priv Investigate {
    has repo: str = "",
        ref: str = "",
        concerns: list[str] = [],
        notes: list[str] = [],
        looked: list[str] = [];

    can route with FileChange entry;

    can read with CodeRef entry;
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
        plan: ReviewPlan = ReviewPlan(
            intent="", change_type="", focus_areas=[], files=[], cross_cutting=[]
        ),
        commits: list[CommitInfo] = [],
        drafts: list[Draft] = [],
        pending: list[Pending] = [],
        finished: queue.Queue[int] = queue.Queue(),
        batch: list[str] = [],
        solo: int = 0,
        t0: float = 0.0,
        failed: str = "";

    def stage(rv: Review, key: str, status: str, detail: str = "");

    def feed(rv: Review, kind: str, title: str, detail: str = "");

    def note_file(rv: Review, fc: FileChange);

    can start with Review entry;

    can lens with FileChange entry;

    def launch_batch;
    def submit(job: Job);
    def gather(rv: Review);

    def anchor_all(rv: Review);

    def cross(rv: Review);

    def investigate(rv: Review) -> dict[str, str];

    def verify(rv: Review, evidence: dict[str, str]) -> int;

    def conclude(rv: Review, dropped: int);

    def close(rv: Review, status: str);

    can finish with Review exit;
}

def run_review(repo: str, pr: PullRequestRef, focus: str = "", trigger: str = "user") -> str;

def is_active(review_id: str) -> bool;

def pr_running(pr_id: str) -> bool;
