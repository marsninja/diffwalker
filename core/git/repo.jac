import os;
import json;
import shutil;
import subprocess;
import threading;
import time;
import hashlib;

obj GitResult {
    has ok: bool = False,
        out: str = "",
        err: str = "";
}

glob _memo: dict[str, any] = {},
     _memo_at: dict[str, float] = {},
     _memo_lock: threading.Lock = threading.Lock();

def run_git(repo: str, args: list[str], timeout: int = 40) -> GitResult;

def git_out(repo: str, args: list[str], timeout: int = 40) -> str;
def memo[T](key: str, ttl: float, producer: Callable[[], T]) -> T;

def forget(prefix: str);

def short_id(seed: str) -> str;

def resolve_repo(path: str) -> str;

def head_sha(repo: str) -> str;

def ref_exists(repo: str, ref: str) -> bool;

def default_base(repo: str) -> str;

def github_slug(url: str) -> str;

def pr_remote(repo: str) -> str;

def repo_info(repo: str) -> RepoInfo;

def _worktree_pr(repo: str, base: str) -> PullRequestRef | None;

def _shortstat(stat: str) -> list[int];

def _branch_prs(repo: str, base: str, limit: int) -> list[PullRequestRef];

def gh_available -> bool;

def _github_prs(repo: str, slug: str, limit: int) -> list[PullRequestRef];

def discover_prs(repo: str, include_github: bool = True, limit: int = 24) -> list[PullRequestRef];

def find_pr(repo: str, pr_id: str) -> PullRequestRef | None;

def _untracked_patch(repo: str) -> str;

def pr_diff_text(repo: str, pr: PullRequestRef) -> str;

def pr_commits(repo: str, pr: PullRequestRef, limit: int = 60) -> list[CommitInfo];
def safe_ref(ref: str) -> bool;
def github_head_ref(repo: str, pr: PullRequestRef) -> str;
def pr_head_ref(repo: str, pr: PullRequestRef) -> str;

def read_text(repo: str, path: str, ref: str = "WORKTREE") -> str;
def grep(
    repo: str, pattern: str, glob_pat: str = "", limit: int = 60, ref: str = "WORKTREE"
) -> list[str];

def file_log(repo: str, path: str, limit: int = 12) -> list[CommitInfo];

def blame_summary(repo: str, path: str, start: int, end: int, ref: str = "HEAD") -> list[str];
