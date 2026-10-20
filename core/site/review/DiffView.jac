import from "lucide-react" {
    Plus,
    FileCode2,
    FilePlus2,
    FileMinus2,
    FileSymlink,
    MessageSquare,
    X,
    ChevronDown,
    ChevronRight
}

def status_icon(status: str) -> any {
    if status == "added" {
        return FilePlus2;
    }
    if status == "deleted" {
        return FileMinus2;
    }
    if status == "renamed" {
        return FileSymlink;
    }
    return FileCode2;
}

def FileRow(f: any, risk: int, count: int, active: bool, onPick: any) -> JsxElement {
    Icon = status_icon(f.status);
    <button
        type="button"
        onClick={lambda { onPick(f.path); }}
        className={"flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-xs transition-colors "
            + (
                "bg-primary/12 text-foreground"
                    if active
                    else "text-muted-foreground hover:bg-muted hover:text-foreground"
            )}
        title={f.path}
    >
        <span
            className="inline-block size-2 shrink-0 rounded-full"
            style={{"background": risk_color(risk)}}
        ></span>
        <Icon className="size-3.5 shrink-0"/>
        <span className="min-w-0 flex-1">
            <span className="block truncate font-mono text-[11.5px]">
                {base_name(f.path)}
            </span>
            <span className="block truncate text-[10px] opacity-70">
                {dir_name(f.path)}
            </span>
        </span>
        {if count > 0 {
            <span
                className="inline-flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 text-[10px] text-primary"
            >
                <MessageSquare className="size-2.5"/>
                {str(count)}
            </span>
        }}
        <span className="shrink-0 tabular text-[10px]">
            <span className="text-[var(--status-good)]">{"+" + str(f.additions)}</span>
            <span className="ml-1 text-[var(--status-critical)]">
                {"−" + str(f.deletions)}
            </span>
        </span>
    </button>
}

def CommentForm(pr_id: str, path: str, line: int, onDone: any) -> JsxElement {
    has title: str = "",
        body: str = "",
        sev: str = "medium",
        busy: bool = False;
    async def submit {
        if not title.strip() {
            return;
        }
        busy = True;
        await add_comment(pr_id, path, line, sev, "correctness", title, body, "");
        busy = False;
        toast("Comment posted on line " + str(line), "success");
        onDone(True);
    }
    <div className="m-2 rounded-xl border border-primary/40 bg-card p-3 font-sans">
        <div className="mb-2 text-xs font-medium">
            {"New comment on line " + str(line)}
        </div>
        <div className="flex gap-2">
            <select
                value={sev}
                onChange={lambda (e: any) { sev = e.target.value; }}
                className="h-8 rounded-md border border-border bg-background px-1.5 text-xs"
                aria-label="Severity"
            >
                {for s in sev_order() {
                    <option key={s} value={s}>{s}</option>
                }}
            </select>
            <input
                value={title}
                autoFocus={True}
                onChange={lambda (e: any) { title = e.target.value; }}
                placeholder="Title"
                className="h-8 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-xs outline-none focus:ring-2 focus:ring-primary/40"
            />
        </div>
        <textarea
            value={body}
            onChange={lambda (e: any) { body = e.target.value; }}
            placeholder="Explain the problem (Markdown)"
            rows={3}
            className="mt-2 w-full rounded-md border border-border bg-background p-2 text-xs outline-none focus:ring-2 focus:ring-primary/40"
        />
        <div className="mt-2 flex justify-end gap-2">
            <button
                type="button"
                onClick={lambda { onDone(False); }}
                className="rounded-md px-2.5 py-1 text-xs hover:bg-muted"
            >
                Cancel
            </button>
            <button
                type="button"
                disabled={busy}
                onClick={submit}
                className="rounded-md bg-primary px-2.5 py-1 text-xs font-medium text-primary-foreground disabled:opacity-50"
            >
                {"Posting…" if busy else "Comment"}
            </button>
        </div>
    </div>
}

def:pub FileDiffView(
    pr_id: str,
    f: any,
    findings: list[any],
    focusLine: int = 0,
    flashKey: str = "",
    onChanged: any = None
) -> JsxElement {
    has composing: int = 0,
        collapsed: bool = False,
        boxW: int = 720,
        box: Ref[HTMLDivElement] = Ref();

    can with entry {
        def measure {
            if box.current {
                el: any = box.current;
                boxW = int(el.clientWidth);
            }
        }
        measure();
        window.addEventListener("resize", measure);
        return lambda { window.removeEventListener("resize", measure); };
    }
    can with [f.path, focusLine, flashKey] entry {
        if focusLine > 0 {
            setTimeout(
                lambda {
                    el: any = document.getElementById("L" + str(focusLine));
                    if el {
                        el.scrollIntoView({"block": "center", "behavior": "smooth"});
                        el.classList.remove("agent-flash");
                        void_ = el.offsetWidth;
                        el.classList.add("agent-flash");
                    }
                },
                120
            );
        }
    }
    by_line: dict[str, list[any]] = {};
    for fd in findings {
        key = str(fd.line);
        if key not in by_line {
            by_line[key] = [];
        }
        by_line[key].append(fd);
    }
    anchored: list[str] = [];
    for h in f.hunks {
        for ln in h.lines {
            if ln.kind != "del" {
                anchored.append(str(ln.new_no));
            }
        }
    }
    orphans = [
        fd
        for fd in findings
        if str(fd.line) not in anchored
    ];
    body: list[any] = [];
    for (hi, h) in enumerate(f.hunks) {
        body.append(
            <tr key={"h" + str(hi)} className="bg-primary/5 text-muted-foreground">
                <td colSpan={3} className="px-3 py-1 text-[11px]">{h.header}</td>
            </tr>
        );
        for (li, ln) in enumerate(h.lines) {
            row_key = str(hi) + "-" + str(li);
            new_no = ln.new_no;
            body.append(
                <tr
                    key={"l" + row_key}
                    id={("L" + str(new_no)) if ln.kind != "del" else ("D" + row_key)}
                    className={"group "
                        + (
                            "diff-add"
                                if ln.kind == "add"
                                else ("diff-del" if ln.kind == "del" else "")
                        )}
                >
                    <td
                        className="gutter w-[1%] select-none whitespace-nowrap px-2 text-right text-[10.5px] text-muted-foreground/70"
                    >
                        {str(ln.old_no) if ln.kind != "add" else ""}
                    </td>
                    <td
                        className="gutter relative w-[1%] select-none whitespace-nowrap px-2 text-right text-[10.5px] text-muted-foreground/70"
                    >
                        {if ln.kind != "del" {
                            <button
                                type="button"
                                title="Comment on this line"
                                onClick={lambda { composing = new_no; }}
                                className="absolute -left-1 top-0.5 hidden size-4 place-items-center rounded bg-primary text-primary-foreground group-hover:grid"
                            >
                                <Plus className="size-3"/>
                            </button>
                        }}
                        {str(new_no) if ln.kind != "del" else ""}
                    </td>
                    <td className="whitespace-pre px-3">
                        <span className="mr-2 select-none text-muted-foreground/60">
                            {"+"
                                if ln.kind == "add"
                                else ("−" if ln.kind == "del" else " ")}
                        </span>
                        {ln.text}
                    </td>
                </tr>
            );
            if ln.kind != "del" and str(new_no) in by_line {
                body.append(
                    <tr key={"f" + row_key}>
                        <td colSpan={3} className="bg-background/60 py-2 font-sans">
                            <div
                                className="sticky left-3 space-y-2"
                                style={{"width": str(min(760, boxW - 24)) + "px"}}
                            >
                                {for fd in by_line[str(new_no)] {
                                    <FindingCard
                                        key={fd.id}
                                        f={fd}
                                        inline={True}
                                        onChanged={onChanged}
                                        flash={focusLine == new_no}
                                    />
                                }}
                            </div>
                        </td>
                    </tr>
                );
            }
            if composing > 0 and ln.kind != "del" and composing == new_no {
                body.append(
                    <tr key={"c" + row_key}>
                        <td colSpan={3} className="bg-background/60">
                            <div
                                className="sticky left-0"
                                style={{"width": str(min(760, boxW)) + "px"}}
                            >
                                <CommentForm
                                    pr_id={pr_id}
                                    path={f.path}
                                    line={new_no}
                                    onDone={lambda (posted: bool) {
                                        composing = 0;
                                        if posted and onChanged {
                                            onChanged();
                                        }
                                    }}
                                />
                            </div>
                        </td>
                    </tr>
                );
            }
        }
    }
    <div className="overflow-hidden rounded-xl border border-border bg-card">
        <button
            type="button"
            onClick={lambda { collapsed = not collapsed; }}
            className="sticky top-0 z-10 flex w-full items-center gap-2 border-b border-border bg-card/95 px-3 py-2 text-left backdrop-blur"
        >
            {(<ChevronRight className="size-4 text-muted-foreground"/>)
                if collapsed
                else (<ChevronDown className="size-4 text-muted-foreground"/>)}
            <span className="min-w-0 truncate font-mono text-xs">{f.path}</span>
            {if f.status != "modified" {
                <span
                    className="rounded bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground"
                >
                    {f.status}
                </span>
            }}
            <span className="ml-auto shrink-0 tabular text-[11px]">
                <span className="text-[var(--status-good)]">
                    {"+" + str(f.additions)}
                </span>
                <span className="ml-1.5 text-[var(--status-critical)]">
                    {"−" + str(f.deletions)}
                </span>
            </span>
        </button>
        {if not collapsed {
            <div ref={box} className="overflow-x-auto thin-scroll">
                {if f.binary {
                    <p className="p-4 text-xs text-muted-foreground">
                        Binary file not shown.
                    </p>
                }}
                {if len(orphans) > 0 {
                    <div className="space-y-2 border-b border-border p-3">
                        {for fd in orphans {
                            <FindingCard
                                key={fd.id}
                                f={fd}
                                inline={False}
                                onChanged={onChanged}
                            />
                        }}
                    </div>
                }}
                <table
                    className="w-full border-collapse font-mono text-[12px] leading-[1.55]"
                >
                    <tbody>{body}</tbody>
                </table>
                {if f.truncated {
                    <p
                        className="border-t border-border p-3 text-xs text-muted-foreground"
                    >
                        Diff truncated for display; the reviewer saw the full patch window.
                    </p>
                }}
            </div>
        }}
    </div>
}

def:pub FileList(
    files: list[any], risks: list[any], findings: list[any], active: str, onPick: any
) -> JsxElement {
    risk_of: dict[str, int] = {};
    for r in risks {
        risk_of[r.path] = r.score;
    }
    counts: dict[str, int] = {};
    for fd in findings {
        if fd.status == "open" {
            counts[fd.path] = (counts[fd.path] or 0) + 1;
        }
    }
    ordered = sorted(
        files, key=lambda (f: any) -> int { return 0 - (risk_of[f.path] or 0); }
    );
    <div className="space-y-0.5">
        {for f in ordered {
            <FileRow
                key={f.path}
                f={f}
                risk={risk_of[f.path] or 0}
                count={counts[f.path] or 0}
                active={f.path == active}
                onPick={onPick}
            />
        }}
    </div>
}
