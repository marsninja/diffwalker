glob NL: str = chr(10),
     TICKS: str = chr(96) + chr(96) + chr(96);

def:pub esc(s: str) -> str {
    return rx(rx(rx(rx(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), "\"", "&quot;");
}

def rx(s: any, pattern: str, repl: str) -> str {
    ctor: any = String;
    native: any = ctor.prototype.replace;
    return native.call(s, new(RegExp, pattern, "g"), repl);
}

def inline(s: str) -> str {
    out = esc(s);
    out = rx(out, chr(96) + "([^" + chr(96) + "]+)" + chr(96), "<code>$1</code>");
    out = rx(out, "\\*\\*([^*]+)\\*\\*", "<strong>$1</strong>");
    out = rx(out, "(^|[^*])\\*([^*\\s][^*]*)\\*", "$1<em>$2</em>");
    out = rx(
        out,
        "\\[([^\\]]+)\\]\\(((?:https?://|/)[^)\\s]+)\\)",
        "<a href=\"$2\" target=\"_blank\" rel=\"noreferrer\">$1</a>"
    );
    out = rx(out, "\\b([FRI]-[0-9a-f]{6})\\b", "<code class=\"ref\">$1</code>");
    return out;
}

def is_table_sep(line: str) -> bool {
    t = line.strip();
    return t.startswith("|")
        and "-" in t
        and t.replace("|", "").replace("-", "").replace(":", "").strip() == "";
}

def cells(line: str) -> list[str] {
    t = line.strip();
    if t.startswith("|") {
        t = t[1:];
    }
    if t.endswith("|") {
        t = t[:len(t) - 1];
    }
    return [c.strip() for c in t.split("|")];
}

def:pub md_to_html(text: str) -> str {
    lines = (text or "").split(NL);
    out: list[str] = [];
    para: list[str] = [];
    list_kind = "";
    in_code = False;
    code: list[str] = [];
    i = 0;
    def flush_para {
        if len(para) > 0 {
            out.append("<p>" + "<br/>".join([inline(p) for p in para]) + "</p>");
            para.clear();
        }
    }
    def close_list {
        if list_kind {
            out.append("</" + list_kind + ">");
            list_kind = "";
        }
    }
    while i < len(lines) {
        line = lines[i];
        stripped = line.strip();
        if stripped.startswith(TICKS) {
            if in_code {
                out.append("<pre><code>" + esc(NL.join(code)) + "</code></pre>");
                code.clear();
                in_code = False;
            } else {
                flush_para();
                close_list();
                in_code = True;
            }
            i += 1;
            continue;
        }
        if in_code {
            code.append(line);
            i += 1;
            continue;
        }
        if stripped == "" {
            flush_para();
            close_list();
            i += 1;
            continue;
        }
        if stripped.startswith("#") {
            flush_para();
            close_list();
            level = 0;
            while level < len(stripped) and stripped[level] == "#" {
                level += 1;
            }
            lv = min(4, max(1, level));
            out.append(
                "<h"
                    + str(lv)
                    + ">"
                    + inline(stripped[level:].strip())
                    + "</h"
                    + str(lv)
                    + ">"
            );
            i += 1;
            continue;
        }
        if stripped.startswith("|")
            and i + 1 < len(lines)
            and is_table_sep(lines[i + 1]) {
            flush_para();
            close_list();
            head = cells(stripped);
            rows: list[str] = [];
            j = i + 2;
            while j < len(lines) and lines[j].strip().startswith("|") {
                rows.append(
                    "<tr>"
                        + "".join(
                            ["<td>" + inline(c) + "</td>" for c in cells(lines[j])]
                        )
                        + "</tr>"
                );
                j += 1;
            }
            out.append(
                "<table><thead><tr>"
                    + "".join(["<th>" + inline(h) + "</th>" for h in head])
                    + "</tr></thead><tbody>"
                    + "".join(rows)
                    + "</tbody></table>"
            );
            i = j;
            continue;
        }
        if stripped.startswith("> ") {
            flush_para();
            close_list();
            out.append("<blockquote>" + inline(stripped[2:]) + "</blockquote>");
            i += 1;
            continue;
        }
        bullet = stripped.startswith("- ") or stripped.startswith("* ");
        num = len(stripped) > 2
            and stripped[0] >= "0"
            and stripped[0] <= "9"
            and (". " in stripped[:4]);
        if bullet or num {
            flush_para();
            kind = "ul" if bullet else "ol";
            if list_kind != kind {
                close_list();
                out.append("<" + kind + ">");
                list_kind = kind;
            }
            body = stripped[2:] if bullet else stripped[stripped.index(". ") + 2:];
            out.append("<li>" + inline(body) + "</li>");
            i += 1;
            continue;
        }
        close_list();
        para.append(stripped);
        i += 1;
    }
    if in_code {
        out.append("<pre><code>" + esc(NL.join(code)) + "</code></pre>");
    }
    flush_para();
    close_list();
    return "".join(out);
}

def:pub Markdown(text: str, className: str = "") -> JsxElement {
    <div className={"md text-sm " + className}>{unsafe_html(md_to_html(text))}</div>
}
