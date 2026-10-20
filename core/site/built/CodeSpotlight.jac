import from "lucide-react" { FileCode2 }

glob KEYWORDS: list[str] = [
         "def",
         "can",
         "walker",
         "node",
         "edge",
         "obj",
         "has",
         "by",
         "sem",
         "glob",
         "import",
         "from",
         "return",
         "if",
         "elif",
         "else",
         "for",
         "in",
         "with",
         "entry",
         "exit",
         "visit",
         "report",
         "spawn",
         "async",
         "await",
         "lambda",
         "impl",
         "enum",
         "try",
         "except",
         "finally",
         "while",
         "not",
         "and",
         "or",
         "is",
         "here",
         "self",
         "root",
         "flow",
         "wait",
         "yield",
         "True",
         "False",
         "None"
     ],
     BUILTIN_TYPES: list[str] = [
         "str",
         "int",
         "float",
         "bool",
         "list",
         "dict",
         "any",
         "JsxElement",
         "JsxPage",
         "Generator"
     ];

def is_word(ch: str) -> bool {
    return (ch >= "a" and ch <= "z")
        or (ch >= "A" and ch <= "Z")
        or (ch >= "0" and ch <= "9")
        or ch == "_"
        or ch == ":";
}

def esc(s: str) -> str {
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
}

def:pub highlight(line: str) -> str {
    out: list[str] = [];
    i = 0;
    n = len(line);
    while i < n {
        ch = line[i];
        if ch == "#" {
            out.append(
                "<span style=\"color:var(--ink-muted);font-style:italic\">"
                    + esc(line[i:])
                    + "</span>"
            );
            break;
        }
        if ch == "\"" or ch == "'" {
            j = i + 1;
            while j < n and line[j] != ch {
                if line[j] == "\\" {
                    j += 1;
                }
                j += 1;
            }
            out.append(
                "<span style=\"color:var(--series-3)\">"
                    + esc(line[i:j + 1])
                    + "</span>"
            );
            i = j + 1;
            continue;
        }
        if is_word(ch) {
            j = i;
            while j < n and is_word(line[j]) {
                j += 1;
            }
            word = line[i:j];
            base = word.split(":")[0];
            if base in KEYWORDS {
                out.append(
                    "<span style=\"color:var(--series-7);font-weight:500\">"
                        + esc(word)
                        + "</span>"
                );
            } elif word in BUILTIN_TYPES {
                out.append(
                    "<span style=\"color:var(--series-4)\">" + esc(word) + "</span>"
                );
            } elif ch >= "0" and ch <= "9" {
                out.append(
                    "<span style=\"color:var(--series-2)\">" + esc(word) + "</span>"
                );
            } elif j < n and line[j] == "(" {
                out.append(
                    "<span style=\"color:var(--series-1)\">" + esc(word) + "</span>"
                );
            } elif ch >= "A" and ch <= "Z" {
                out.append(
                    "<span style=\"color:var(--series-5)\">" + esc(word) + "</span>"
                );
            } else {
                out.append(esc(word));
            }
            i = j;
            continue;
        }
        if ch == "-" and i + 2 < n and line[i + 1] == "-" and line[i + 2] == ">" {
            out.append(
                "<span style=\"color:var(--series-2);font-weight:600\">--&gt;</span>"
            );
            i += 3;
            continue;
        }
        out.append(esc(ch));
        i += 1;
    }
    return "".join(out);
}

def:pub CodeSpotlight(
    path: str, needle: str = "", before: int = 2, after: int = 14, title: str = ""
) -> JsxElement {
    has snip: any = None;
    async can with [path, needle] entry {
        snip = await source_snippet(path, needle, before, after);
    }
    <div
        className="overflow-hidden rounded-xl border border-border bg-[var(--chart-surface)] shadow-sm"
    >
        <div className="flex items-center gap-2 border-b border-border px-3 py-2">
            <span className="flex gap-1">
                <span className="size-2.5 rounded-full bg-[#ff5f57]"></span>
                <span className="size-2.5 rounded-full bg-[#febc2e]"></span>
                <span className="size-2.5 rounded-full bg-[#28c840]"></span>
            </span>
            <FileCode2 className="ml-1 size-3.5 text-muted-foreground"/>
            <span className="truncate font-mono text-[11px] text-muted-foreground">
                {path}
            </span>
            {if title {
                <span
                    className="ml-auto shrink-0 rounded-full bg-primary/15 px-2 py-0.5 text-[10px] text-primary"
                >
                    {title}
                </span>
            }}
        </div>
        {if not snip {
            <div className="shimmer h-48"></div>
        } else {
            <div className="max-h-[420px] overflow-auto py-2 thin-scroll">
                {for (i, ln) in enumerate(snip.lines) {
                    <div
                        key={str(i)}
                        className="flex font-mono text-[11.5px] leading-[1.6]"
                    >
                        <span
                            className="w-10 shrink-0 select-none pr-3 text-right text-muted-foreground/50"
                        >
                            {str(snip.start + i)}
                        </span>
                        <span className="whitespace-pre pr-4">
                            {unsafe_html(highlight(ln) or " ")}
                        </span>
                    </div>
                }}
            </div>
        } }
    </div>
}
