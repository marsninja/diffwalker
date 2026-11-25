impl new_id(prefix: str) -> str {
    return prefix + "-" + uuid.uuid4().hex[:8];
}

impl now -> float {
    return time.time();
}

impl workspace -> Workspace {
    with _making {
        found = [root --> [?:Workspace]];
        if found {
            return found[0];
        }
        ws = Workspace();
        root ++> ws;
        return ws;
    }
}

impl repo_node(repo_path: str) -> Repo | None {
    found = [root ->:HasRepo:->][?:Repo, path == repo_path];
    return found[0] if found else None;
}

impl ensure_repo(path: str, name: str) -> Repo {
    with _making {
        r = repo_node(path);
        if r is not None {
            return r;
        }
        fresh = Repo(path=path, name=name, added_at=now());
        root +>:HasRepo:+> fresh;
        return fresh;
    }
}

impl pr_node(repo: Repo, pr_id: str) -> PullRequest | None {
    found = [repo ->:HasPR:->][?:PullRequest, id == pr_id];
    return found[0] if found else None;
}

impl ensure_pr(
    repo: Repo,
    pr_id: str,
    kind: str,
    title: str,
    head: str,
    base: str,
    author: str,
    url: str,
    number: int,
) -> PullRequest {
    with _making {
        found = pr_node(repo, pr_id);
        p = found if found is not None else PullRequest(id=pr_id);
        if found is None {
            repo +>:HasPR:+> p;
        }
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

impl pr_reviews(pr: PullRequest) -> list[Review] {
    reviews = [pr ->:HasReview:->][?:Review];
    return sorted(reviews, key=lambda (r: Review) -> float { return 0 - r.started; });
}

impl review_files(review: Review) -> list[FileChange] {
    files = [review ->:Covers:->][?:FileChange];
    return sorted(files, key=lambda (f: FileChange) -> int { return 0 - f.risk; });
}

impl review_findings(review: Review) -> list[Finding] {
    return [review ->:Covers:-> ->:Raised:->][?:Finding];
}

impl file_change(review: Review, file_path: str) -> FileChange | None {
    found = [review ->:Covers:->][?:FileChange, path == file_path];
    return found[0] if found else None;
}

impl review_of(pr: PullRequest, status: str = "done") -> Review | None {
    for rv in pr_reviews(pr) {
        if not status or rv.status == status {
            return rv;
        }
    }
    return None;
}

impl find_review(review_id: str) -> Review | None {
    found = [root ->:HasRepo:-> ->:HasPR:-> ->:HasReview:->][?:Review, id == review_id];
    return found[0] if found else None;
}

impl find_finding(finding_id: str) -> Finding | None {
    found = [root ->:HasRepo:-> ->:HasPR:-> ->:HasReview:-> ->:Covers:-> ->:Raised:->][?:Finding, id
        == finding_id];
    return found[0] if found else None;
}

impl review_pr(review: Review) -> PullRequest | None {
    found = [review <-:HasReview:<-][?:PullRequest];
    return found[0] if found else None;
}

impl finding_review(f: Finding) -> Review | None {
    found = [f <-:Raised:<- <-:Covers:<-][?:Review];
    return found[0] if found else None;
}

impl repo_insights(repo: Repo) -> list[Insight] {
    found = [repo ->:Pinned:->][?:Insight];
    return sorted(found, key=lambda (i: Insight) -> float { return 0 - i.created; });
}

impl chat_thread(thread_id: str) -> ChatThread {
    with _making {
        found = [root ->:Talked:->][?:ChatThread, id == thread_id];
        if found {
            return found[0];
        }
        t = ChatThread(id=thread_id, created=now(), updated=now());
        root +>:Talked:+> t;
        return t;
    }
}

impl refresh_pr_rollup(pr: PullRequest) {
    latest = review_of(pr, "done");
    if latest is None {
        return;
    }
    pr.last_review = latest.id;
    pr.verdict = latest.verdict;
    pr.risk = latest.risk;
    pr.open_findings = len([f for f in review_findings(latest) if f.status == "open"]);
}

impl touch_rollup(f: Finding) {
    rv = finding_review(f);
    if rv {
        pr = review_pr(rv);
        if pr {
            refresh_pr_rollup(pr);
        }
    }
}

impl CollectFindings.at_repo with Repo entry {
    visit [here ->:HasPR:->];
}

impl CollectFindings.at_pr with PullRequest entry {
    done = [rv for rv in pr_reviews(here) if rv.status == "done"];
    visit done[:1] if self.latest_only else done;
}

impl CollectFindings.at_review with Review entry {
    visit [here ->:Covers:->];
}

impl CollectFindings.at_file with FileChange entry {
    visit [here ->:Raised:->];
}

impl CollectFindings.at_finding with Finding entry {
    if not self.status or here.status == self.status {
        self.found.append(here);
    }
}

impl repo_findings(repo: Repo, status: str = "", latest_only: bool = True) -> list[Finding] {
    w = repo spawn CollectFindings(status=status, latest_only=latest_only);
    return w.found;
}
