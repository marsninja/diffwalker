obj DiffLine {
    has kind: str = "ctx",
        old_no: int = 0,
        new_no: int = 0,
        text: str = "";
}

obj Hunk {
    has header: str = "",
        old_start: int = 0,
        old_len: int = 0,
        new_start: int = 0,
        new_len: int = 0,
        lines: list[DiffLine] = [];
}

obj FileDiff {
    has path: str = "",
        old_path: str = "",
        status: str = "modified",
        additions: int = 0,
        deletions: int = 0,
        binary: bool = False,
        language: str = "",
        hunks: list[Hunk] = [],
        truncated: bool = False;
}

glob LANGUAGES: dict[str, str] = {
         "jac": "Jac",
         "py": "Python",
         "pyi": "Python",
         "ts": "TypeScript",
         "tsx": "TypeScript",
         "js": "JavaScript",
         "jsx": "JavaScript",
         "mjs": "JavaScript",
         "cjs": "JavaScript",
         "rs": "Rust",
         "go": "Go",
         "c": "C",
         "h": "C",
         "cc": "C++",
         "cpp": "C++",
         "hpp": "C++",
         "zig": "Zig",
         "java": "Java",
         "kt": "Kotlin",
         "swift": "Swift",
         "rb": "Ruby",
         "php": "PHP",
         "cs": "C#",
         "md": "Markdown",
         "mdx": "Markdown",
         "rst": "Docs",
         "txt": "Text",
         "json": "JSON",
         "toml": "TOML",
         "yaml": "YAML",
         "yml": "YAML",
         "css": "CSS",
         "scss": "CSS",
         "html": "HTML",
         "sh": "Shell",
         "bash": "Shell",
         "zsh": "Shell",
         "sql": "SQL",
         "lock": "Lockfile",
         "svg": "SVG",
         "ll": "LLVM IR",
         "proto": "Protobuf",
         "dockerfile": "Docker"
     };

def language_of(path: str) -> str {
    name = path.rsplit("/", 1)[-1].lower();
    if name == "dockerfile" or name.startswith("dockerfile.") {
        return "Docker";
    }
    if name in ("makefile", "gnumakefile") {
        return "Make";
    }
    if "." not in name {
        return "Other";
    }
    ext = name.rsplit(".", 1)[-1];
    return LANGUAGES.get(ext, "Other");
}

def _hunk_numbers(header: str) -> list[int] {
    out: list[int] = [0, 0, 0, 0];
    try {
        body = header.split("@@")[1].strip();
        parts = body.split(" ");
        old = parts[0][1:].split(",");
        new = parts[1][1:].split(",");
        out = [
            int(old[0]),
            int(old[1]) if len(old) > 1 else 1,
            int(new[0]),
            int(new[1]) if len(new) > 1 else 1
        ];
    } except Exception {
        out = [0, 0, 0, 0];
    }
    return out;
}

def _strip_prefix(p: str) -> str {
    if p.startswith("a/") or p.startswith("b/") {
        return p[2:];
    }
    return p;
}

glob _ESCAPES: dict[str, int] = {
         "n": 10,
         "t": 9,
         "r": 13,
         "\"": 34,
         "\\": 92,
         "a": 7,
         "b": 8,
         "f": 12,
         "v": 11
     };

"""Undo git's path quoting: a C-quoted string with octal escapes for non-ASCII bytes."""
def unquote_path(raw: str) -> str {
    p = raw.rstrip("\t");
    if len(p) < 2 or not p.startswith("\"") or not p.endswith("\"") {
        return p;
    }
    body = p[1:-1];
    out = bytearray();
    i = 0;
    while i < len(body) {
        ch = body[i];
        if ch != "\\" or i + 1 >= len(body) {
            out.extend(ch.encode("utf-8"));
            i += 1;
            continue;
        }
        nxt = body[i + 1];
        if nxt in "01234567" and i + 3 < len(body) + 1 {
            digits = body[i + 1:i + 4];
            try {
                out.append(int(digits, 8) & 255);
                i += 4;
                continue;
            } except ValueError {
                out.extend(nxt.encode("utf-8"));
                i += 2;
                continue;
            }
        }
        out.append(_ESCAPES.get(nxt, ord(nxt)));
        i += 2;
    }
    return out.decode("utf-8", errors="replace");
}

"""Paths from a `diff --git a/x b/y` header; only a fallback, since ---/+++/rename lines win."""
def _header_paths(rest: str) -> list[str] {
    if rest.startswith("\"") {
        end = rest.find("\" ", 1);
        while end > 0 and rest[end - 1] == "\\" {
            end = rest.find("\" ", end + 1);
        }
        if end > 0 {
            return [
                _strip_prefix(unquote_path(rest[:end + 1])),
                _strip_prefix(unquote_path(rest[end + 2:]))
            ];
        }
    }
    half = len(rest) // 2;
    if len(rest) % 2 == 1 and rest[half] == " " and rest[2:half] == rest[half + 3:] {
        same = _strip_prefix(rest[:half]);
        return [same, same];
    }
    parts = rest.split(" b/");
    if len(parts) > 1 {
        return [_strip_prefix(parts[0]), " b/".join(parts[1:])];
    }
    return [rest, rest];
}

def parse_unified_diff(text: str, max_lines_per_file: int = 1500) -> list[FileDiff] {
    files: list[FileDiff] = [];
    cur: FileDiff | None = None;
    hunk: Hunk | None = None;
    old_no = 0;
    new_no = 0;
    old_left = 0;
    new_left = 0;
    for raw in text.split("\n") {
        if raw.startswith("diff --git ") {
            names = _header_paths(raw[11:]);
            cur = FileDiff(path=names[1], old_path=names[0], language=language_of(names[1]));
            files.append(cur);
            hunk = None;
            continue;
        }
        if cur is None {
            continue;
        }
        in_hunk = hunk is not None and (old_left > 0 or new_left > 0);
        if not in_hunk {
            if raw.startswith("new file mode") {
                cur.status = "added";
                continue;
            } elif raw.startswith("deleted file mode") {
                cur.status = "deleted";
                continue;
            } elif raw.startswith("rename from ") {
                cur.status = "renamed";
                cur.old_path = unquote_path(raw[12:]);
                continue;
            } elif raw.startswith("rename to ") {
                cur.path = unquote_path(raw[10:]);
                cur.language = language_of(cur.path);
                continue;
            } elif raw.startswith("Binary files ") or raw.startswith("GIT binary patch") {
                cur.binary = True;
                continue;
            } elif raw.startswith("--- ") {
                continue;
            } elif raw.startswith("+++ ") {
                target = unquote_path(raw[4:]);
                if target != "/dev/null" {
                    cur.path = _strip_prefix(target);
                    cur.language = language_of(cur.path);
                }
                continue;
            }
        }
        if raw.startswith("@@") and not in_hunk {
            nums = _hunk_numbers(raw);
            hunk = Hunk(
                header=raw,
                old_start=nums[0],
                old_len=nums[1],
                new_start=nums[2],
                new_len=nums[3]
            );
            old_no = nums[0];
            new_no = nums[2];
            old_left = nums[1];
            new_left = nums[3];
            cur.hunks.append(hunk);
            continue;
        }
        if hunk is None or raw.startswith("\\") {
            continue;
        }
        if not in_hunk {
            continue;
        }
        if raw == "" {
            raw = " ";
        }
        shown = sum([len(h.lines) for h in cur.hunks]);
        if raw.startswith("+") {
            new_left -= 1;
            cur.additions += 1;
            if shown < max_lines_per_file {
                hunk.lines.append(DiffLine(kind="add", new_no=new_no, text=raw[1:]));
            } else {
                cur.truncated = True;
            }
            new_no += 1;
        } elif raw.startswith("-") {
            old_left -= 1;
            cur.deletions += 1;
            if shown < max_lines_per_file {
                hunk.lines.append(DiffLine(kind="del", old_no=old_no, text=raw[1:]));
            } else {
                cur.truncated = True;
            }
            old_no += 1;
        } elif raw.startswith(" ") {
            old_left -= 1;
            new_left -= 1;
            if shown < max_lines_per_file {
                hunk.lines.append(
                    DiffLine(kind="ctx", old_no=old_no, new_no=new_no, text=raw[1:])
                );
            }
            old_no += 1;
            new_no += 1;
        }
    }
    return files;
}

def render_file_patch(f: FileDiff, max_chars: int = 9000) -> str {
    out: list[str] = [f"--- {f.old_path}", f"+++ {f.path}"];
    used = 0;
    for h in f.hunks {
        out.append(h.header);
        for ln in h.lines {
            if ln.kind == "add" {
                row = f"+{ln.new_no:>5} | {ln.text}";
            } elif ln.kind == "del" {
                row = f"-{ln.old_no:>5} | {ln.text}";
            } else {
                row = f" {ln.new_no:>5} | {ln.text}";
            }
            used += len(row) + 1;
            if used > max_chars {
                out.append("... (patch truncated)");
                return "\n".join(out);
            }
            out.append(row);
        }
    }
    return "\n".join(out);
}

def changed_new_lines(f: FileDiff) -> list[int] {
    return [
        ln.new_no for h in f.hunks
        for ln in h.lines
        if ln.kind == "add"
    ];
}

"""New-side line numbers a comment may anchor to: added lines and the context shown around them."""
def commentable_lines(f: FileDiff) -> list[int] {
    return [
        ln.new_no for h in f.hunks
        for ln in h.lines
        if ln.kind != "del" and ln.new_no > 0
    ];
}
