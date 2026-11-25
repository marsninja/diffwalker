import from "@jac/runtime" { unsafe_html }

glob NL: str = chr(10),
     TICKS: str = chr(96) + chr(96) + chr(96);

def:pub esc(s: str) -> str;

def rx(s: str, pattern: str, repl: str) -> str;

def inline(s: str) -> str;

def is_table_sep(line: str) -> bool;

def cells(line: str) -> list[str];

def:pub md_to_html(text: str) -> str;

def:pub Markdown(text: str, className: str = "") -> JsxElement;
