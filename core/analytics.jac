import math;
import time;
import from datetime { date, timedelta }

obj FileTouch {
    has path: str = "",
        additions: int = 0,
        deletions: int = 0;
}

obj CommitRec {
    has sha: str = "",
        author: str = "",
        ts: int = 0,
        subject: str = "",
        files: list[FileTouch] = [];
}

glob HISTORY_DEPTH: int = 1500,
     HIDDEN_PREFIXES: list[str] = ["node_modules/", ".jac/", "dist/", "vendor/"];

def _area(path: str, depth: int = 2) -> str;

def history(repo: str) -> list[CommitRec];
def rename_target(path: str) -> str;

def sizes(repo: str) -> dict[str, int];

def activity(repo: str, days: int = 371) -> list[DayCount];

def weekly(repo: str, weeks: int = 26) -> list[WeekBucket];

glob KINDS: list[str] = ["feat", "fix", "refactor", "docs", "test", "chore", "perf", "other"];

def commit_kind(subject: str) -> str;

def kinds_by_month(repo: str, months: int = 9) -> list[KindMonth];

def _visible(path: str) -> bool;

def hotspots(repo: str, limit: int = 40) -> list[Hotspot];

def contributors(repo: str, limit: int = 20) -> list[Contributor];

def ownership(repo: str, limit: int = 16) -> list[Ownership];

def languages(repo: str) -> list[LangSlice];

def structure(repo: str, depth: int = 2, limit: int = 60) -> list[TreeCell];

def coupling(repo: str, max_nodes: int = 28, min_weight: int = 3) -> CouplingGraph;

def stats(repo: str) -> RepoStats;

def warm(repo: str);
