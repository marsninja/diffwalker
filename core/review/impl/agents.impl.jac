impl Reviewer.read_file(path: str, start_line: int, end_line: int) -> str {
    text = read_text(self.repo, path, self.ref);
    if not text {
        return f"(no file {path} at {self.ref})";
    }
    lines = text.split("\n");
    a = max(1, start_line);
    b = min(len(lines), max(a, end_line), a + 200);
    return f"{path} ({len(lines)} lines)\n"
        + "\n".join([f"{i}: {lines[i - 1]}" for i in range(a, b + 1)]);
}

impl Reviewer.search_code(regex: str, path_glob: str) -> str {
    rows = grep(self.repo, regex, path_glob, 40, self.ref);
    return "\n".join(rows) if rows else "(no matches)";
}

impl Reviewer.file_history(path: str) -> str {
    return "\n".join([f"{c.sha} {c.author}: {c.subject}" for c in file_log(self.repo, path, 10)])
        or "(no history)";
}
