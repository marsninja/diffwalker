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
    "dockerfile": "Docker",
};

def language_of(path: str) -> str;

def _hunk_numbers(header: str) -> list[int];

def _strip_prefix(p: str) -> str;

glob _ESCAPES: dict[str, int] = {
    "n": 10,
    "t": 9,
    "r": 13,
    "\"": 34,
    "\\": 92,
    "a": 7,
    "b": 8,
    "f": 12,
    "v": 11,
};
def unquote_path(raw: str) -> str;
def _header_paths(rest: str) -> list[str];

def parse_unified_diff(text: str, max_lines_per_file: int = 1500) -> list[FileDiff];

def render_file_patch(f: FileDiff, max_chars: int = 9000) -> str;

def changed_new_lines(f: FileDiff) -> list[int];
def commentable_lines(f: FileDiff) -> list[int];
