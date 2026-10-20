import math;
import time;
import from datetime { date, timedelta }

obj CommitRec {
    has sha: str = "",
        author: str = "",
        ts: int = 0,
        subject: str = "",
        files: list[list[any]] = [];
}

obj DayCount {
    has day: str = "",
        count: int = 0;
}

obj WeekBucket {
    has week: str = "",
        commits: int = 0,
        additions: int = 0,
        deletions: int = 0;
}

obj KindMonth {
    has month: str = "",
        counts: dict[str, int] = {};
}

obj Hotspot {
    has path: str = "",
        changes: int = 0,
        churn: int = 0,
        authors: int = 0,
        size: int = 0,
        language: str = "",
        last_ts: int = 0,
        score: float = 0.0;
}

obj Contributor {
    has name: str = "",
        commits: int = 0,
        additions: int = 0,
        deletions: int = 0,
        files: int = 0,
        first_ts: int = 0,
        last_ts: int = 0,
        top_area: str = "";
}

obj Ownership {
    has area: str = "",
        owner: str = "",
        share: float = 0.0,
        commits: int = 0,
        authors: int = 0;
}

obj LangSlice {
    has language: str = "",
        bytes: int = 0,
        files: int = 0;
}

obj TreeCell {
    has path: str = "",
        bytes: int = 0,
        files: int = 0,
        language: str = "",
        churn: int = 0;
}

obj CouplingNode {
    has id: str = "",
        changes: int = 0,
        area: str = "";
}

obj CouplingEdge {
    has a: str = "",
        b: str = "",
        weight: int = 0,
        strength: float = 0.0;
}

obj CouplingGraph {
    has nodes: list[CouplingNode] = [],
        edges: list[CouplingEdge] = [];
}

obj RepoStats {
    has commits_90d: int = 0,
        authors_90d: int = 0,
        additions_90d: int = 0,
        deletions_90d: int = 0,
        busiest_day: str = "",
        busiest_count: int = 0,
        streak_days: int = 0,
        median_commit_size: int = 0,
        bus_factor: int = 0,
        test_ratio: float = 0.0;
}

glob HISTORY_DEPTH: int = 1500,
     HIDDEN_PREFIXES: list[str] = ["node_modules/", ".jac/", "dist/", "vendor/"];

def _area(path: str, depth: int = 2) -> str {
    parts = path.split("/");
    if len(parts) <= 1 {
        return "(root)";
    }
    return "/".join(parts[:min(depth, len(parts) - 1)]);
}

def history(repo: str) -> list[CommitRec] {
    sha = head_sha(repo);
    def build -> list[CommitRec] {
        raw = git_out(
            repo,
            [
                "log",
                f"-n{HISTORY_DEPTH}",
                "--no-merges",
                "--numstat",
                "--format=@@%H%x09%an%x09%at%x09%s"
            ],
            120
        );
        out: list[CommitRec] = [];
        cur: CommitRec | None = None;
        for line in raw.split("\n") {
            if line.startswith("@@") {
                cols = line[2:].split("\t");
                if len(cols) < 4 {
                    continue;
                }
                cur = CommitRec(
                    sha=cols[0][:10],
                    author=cols[1],
                    ts=int(cols[2]) if cols[2].isdigit() else 0,
                    subject=cols[3]
                );
                out.append(cur);
            } elif cur and line.strip() {
                cols = line.split("\t");
                if len(cols) == 3 {
                    adds = int(cols[0]) if cols[0].isdigit() else 0;
                    dels = int(cols[1]) if cols[1].isdigit() else 0;
                    path = cols[2];
                    if " => " in path {
                        path = rename_target(path);
                    }
                    cur.files.append([path, adds, dels]);
                }
            }
        }
        return out;
    }
    return memo(f"hist:{repo}:{sha}", 3600.0, build);
}

"""The new path of a numstat rename: `src/{a => b}/f.py` is `src/b/f.py`, `x.py => y.py` is `y.py`."""
def rename_target(path: str) -> str {
    lb = path.find("{");
    rb = path.find("}", lb + 1);
    if lb >= 0 and rb > lb and " => " in path[lb:rb] {
        inner = path[lb + 1:rb].split(" => ")[-1];
        joined = path[:lb] + inner + path[rb + 1:];
        return joined.replace("//", "/").lstrip("/");
    }
    return path.split(" => ")[-1];
}

def sizes(repo: str) -> dict[str, int] {
    sha = head_sha(repo);
    def build -> dict[str, int] {
        out: dict[str, int] = {};
        for line in git_out(repo, ["ls-tree", "-r", "-l", "HEAD"], 60).split("\n") {
            if "\t" not in line {
                continue;
            }
            (meta, path) = line.split("\t", 1);
            cols = meta.split();
            if len(cols) >= 4 and cols[3].isdigit() {
                out[path] = int(cols[3]);
            }
        }
        return out;
    }
    return memo(f"sizes:{repo}:{sha}", 3600.0, build);
}

def activity(repo: str, days: int = 371) -> list[DayCount] {
    counts: dict[str, int] = {};
    cutoff = time.time() - days * 86400;
    raw = git_out(
        repo, ["log", "--no-merges", f"--since={days}.days", "--format=%at"], 60
    );
    for line in raw.split("\n") {
        if line.strip().isdigit() {
            ts = int(line.strip());
            if ts >= cutoff {
                d = date.fromtimestamp(ts).isoformat();
                counts[d] = counts.get(d, 0) + 1;
            }
        }
    }
    today = date.today();
    out: list[DayCount] = [];
    for i in range(days - 1, -1, -1) {
        d = (today - timedelta(days=i)).isoformat();
        out.append(DayCount(day=d, count=counts.get(d, 0)));
    }
    return out;
}

def weekly(repo: str, weeks: int = 26) -> list[WeekBucket] {
    hist = history(repo);
    today = date.today();
    start = today - timedelta(days=today.weekday() + 7 * (weeks - 1));
    buckets: dict[str, WeekBucket] = {};
    order: list[str] = [];
    for i in range(weeks) {
        wk = (start + timedelta(days=7 * i)).isoformat();
        buckets[wk] = WeekBucket(week=wk);
        order.append(wk);
    }
    for c in hist {
        d = date.fromtimestamp(c.ts);
        wk = (d - timedelta(days=d.weekday())).isoformat();
        if wk in buckets {
            b = buckets[wk];
            b.commits += 1;
            b.additions += sum([int(f[1]) for f in c.files]);
            b.deletions += sum([int(f[2]) for f in c.files]);
        }
    }
    return [buckets[w] for w in order];
}

glob KINDS: list[str] = [
         "feat",
         "fix",
         "refactor",
         "docs",
         "test",
         "chore",
         "perf",
         "other"
     ];

def commit_kind(subject: str) -> str {
    s = subject.lower().strip();
    for k in KINDS {
        if s.startswith(k + "(") or s.startswith(k + ":") or s.startswith(k + "!") {
            return k;
        }
    }
    if s.startswith("revert") {
        return "fix";
    }
    if s.startswith("ci") or s.startswith("build") or s.startswith("style") {
        return "chore";
    }
    return "other";
}

def kinds_by_month(repo: str, months: int = 9) -> list[KindMonth] {
    hist = history(repo);
    order: list[str] = [];
    today = date.today();
    y = today.year;
    m = today.month;
    for _ in range(months) {
        order.insert(0, f"{y:04d}-{m:02d}");
        m -= 1;
        if m == 0 {
            m = 12;
            y -= 1;
        }
    }
    table: dict[str, dict[str, int]] = {mo: {k: 0 for k in KINDS} for mo in order};
    for c in hist {
        mo = date.fromtimestamp(c.ts).strftime("%Y-%m");
        if mo in table {
            k = commit_kind(c.subject);
            table[mo][k] = table[mo][k] + 1;
        }
    }
    return [KindMonth(month=mo, counts=table[mo]) for mo in order];
}

def _visible(path: str) -> bool {
    for p in HIDDEN_PREFIXES {
        if path.startswith(p) or ("/" + p) in path {
            return False;
        }
    }
    return not path.endswith(".lock");
}

def hotspots(repo: str, limit: int = 40) -> list[Hotspot] {
    hist = history(repo);
    sz = sizes(repo);
    acc: dict[str, Hotspot] = {};
    authors: dict[str, set] = {};
    for c in hist {
        for f in c.files {
            path = str(f[0]);
            if path not in sz or not _visible(path) {
                continue;
            }
            h = acc.get(path);
            if h is None {
                h = Hotspot(path=path, size=sz[path], language=language_of(path));
                acc[path] = h;
                authors[path] = set();
            }
            h.changes += 1;
            h.churn += int(f[1]) + int(f[2]);
            h.last_ts = max(h.last_ts, c.ts);
            authors[path].add(c.author);
        }
    }
    now = time.time();
    for (path, h) in acc.items() {
        h.authors = len(authors[path]);
        age_days = max(1.0, (now - h.last_ts) / 86400.0);
        recency = 1.0 / (1.0 + age_days / 60.0);
        h.score = round(
            h.changes * math.log2(2 + h.size / 1024.0) * (0.6 + recency)
                + h.authors * 0.5,
            2
        );
    }
    ranked = sorted(
        acc.values(), key=lambda (h: Hotspot) -> float { return 0 - h.score; }
    );
    return ranked[:limit];
}

def contributors(repo: str, limit: int = 20) -> list[Contributor] {
    hist = history(repo);
    acc: dict[str, Contributor] = {};
    files: dict[str, set] = {};
    areas: dict[str, dict[str, int]] = {};
    for c in hist {
        p = acc.get(c.author);
        if p is None {
            p = Contributor(name=c.author, first_ts=c.ts, last_ts=c.ts);
            acc[c.author] = p;
            files[c.author] = set();
            areas[c.author] = {};
        }
        p.commits += 1;
        p.first_ts = min(p.first_ts, c.ts);
        p.last_ts = max(p.last_ts, c.ts);
        for f in c.files {
            p.additions += int(f[1]);
            p.deletions += int(f[2]);
            files[c.author].add(str(f[0]));
            a = _area(str(f[0]));
            areas[c.author][a] = areas[c.author].get(a, 0) + 1;
        }
    }
    for (name, p) in acc.items() {
        p.files = len(files[name]);
        if areas[name] {
            p.top_area = max(
                areas[name].items(), key=lambda (kv: any) -> int { return kv[1]; }
            )[0];
        }
    }
    ranked = sorted(
        acc.values(), key=lambda (c: Contributor) -> int { return 0 - c.commits; }
    );
    return ranked[:limit];
}

def ownership(repo: str, limit: int = 16) -> list[Ownership] {
    hist = history(repo);
    table: dict[str, dict[str, int]] = {};
    for c in hist {
        seen: set = set();
        for f in c.files {
            a = _area(str(f[0]));
            if a in seen or not _visible(str(f[0])) {
                continue;
            }
            seen.add(a);
            row = table.get(a);
            if row is None {
                row = {};
                table[a] = row;
            }
            row[c.author] = row.get(c.author, 0) + 1;
        }
    }
    out: list[Ownership] = [];
    for (area, row) in table.items() {
        total = sum(row.values());
        (owner, n) = max(row.items(), key=lambda (kv: any) -> int { return kv[1]; });
        out.append(
            Ownership(
                area=area,
                owner=owner,
                share=round(n / total, 3),
                commits=total,
                authors=len(row)
            )
        );
    }
    ranked = sorted(out, key=lambda (o: Ownership) -> int { return 0 - o.commits; });
    return ranked[:limit];
}

def languages(repo: str) -> list[LangSlice] {
    acc: dict[str, LangSlice] = {};
    for (path, b) in sizes(repo).items() {
        if not _visible(path) {
            continue;
        }
        lang = language_of(path);
        s = acc.get(lang);
        if s is None {
            s = LangSlice(language=lang);
            acc[lang] = s;
        }
        s.bytes += b;
        s.files += 1;
    }
    return sorted(
        acc.values(), key=lambda (s: LangSlice) -> int { return 0 - s.bytes; }
    );
}

def structure(repo: str, depth: int = 2, limit: int = 60) -> list[TreeCell] {
    churn: dict[str, int] = {};
    for c in history(repo) {
        for f in c.files {
            a = _area(str(f[0]), depth);
            churn[a] = churn.get(a, 0) + int(f[1]) + int(f[2]);
        }
    }
    cells: dict[str, TreeCell] = {};
    langs: dict[str, dict[str, int]] = {};
    for (path, b) in sizes(repo).items() {
        if not _visible(path) {
            continue;
        }
        a = _area(path, depth);
        cell = cells.get(a);
        if cell is None {
            cell = TreeCell(path=a);
            cells[a] = cell;
            langs[a] = {};
        }
        cell.bytes += b;
        cell.files += 1;
        lg = language_of(path);
        langs[a][lg] = langs[a].get(lg, 0) + b;
    }
    for (a, cell) in cells.items() {
        cell.churn = churn.get(a, 0);
        if langs[a] {
            cell.language = max(
                langs[a].items(), key=lambda (kv: any) -> int { return kv[1]; }
            )[0];
        }
    }
    ranked = sorted(
        cells.values(), key=lambda (c: TreeCell) -> int { return 0 - c.bytes; }
    );
    return ranked[:limit];
}

def coupling(repo: str, max_nodes: int = 28, min_weight: int = 3) -> CouplingGraph {
    hist = history(repo);
    sz = sizes(repo);
    changes: dict[str, int] = {};
    for c in hist {
        if len(c.files) > 24 {
            continue;
        }
        for f in c.files {
            p = str(f[0]);
            if p in sz and _visible(p) {
                changes[p] = changes.get(p, 0) + 1;
            }
        }
    }
    top = [
        kv[0]
        for kv in sorted(
            changes.items(), key=lambda (kv: any) -> int { return 0 - kv[1]; }
        )[:120]
    ];
    keep = set(top);
    pairs: dict[str, int] = {};
    for c in hist {
        if len(c.files) > 24 {
            continue;
        }
        touched = sorted(
            set(
                [
                    str(f[0])
                    for f in c.files
                    if str(f[0]) in keep
                ]
            )
        );
        for i in range(len(touched)) {
            for j in range(i + 1, len(touched)) {
                key = touched[i] + "|" + touched[j];
                pairs[key] = pairs.get(key, 0) + 1;
            }
        }
    }
    edges: list[CouplingEdge] = [];
    for (key, w) in pairs.items() {
        if w < min_weight {
            continue;
        }
        (a, b) = key.split("|");
        strength = w / max(1, min(changes[a], changes[b]));
        edges.append(CouplingEdge(a=a, b=b, weight=w, strength=round(strength, 3)));
    }
    edges = sorted(
        edges,
        key=lambda (e: CouplingEdge) -> float { return 0
            - e.weight * (0.5 + e.strength); }
    );
    chosen: list[str] = [];
    picked: list[CouplingEdge] = [];
    for e in edges {
        fresh = [
            n
            for n in [e.a, e.b]
            if n not in chosen
        ];
        if len(chosen) + len(fresh) > max_nodes {
            continue;
        }
        chosen = chosen + fresh;
        picked.append(e);
        if len(picked) >= 60 {
            break;
        }
    }
    return CouplingGraph(
        nodes=[
            CouplingNode(id=n, changes=changes[n], area=_area(n, 2)) for n in chosen
        ],
        edges=picked
    );
}

def stats(repo: str) -> RepoStats {
    hist = history(repo);
    cutoff = time.time() - 90 * 86400;
    recent = [
        c
        for c in hist
        if c.ts >= cutoff
    ];
    out = RepoStats(
        commits_90d=len(recent),
        authors_90d=len(set([c.author for c in recent])),
        additions_90d=sum([int(f[1]) for c in recent for f in c.files]),
        deletions_90d=sum([int(f[2]) for c in recent for f in c.files])
    );
    days = activity(repo, 90);
    best = DayCount();
    for d in days {
        if d.count > best.count {
            best = d;
        }
    }
    out.busiest_day = best.day;
    out.busiest_count = best.count;
    streak = 0;
    for d in reversed(days) {
        if d.count > 0 {
            streak += 1;
        } elif streak > 0 {
            break;
        }
    }
    out.streak_days = streak;
    sizes_list = sorted([sum([int(f[1]) + int(f[2]) for f in c.files]) for c in hist]);
    out.median_commit_size = sizes_list[len(sizes_list) // 2] if sizes_list else 0;
    people = contributors(repo, 200);
    total = sum([p.commits for p in people]);
    running = 0;
    bus = 0;
    for p in people {
        running += p.commits;
        bus += 1;
        if total and running / total >= 0.5 {
            break;
        }
    }
    out.bus_factor = bus;
    paths = list(sizes(repo).keys());
    tests = len(
        [
            p
            for p in paths
            if "test" in p.lower()
        ]
    );
    out.test_ratio = round(tests / max(1, len(paths)), 3);
    return out;
}

def warm(repo: str) {
    _ = history(repo);
    _ = sizes(repo);
    _ = repo_info(repo);
}
