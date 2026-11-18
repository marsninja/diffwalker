"""`repo`, `prs`, `hotspots` and `people`: what the analytics say of a repository, printed."""
import json;
import from stdjac.codec { encode }

def bar(value: float, peak: float, width: int = 24) -> str {
    n = int(round(width * value / max(1.0, peak)));
    return "█" * n + dim("░" * (width - n));
}

def run_repo(repo: str, as_json: bool) -> int {
    info = repo_info(repo);
    if not info.is_git {
        warn(red("diffwalker: " + (info.error or "not a git repository")));
        return EXIT_USAGE;
    }
    s = stats(repo);
    langs = languages(repo)[:6];
    if as_json {
        print(
            json.dumps(
                {"repo": encode(info), "stats": encode(s), "languages": encode(langs)}, indent=2
            ),
        );
        return EXIT_OK;
    }
    total = sum([l.size for l in langs]) or 1;
    print(bold(violet(info.name)) + dim("  " + info.path));
    print(
        dim("  branch ")
            + info.branch
            + dim(" @ ")
            + info.head
            + dim("   base ")
            + info.base
            + (dim("   github ") + info.github if info.github else ""),
    );
    print(
        f"  {info.commits} commits · {info.files} files · {info.contributors} contributors · since {info.first_commit[:10]}",
    );
    print(
        f"  last 90 days: {s.commits_90d} commits by {s.authors_90d} authors, "
            + green(f"+{s.additions_90d}")
            + " "
            + red(f"-{s.deletions_90d}"),
    );
    print(
        f"  bus factor {s.bus_factor} · median commit {s.median_commit_size} lines · streak {s.streak_days}d",
    );
    print("");
    for l in langs {
        print(f"  {l.language:<12} {bar(l.size, langs[0].size)} {round(100 * l.size / total):>3}%");
    }
    return EXIT_OK;
}

def run_prs(repo: str, as_json: bool) -> int {
    prs = discover_prs(repo);
    if as_json {
        print(json.dumps(encode(prs), indent=2));
        return EXIT_OK;
    }
    if not prs {
        print(dim("nothing to review: no branches ahead of base, no GitHub PRs, clean worktree"));
        return EXIT_OK;
    }
    print(bold(f"{len(prs)} reviewable pull requests") + dim(f"  in {repo}"));
    for p in prs {
        kind = {"github": "gh", "worktree": "wt", "branch": "br"}.get(p.kind, p.kind);
        size = green(f"+{p.additions}") + " " + red(f"-{p.deletions}");
        print(f"  {violet(p.id):<24} {dim(kind)}  {p.title[:64]:<64}  {size}");
    }
    print(dim("\nreview one:  neojac run cli -- review <id>"));
    return EXIT_OK;
}

def run_hotspots(repo: str, limit: int, as_json: bool) -> int {
    rows = hotspots(repo, limit);
    if as_json {
        print(json.dumps(encode(rows), indent=2));
        return EXIT_OK;
    }
    if not rows {
        print(dim("no history"));
        return EXIT_OK;
    }
    peak = rows[0].score;
    print(bold("hotspots") + dim("  change frequency × size × recency, last 1500 commits"));
    for (i, h) in enumerate(rows) {
        print(
            f"  {i + 1:>2}. {bar(h.score, peak, 18)} {h.path[-58:]:<58} "
                + dim(f"{h.changes} changes, {h.authors} authors"),
        );
    }
    return EXIT_OK;
}

def run_people(repo: str, as_json: bool) -> int {
    people = contributors(repo, 12);
    if as_json {
        print(json.dumps(encode(people), indent=2));
        return EXIT_OK;
    }
    peak = people[0].commits if people else 1;
    for p in people {
        print(f"  {p.name[:22]:<22} {bar(p.commits, peak, 20)} {p.commits:>5}  " + dim(p.top_area));
    }
    return EXIT_OK;
}
