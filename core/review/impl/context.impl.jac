impl changed_symbols(f: FileDiff) -> list[str] {
    found: list[str] = [];
    def note(name: str) {
        if name and name not in found and name.lower() not in COMMON_NAMES {
            found.append(name);
        }
    }
    for h in f.hunks {
        for pat in SYMBOL_PATTERNS {
            m = re.search(pat, h.header.split("@@")[-1]);
            if m {
                note(m.group(1));
            }
        }
        for ln in h.lines {
            if ln.kind != "add" {
                continue;
            }
            for pat in SYMBOL_PATTERNS {
                m = re.search(pat, ln.text);
                if m {
                    note(m.group(1));
                }
            }
        }
    }
    return found[:MAX_SYMBOLS];
}

impl _callers(repo: str, ref: str, f: FileDiff) -> list[Caller] {
    out: list[Caller] = [];
    seen: set[str] = set();
    for sym in changed_symbols(f) {
        hits = 0;
        for row in grep(repo, "\\b" + sym + "\\b", "", 40, ref) {
            parts = row.split(":", 2);
            if len(parts) < 3 or parts[0] == f.path or not parts[1].isdigit() {
                continue;
            }
            text = parts[2].strip();
            if re.search(SYMBOL_PATTERNS[0], text)
                or text.startswith(("import ", "from ", "#", "//"))
            {
                continue;
            }
            key = parts[0] + ":" + parts[1];
            if key in seen {
                continue;
            }
            seen.add(key);
            out.append(Caller(path=parts[0], line=int(parts[1]), symbol=sym, text=text[:160]));
            hits += 1;
            if hits >= MAX_CALLERS {
                break;
            }
        }
    }
    return out;
}

impl _tests_for(repo: str, ref: str, f: FileDiff) -> list[str] {
    stem = f.path.rsplit("/", 1)[-1].rsplit(".", 1)[0].lower();
    if len(stem) < 3 or file_kind(f.path, f.language) == "test" {
        return [];
    }
    args = ["ls-tree", "-r", "--name-only", ref]
        if ref and ref != "WORKTREE" and safe_ref(ref)
        else ["ls-files"];
    out: list[str] = [];
    for p in git_out(repo, args, 30).split("\n") {
        name = p.rsplit("/", 1)[-1].lower();
        if p and p != f.path and stem in name and file_kind(p, language_of(p)) == "test" {
            out.append(p);
            if len(out) >= MAX_TESTS {
                break;
            }
        }
    }
    return out;
}

impl co_changes(repo: str, path: str, limit: int = 3) -> list[tuple[str, int]] {
    counts: dict[str, int] = {};
    for c in history(repo) {
        paths = [x.path for x in c.files];
        if path not in paths or len(paths) > 24 {
            continue;
        }
        for p in paths {
            if p != path {
                counts[p] = counts.get(p, 0) + 1;
            }
        }
    }
    ranked = sorted(counts.items(), key=lambda (kv: tuple[str, int]) -> int { return 0 - kv[1]; });
    return [kv for kv in ranked if kv[1] >= 2][:limit];
}

impl build_context(repo: str, ref: str, fc: FileChange, f: FileDiff) -> int {
    seen: set[str] = set();
    for c in _callers(repo, ref, f) {
        key = f"{c.path}:{c.line}";
        if key in seen {
            continue;
        }
        seen.add(key);
        seen.add(c.path);
        fc +>:CalledFrom(symbol=c.symbol):+> CodeRef(
            path=c.path, line=c.line, symbol=c.symbol, preview=c.text
        );
    }
    for t in _tests_for(repo, ref, f) {
        if t in seen {
            continue;
        }
        seen.add(t);
        fc +>:TestedBy:+> CodeRef(path=t, line=1, preview="test file");
    }
    for (path, times) in co_changes(repo, f.path, MAX_COUPLED + 2) {
        if path in seen {
            continue;
        }
        seen.add(path);
        fc +>:ChangesWith(times=times):+> CodeRef(
            path=path, line=1, preview=f"changed together {times} times"
        );
    }
    return len([fc --> [?:CodeRef]]);
}

impl ref_excerpt(repo: str, ref: str, cr: CodeRef, span: int = 18) -> str {
    text = read_text(repo, cr.path, ref);
    if not text {
        return "";
    }
    lines = text.split("\n");
    a = max(1, cr.line - span // 2) if cr.line > 1 else 1;
    b = min(len(lines), a + span + (0 if cr.line > 1 else 22));
    return "\n".join([f"{i}: {lines[i - 1]}" for i in range(a, b + 1)]);
}
