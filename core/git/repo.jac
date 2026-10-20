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

obj RepoInfo {
    has path: str = "",
        name: str = "",
        branch: str = "",
        head: str = "",
        base: str = "",
        remote: str = "",
        github: str = "",
        commits: int = 0,
        files: int = 0,
        contributors: int = 0,
        first_commit: str = "",
        last_commit: str = "",
        is_git: bool = False,
        error: str = "";
}

obj PullRequestRef {
    has id: str = "",
        kind: str = "branch",
        number: int = 0,
        title: str = "",
        head: str = "",
        base: str = "",
        author: str = "",
        updated: str = "",
        updated_ts: int = 0,
        ahead: int = 0,
        behind: int = 0,
        files_changed: int = 0,
        additions: int = 0,
        deletions: int = 0,
        url: str = "",
        state: str = "open",
        body: str = "";
}

obj CommitInfo {
    has sha: str = "",
        author: str = "",
        ts: int = 0,
        subject: str = "";
}

glob _memo: dict[str, any] = {},
     _memo_at: dict[str, float] = {},
     _memo_lock: any = threading.Lock();

def run_git(repo: str, args: list[str], timeout: int = 40) -> GitResult {
    try {
        p = subprocess.run(
            ["git", "-C", repo] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            errors="replace"
        );
        return GitResult(ok=p.returncode == 0, out=p.stdout, err=p.stderr);
    } except Exception as e {
        return GitResult(ok=False, out="", err=str(e));
    }
}

def git_out(repo: str, args: list[str], timeout: int = 40) -> str {
    r = run_git(repo, args, timeout);
    return r.out if r.ok else "";
}

def memo(key: str, ttl: float, producer: Callable[[], any]) -> any {
    now = time.time();
    with _memo_lock {
        if key in _memo and now - _memo_at.get(key, 0.0) < ttl {
            return _memo[key];
        }
    }
    value = producer();
    with _memo_lock {
        _memo[key] = value;
        _memo_at[key] = time.time();
    }
    return value;
}

def forget(prefix: str) -> None {
    with _memo_lock {
        for k in list(_memo.keys()) {
            if k.startswith(prefix) {
                _memo.pop(k, None);
                _memo_at.pop(k, None);
            }
        }
    }
}

def short_id(seed: str) -> str {
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:10];
}

def resolve_repo(path: str) -> str {
    expanded = os.path.abspath(os.path.expanduser(path.strip() or "."));
    top = git_out(expanded, ["rev-parse", "--show-toplevel"]).strip();
    return top;
}

def head_sha(repo: str) -> str {
    return git_out(repo, ["rev-parse", "HEAD"]).strip();
}

def ref_exists(repo: str, ref: str) -> bool {
    return run_git(repo, ["rev-parse", "--verify", "--quiet", ref + "^{commit}"]).ok;
}

def default_base(repo: str) -> str {
    sym = git_out(
        repo, ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"]
    ).strip();
    candidates: list[str] = ["upstream/main", "main", "master"];
    if sym {
        candidates = candidates + [sym.replace("refs/remotes/", "")];
    }
    candidates = candidates + ["origin/main", "origin/master", "develop"];
    for c in candidates {
        if ref_exists(repo, c) {
            return c;
        }
    }
    return "HEAD";
}

def github_slug(url: str) -> str {
    u = url.strip();
    if "github.com" not in u {
        return "";
    }
    tail = u.split("github.com")[-1].lstrip(":/");
    if tail.endswith(".git") {
        tail = tail[:-4];
    }
    parts = tail.split("/");
    return parts[0] + "/" + parts[1] if len(parts) >= 2 else "";
}

def pr_remote(repo: str) -> str {
    for name in ["upstream", "origin"] {
        url = git_out(repo, ["remote", "get-url", name]).strip();
        if url and github_slug(url) {
            return url;
        }
    }
    return git_out(repo, ["remote", "get-url", "origin"]).strip();
}

def repo_info(repo: str) -> RepoInfo {
    def build -> RepoInfo {
        if not repo or not os.path.isdir(repo) {
            return RepoInfo(path=repo, error="Not a directory");
        }
        top = resolve_repo(repo);
        if not top {
            return RepoInfo(path=repo, error="Not a git repository");
        }
        remote = pr_remote(top);
        counts = git_out(top, ["rev-list", "--count", "HEAD"]).strip();
        files = git_out(top, ["ls-files"]).count("\n");
        authors = git_out(top, ["shortlog", "-sn", "--no-merges", "HEAD"]).strip();
        first = git_out(
            top, ["log", "--reverse", "--format=%aI", "--max-parents=0", "HEAD"]
        ).strip().split(
            "\n"
        )[0];
        last = git_out(top, ["log", "-1", "--format=%aI"]).strip();
        return RepoInfo(
            path=top,
            name=os.path.basename(top),
            branch=git_out(top, ["rev-parse", "--abbrev-ref", "HEAD"]).strip(),
            head=head_sha(top)[:10],
            base=default_base(top),
            remote=remote,
            github=github_slug(remote),
            commits=int(counts) if counts.isdigit() else 0,
            files=files,
            contributors=len(authors.split("\n")) if authors else 0,
            first_commit=first,
            last_commit=last,
            is_git=True
        );
    }
    return memo("info:" + repo, 20.0, build);
}

def _worktree_pr(repo: str, base: str) -> PullRequestRef | None {
    status = git_out(repo, ["status", "--porcelain"]).strip();
    if not status {
        return None;
    }
    stat = git_out(repo, ["diff", "--shortstat", "HEAD"]).strip();
    nums = _shortstat(stat);
    others = git_out(repo, ["ls-files", "--others", "--exclude-standard"]).strip();
    untracked = len(others.split("\n")) if others else 0;
    return PullRequestRef(
        id="worktree",
        kind="worktree",
        title="Uncommitted changes on "
            + git_out(repo, ["rev-parse", "--abbrev-ref", "HEAD"]).strip(),
        head="WORKTREE",
        base="HEAD",
        author=git_out(repo, ["config", "user.name"]).strip(),
        updated=time.strftime("%Y-%m-%dT%H:%M:%S"),
        updated_ts=int(time.time()),
        ahead=0,
        files_changed=nums[0] + untracked,
        additions=nums[1],
        deletions=nums[2],
        body=status[:2000]
    );
}

def _shortstat(stat: str) -> list[int] {
    files = 0;
    adds = 0;
    dels = 0;
    for part in stat.split(",") {
        p = part.strip();
        num = p.split(" ")[0] if p else "";
        if not num.isdigit() {
            continue;
        }
        if "file" in p {
            files = int(num);
        } elif "insertion" in p {
            adds = int(num);
        } elif "deletion" in p {
            dels = int(num);
        }
    }
    return [files, adds, dels];
}

def _branch_prs(repo: str, base: str, limit: int) -> list[PullRequestRef] {
    fmt = "%(refname:short)%09%(committerdate:unix)%09%(committerdate:iso-strict)%09%(authorname)%09%(subject)";
    rows = git_out(
        repo, ["for-each-ref", "refs/heads", "--sort=-committerdate", "--format=" + fmt]
    ).strip().split(
        "\n"
    );
    base_short = base.split("/")[-1];
    out: list[PullRequestRef] = [];
    for row in rows {
        if len(out) >= limit {
            break;
        }
        cols = row.split("\t");
        if len(cols) < 5 {
            continue;
        }
        name = cols[0];
        if name == base or name == base_short {
            continue;
        }
        lr = git_out(
            repo, ["rev-list", "--left-right", "--count", base + "..." + name]
        ).strip().split();
        if len(lr) != 2 {
            continue;
        }
        behind = int(lr[0]);
        ahead = int(lr[1]);
        if ahead == 0 {
            continue;
        }
        nums = _shortstat(
            git_out(repo, ["diff", "--shortstat", base + "..." + name]).strip()
        );
        out.append(
            PullRequestRef(
                id="b-" + short_id(repo + "|branch|" + name),
                kind="branch",
                title=cols[4],
                head=name,
                base=base,
                author=cols[3],
                updated=cols[2],
                updated_ts=int(cols[1]) if cols[1].isdigit() else 0,
                ahead=ahead,
                behind=behind,
                files_changed=nums[0],
                additions=nums[1],
                deletions=nums[2]
            )
        );
    }
    return out;
}

def gh_available -> bool {
    return shutil.which("gh") is not None;
}

def _github_prs(repo: str, slug: str, limit: int) -> list[PullRequestRef] {
    if not slug or not gh_available() {
        return [];
    }
    try {
        p = subprocess.run(
            [
                "gh",
                "pr",
                "list",
                "--repo",
                slug,
                "--limit",
                str(limit),
                "--json",
                "number,title,headRefName,baseRefName,author,updatedAt,additions,deletions,changedFiles,url,state,body"
            ],
            capture_output=True,
            text=True,
            timeout=25
        );
        if p.returncode != 0 {
            return [];
        }
        data = json.loads(p.stdout or "[]");
    } except Exception {
        return [];
    }
    out: list[PullRequestRef] = [];
    for d in data {
        updated = str(d.get("updatedAt", ""));
        ts = 0;
        try {
            ts = int(time.mktime(time.strptime(updated[:19], "%Y-%m-%dT%H:%M:%S")));
        } except Exception {
            ts = 0;
        }
        author = d.get("author") or {};
        out.append(
            PullRequestRef(
                id="gh-" + str(d.get("number", 0)),
                kind="github",
                number=int(d.get("number", 0)),
                title=str(d.get("title", "")),
                head=str(d.get("headRefName", "")),
                base=str(d.get("baseRefName", "")),
                author=str(author.get("login", "")),
                updated=updated,
                updated_ts=ts,
                files_changed=int(d.get("changedFiles", 0)),
                additions=int(d.get("additions", 0)),
                deletions=int(d.get("deletions", 0)),
                url=str(d.get("url", "")),
                state=str(d.get("state", "OPEN")).lower(),
                body=str(d.get("body", "") or "")[:4000]
            )
        );
    }
    return out;
}

def discover_prs(
    repo: str, include_github: bool = True, limit: int = 24
) -> list[PullRequestRef] {
    def build -> list[PullRequestRef] {
        info = repo_info(repo);
        if not info.is_git {
            return [];
        }
        out: list[PullRequestRef] = [];
        wt = _worktree_pr(info.path, info.base);
        if wt {
            out.append(wt);
        }
        out = out + _branch_prs(info.path, info.base, limit);
        if include_github {
            out = out + _github_prs(info.path, info.github, limit);
        }
        return out;
    }
    return memo(f"prs:{repo}:{include_github}", 45.0, build);
}

def find_pr(repo: str, pr_id: str) -> PullRequestRef | None {
    for p in discover_prs(repo) {
        if p.id == pr_id {
            return p;
        }
    }
    if pr_id.startswith("gh-") and pr_id[3:].isdigit() {
        info = repo_info(repo);
        if info.github and gh_available() {
            return PullRequestRef(
                id=pr_id,
                kind="github",
                number=int(pr_id[3:]),
                title="GitHub PR #" + pr_id[3:],
                url=f"https://github.com/{info.github}/pull/{pr_id[3:]}"
            );
        }
    }
    return None;
}

def _untracked_patch(repo: str) -> str {
    names = git_out(repo, ["ls-files", "--others", "--exclude-standard"]).strip();
    if not names {
        return "";
    }
    chunks: list[str] = [];
    for name in names.split("\n")[:40] {
        full = os.path.join(repo, name);
        if os.path.islink(full)
            or not os.path.realpath(full).startswith(os.path.realpath(repo) + os.sep) {
            continue;
        }
        try {
            if os.path.getsize(full) > 200000 {
                continue;
            }
            with open(full, "r", errors="replace") as fh {
                body = fh.read();
            }
        } except Exception {
            continue;
        }
        lines = body.split("\n");
        if lines and lines[-1] == "" {
            lines = lines[:-1];
        }
        head = f"diff --git a/{name} b/{name}\nnew file mode 100644\n--- /dev/null\n+++ b/{name}\n@@ -0,0 +1,{len(
            lines
        )} @@";
        chunks.append(head + "\n" + "\n".join(["+" + l for l in lines]));
    }
    return "\n".join(chunks);
}

def pr_diff_text(repo: str, pr: PullRequestRef) -> str {
    def build -> str {
        if pr.kind == "worktree" {
            tracked = git_out(
                repo, ["diff", "--no-color", "-U3", "--find-renames", "HEAD"], 60
            );
            return tracked + "\n" + _untracked_patch(repo);
        }
        if pr.kind == "github" {
            info = repo_info(repo);
            try {
                p = subprocess.run(
                    ["gh", "pr", "diff", str(pr.number), "--repo", info.github],
                    capture_output=True,
                    text=True,
                    timeout=60,
                    errors="replace"
                );
                return p.stdout if p.returncode == 0 else "";
            } except Exception {
                return "";
            }
        }
        return git_out(
            repo,
            ["diff", "--no-color", "-U3", "--find-renames", pr.base + "..." + pr.head],
            60
        );
    }
    ttl = 5.0 if pr.kind == "worktree" else 300.0;
    return memo(f"diff:{repo}:{pr.id}", ttl, build);
}

def pr_commits(repo: str, pr: PullRequestRef, limit: int = 60) -> list[CommitInfo] {
    if pr.kind == "worktree" {
        return [];
    }
    head = pr.head;
    base = pr.base;
    if pr.kind == "github" {
        head = github_head_ref(repo, pr);
        base = repo_info(repo).base;
        if not head {
            return [];
        }
    }
    if not safe_ref(head) or not safe_ref(base) {
        return [];
    }
    raw = git_out(
        repo,
        [
            "log",
            f"-n{limit}",
            "--format=%H%x09%an%x09%at%x09%s",
            base + ".." + head
        ]
    ).strip();
    out: list[CommitInfo] = [];
    for row in raw.split("\n") {
        cols = row.split("\t");
        if len(cols) >= 4 {
            out.append(
                CommitInfo(
                    sha=cols[0][:10],
                    author=cols[1],
                    ts=int(cols[2]) if cols[2].isdigit() else 0,
                    subject=cols[3]
                )
            );
        }
    }
    return out;
}

"""A ref we will hand to git: never something git could parse as an option."""
def safe_ref(ref: str) -> bool {
    r = ref.strip();
    return bool(r) and not r.startswith("-") and " " not in r and ".." not in r.replace("...", "");
}

"""Fetch a GitHub pull request's head into refs/diffwalker/pr/<n>, so reviewers read the PR's code."""
def github_head_ref(repo: str, pr: PullRequestRef) -> str {
    if pr.kind != "github" or pr.number <= 0 {
        return "";
    }
    local = f"refs/diffwalker/pr/{pr.number}";
    def fetch -> str {
        for name in ["upstream", "origin"] {
            url = git_out(repo, ["remote", "get-url", name]).strip();
            if not url or not github_slug(url) {
                continue;
            }
            r = run_git(repo, ["fetch", "--quiet", "--no-tags", name, f"+pull/{pr.number}/head:{local}"], 90);
            if r.ok and ref_exists(repo, local) {
                return local;
            }
        }
        return local if ref_exists(repo, local) else "";
    }
    return memo(f"ghref:{repo}:{pr.number}:{pr.updated}", 600.0, fetch);
}

"""The ref whose file contents match the pull request's diff."""
def pr_head_ref(repo: str, pr: PullRequestRef) -> str {
    if pr.kind == "worktree" {
        return "WORKTREE";
    }
    if pr.kind == "github" {
        return github_head_ref(repo, pr) or "WORKTREE";
    }
    return pr.head;
}

def read_text(repo: str, path: str, ref: str = "WORKTREE") -> str {
    clean = path.lstrip("/");
    if not clean or ".." in clean.split("/") {
        return "";
    }
    if not ref or ref == "WORKTREE" {
        full = os.path.realpath(os.path.join(repo, clean));
        if not full.startswith(os.path.realpath(repo) + os.sep) {
            return "";
        }
        try {
            if os.path.getsize(full) > 400000 {
                return "";
            }
            with open(full, "r", errors="replace") as fh {
                return fh.read();
            }
        } except Exception {
            return "";
        }
    }
    if not safe_ref(ref) {
        return "";
    }
    return git_out(repo, ["show", ref + ":" + clean]);
}

"""git grep at a ref (or the worktree); rows are `path:line:text`, whatever was searched."""
def grep(
    repo: str,
    pattern: str,
    glob_pat: str = "",
    limit: int = 60,
    ref: str = "WORKTREE"
) -> list[str] {
    args = ["grep", "-n", "-I", "--no-color", "-E", "-e", pattern];
    tree = ref if ref and ref != "WORKTREE" and safe_ref(ref) else "";
    if tree {
        args.append(tree);
    }
    if glob_pat {
        args = args + ["--", glob_pat];
    }
    rows: list[str] = [];
    for r in git_out(repo, args, 30).split("\n") {
        if not r.strip() {
            continue;
        }
        if tree and r.startswith(tree + ":") {
            r = r[len(tree) + 1:];
        }
        rows.append(r[:300]);
        if len(rows) >= limit {
            break;
        }
    }
    return rows;
}

def file_log(repo: str, path: str, limit: int = 12) -> list[CommitInfo] {
    raw = git_out(
        repo, ["log", f"-n{limit}", "--format=%H%x09%an%x09%at%x09%s", "--", path]
    ).strip();
    out: list[CommitInfo] = [];
    for row in raw.split("\n") {
        cols = row.split("\t");
        if len(cols) >= 4 {
            out.append(
                CommitInfo(
                    sha=cols[0][:10],
                    author=cols[1],
                    ts=int(cols[2]) if cols[2].isdigit() else 0,
                    subject=cols[3]
                )
            );
        }
    }
    return out;
}

def blame_summary(
    repo: str, path: str, start: int, end: int, ref: str = "HEAD"
) -> list[str] {
    rev = ref if ref != "WORKTREE" and safe_ref(ref) else "HEAD";
    raw = git_out(
        repo,
        [
            "blame",
            "--line-porcelain",
            "-L",
            f"{max(1, start)},{max(start, end)}",
            rev,
            "--",
            path
        ]
    );
    out: list[str] = [];
    author = "";
    when = "";
    for line in raw.split("\n") {
        if line.startswith("author ") {
            author = line[7:];
        } elif line.startswith("author-time ") {
            when = time.strftime("%Y-%m-%d", time.localtime(int(line[12:])));
        } elif line.startswith("\t") {
            out.append(f"{author} {when} | {line[1:]}"[:240]);
        }
    }
    return out;
}
