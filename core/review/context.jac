import re;

"""The code-relationship neighbourhood of a changed file, built without a model call.

For every changed file we attach CodeRef nodes over typed edges: CalledFrom (places
that use a symbol the change defines or edits), TestedBy (tests for the file), and
ChangesWith (files that historically change in the same commits). The investigator
walker later lets the model pick which of these to read with `visit ... by llm()`.
"""
glob SYMBOL_PATTERNS: list[str] = [
         "^\\s*(?:async\\s+)?def(?::\\w+)?\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:async\\s+)?function\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:abstract\\s+)?class\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:obj|node|edge|walker|enum)(?::\\w+)?\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:const|let)\\s+([A-Za-z_]\\w{2,})\\s*=\\s*(?:async\\s*)?\\(",
         "^\\s*(?:pub\\s+)?fn\\s+([A-Za-z_]\\w{2,})",
         "^\\s*func\\s+(?:\\([^)]*\\)\\s*)?([A-Za-z_]\\w{2,})",
         "^\\s*impl\\s+(?:[A-Za-z_]\\w*\\.)*([A-Za-z_]\\w{2,})"
     ],
     COMMON_NAMES: list[str] = [
         "main",
         "init",
         "run",
         "get",
         "set",
         "test",
         "setup",
         "self",
         "new",
         "start",
         "stop",
         "update",
         "render",
         "handle",
         "postinit"
     ],
     MAX_SYMBOLS: int = 4,
     MAX_CALLERS: int = 3,
     MAX_TESTS: int = 2,
     MAX_COUPLED: int = 3;

"""Names of functions, classes, and archetypes the patch defines or edits inside."""
def changed_symbols(f: FileDiff) -> list[str] {
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

def _callers(repo: str, ref: str, f: FileDiff) -> list[list[any]] {
    out: list[list[any]] = [];
    seen: set[str] = set();
    for sym in changed_symbols(f) {
        hits = 0;
        for row in grep(repo, "\\b" + sym + "\\b", "", 40, ref) {
            parts = row.split(":", 2);
            if len(parts) < 3 or parts[0] == f.path or not parts[1].isdigit() {
                continue;
            }
            text = parts[2].strip();
            if re.search(SYMBOL_PATTERNS[0], text) or text.startswith(("import ", "from ", "#", "//")) {
                continue;
            }
            key = parts[0] + ":" + parts[1];
            if key in seen {
                continue;
            }
            seen.add(key);
            out.append([parts[0], int(parts[1]), sym, text[:160]]);
            hits += 1;
            if hits >= MAX_CALLERS {
                break;
            }
        }
    }
    return out;
}

def _tests_for(repo: str, ref: str, f: FileDiff) -> list[str] {
    stem = f.path.rsplit("/", 1)[-1].rsplit(".", 1)[0].lower();
    if len(stem) < 3 or file_kind(f.path, f.language) == "test" {
        return [];
    }
    args = ["ls-tree", "-r", "--name-only", ref] if ref and ref != "WORKTREE" and safe_ref(ref) else ["ls-files"];
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

"""Files that most often changed in the same commit as `path`, from the mined history."""
def co_changes(repo: str, path: str, limit: int = 3) -> list[list[any]] {
    counts: dict[str, int] = {};
    for c in history(repo) {
        paths = [str(x[0]) for x in c.files];
        if path not in paths or len(paths) > 24 {
            continue;
        }
        for p in paths {
            if p != path {
                counts[p] = counts.get(p, 0) + 1;
            }
        }
    }
    ranked = sorted(counts.items(), key=lambda (kv: any) -> int { return 0 - kv[1]; });
    return [[kv[0], kv[1]] for kv in ranked if kv[1] >= 2][:limit];
}

"""Attach the related-code neighbourhood under a FileChange, one CodeRef per related
location (a test that also co-changes is linked once, as the stronger relation). Returns
how many refs it added."""
def build_context(repo: str, ref: str, fc: FileChange, f: FileDiff) -> int {
    seen: set[str] = set();
    for c in _callers(repo, ref, f) {
        key = f"{c[0]}:{c[1]}";
        if key in seen {
            continue;
        }
        seen.add(key);
        seen.add(c[0]);
        fc +>:CalledFrom(symbol=c[2]):+> CodeRef(path=c[0], line=c[1], symbol=c[2], preview=c[3]);
    }
    for t in _tests_for(repo, ref, f) {
        if t in seen {
            continue;
        }
        seen.add(t);
        fc +>:TestedBy:+> CodeRef(path=t, line=1, preview="test file");
    }
    for pair in co_changes(repo, f.path, MAX_COUPLED + 2) {
        if pair[0] in seen {
            continue;
        }
        seen.add(pair[0]);
        fc +>:ChangesWith(times=pair[1]):+> CodeRef(path=pair[0], line=1, preview=f"changed together {pair[1]} times");
    }
    return len([fc-->][?:CodeRef]);
}

"""Read the code a CodeRef points at: around its line, or the top of the file."""
def ref_excerpt(repo: str, ref: str, cr: CodeRef, span: int = 18) -> str {
    text = read_text(repo, cr.path, ref);
    if not text {
        return "";
    }
    lines = text.split("\n");
    a = max(1, cr.line - span // 2) if cr.line > 1 else 1;
    b = min(len(lines), a + span + (0 if cr.line > 1 else 22));
    return "\n".join([f"{i}: {lines[i - 1]}" for i in range(a, b + 1)]);
}
