import threading;
import from stdjac { commit }

glob _acting: threading.Lock = threading.Lock();

def _manual_review(pr_n: PullRequest, repo: str, pr_id: str, source: str) -> Review;
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
    source: str,
) -> Finding | None;

def set_status(finding_id: str, status: str, note: str, author: str) -> Finding | None;

def add_reply(finding_id: str, text: str, author: str) -> Finding | None;

def pin_insight(repo: str, title: str, kind: str, caption: str, spec: str) -> Insight;

def unpin_insight(repo: str, insight_id: str) -> bool;
def choose_repo(path: str) -> str;
