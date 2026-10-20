import from "lucide-react" {
    Sparkles,
    X,
    SquarePen,
    ArrowUp,
    Compass,
    GitPullRequest,
    FileCode2,
    Filter,
    Activity,
    Bell,
    FolderGit2,
    List,
    FileDiff,
    Search,
    History,
    Flame,
    Users,
    Network,
    MessageSquarePlus,
    CircleCheck,
    MessageCircle,
    BarChart3,
    Table2,
    Workflow,
    FileDown,
    Github,
    ScanSearch,
    ChevronRight,
    LoaderCircle,
    Brain,
    Terminal,
    Square
}

glob NL: str = chr(10),
     TOOL_META: dict[str, any] = {
         "navigate": ["Navigating", Compass],
         "open_pull_request": ["Opening pull request", GitPullRequest],
         "focus_file": ["Jumping to code", FileCode2],
         "filter_findings": ["Filtering findings", Filter],
         "show_insights": ["Opening analytics", Activity],
         "notify": ["Notifying", Bell],
         "switch_repository": ["Switching repository", FolderGit2],
         "list_pull_requests": ["Scanning pull requests", List],
         "pull_request_details": ["Inspecting pull request", GitPullRequest],
         "file_diff": ["Reading diff", FileDiff],
         "read_file": ["Reading file", FileCode2],
         "search_code": ["Searching code", Search],
         "blame": ["Running blame", History],
         "repo_overview": ["Profiling repository", FolderGit2],
         "hotspot_report": ["Ranking hotspots", Flame],
         "contributor_report": ["Analyzing contributors", Users],
         "ownership_report": ["Mapping ownership", Users],
         "coupling_report": ["Finding coupled files", Network],
         "activity_report": ["Reading activity", Activity],
         "list_findings": ["Listing findings", List],
         "review_pull_request": ["Running full agentic review", ScanSearch],
         "post_comment": ["Posting review comment", MessageSquarePlus],
         "update_finding": ["Updating finding", CircleCheck],
         "reply_to_finding": ["Replying in thread", MessageCircle],
         "render_chart": ["Rendering chart", BarChart3],
         "render_table": ["Rendering table", Table2],
         "render_diagram": ["Drawing diagram", Workflow],
         "export_review": ["Exporting review", FileDown],
         "publish_to_github": ["Preparing GitHub publish", Github]
     };

def tool_detail(tool: str, args: any) -> str {
    if not args {
        return "";
    }
    if tool in ("focus_file", ) {
        return str(args.path or "") + ":" + str(args.line or "");
    }
    if tool in ("read_file", "blame") {
        return str(args.path or "")
            + " "
            + str(args.start_line or "")
            + "-"
            + str(args.end_line or "");
    }
    if tool in ("file_diff", ) {
        return str(args.path or "");
    }
    if tool in ("search_code", ) {
        return str(args.regex or "")
            + ("  in " + args.path_glob if args.path_glob else "");
    }
    if tool in ("navigate", ) {
        return str(args.page or "");
    }
    if tool in ("show_insights", ) {
        return str(args.view or "");
    }
    if tool in ("render_chart", "render_table", "render_diagram") {
        return str(args.title or "");
    }
    if tool in ("post_comment", ) {
        return str(args.path or "")
            + ":"
            + str(args.line or "")
            + " · "
            + str(args.title or "");
    }
    if tool in ("update_finding", ) {
        return str(args.finding_id or "") + " → " + str(args.status or "");
    }
    if args.pr_id {
        return str(args.pr_id);
    }
    return "";
}

def suggestions_for(path: str) -> list[str] {
    if path.startswith("/reviews/") {
        return [
            "Walk me through the riskiest change in this PR and show me the code",
            "Run a full review of this PR focusing on correctness",
            "Chart this PR's findings by severity and pin it",
            "Draw a diagram of how the changed files interact"
        ];
    }
    if path.startswith("/reviews") {
        return [
            "Which open pull request is riskiest? Open it and explain why",
            "Review the smallest branch and summarize what you find",
            "Compare the local branches by size in a chart"
        ];
    }
    if path.startswith("/insights") {
        return [
            "Explain the top 5 hotspots and why they keep changing",
            "Which directories are knowledge silos? Show me the ownership view",
            "Draw a diagram of the most tightly coupled files"
        ];
    }
    if path.startswith("/built") {
        return [
            "How does your review pipeline work? Draw it as a diagram",
            "Show me the hotspot files of this repository on the insights page",
            "What tools do you have, and which ones change my screen?"
        ];
    }
    return [
        "Give me a tour of this repository: health, hotspots, and who owns what",
        "Which open pull request is riskiest? Open it and explain why",
        "Chart commit types over recent months and pin it to the board",
        "Find TODO or FIXME comments added recently and summarize them"
    ];
}

def ToolChip(item: any) -> JsxElement {
    has open: bool = False;
    meta = TOOL_META[item["tool"]] or [item["tool"], Terminal];
    Icon = meta[1];
    detail = tool_detail(item["tool"], item["args"]);
    <div className="rounded-lg border border-border/70 bg-background/60">
        <button
            type="button"
            onClick={lambda { open = not open; }}
            className="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-xs"
        >
            {if item["done"] {
                <Icon className="size-3.5 shrink-0 text-primary"/>
            } else {
                <LoaderCircle className="size-3.5 shrink-0 animate-spin text-primary"/>
            } }
            <span
                className={"shrink-0 font-medium "
                    + ("" if item["done"] else "text-foreground")}
            >
                {meta[0]}
            </span>
            <span
                className="min-w-0 truncate font-mono text-[11px] text-muted-foreground"
            >
                {detail}
            </span>
            <ChevronRight
                className={"ml-auto size-3 shrink-0 text-muted-foreground transition-transform "
                    + ("rotate-90" if open else "")}
            />
        </button>
        {if open {
            <div
                className="border-t border-border/70 px-2.5 py-2 font-mono text-[10.5px] leading-relaxed text-muted-foreground"
            >
                <div className="whitespace-pre-wrap break-all">
                    {"→ " + JSON.stringify(item["args"])}
                </div>
                {if item["result"] {
                    <div
                        className="mt-1.5 max-h-40 overflow-y-auto whitespace-pre-wrap break-words thin-scroll"
                    >
                        {"← " + item["result"]}
                    </div>
                }}
            </div>
        }}
    </div>
}

def AssistantMsg(msg: any, onPin: any) -> JsxElement {
    tools = len(
        [
            it
            for it in msg["items"]
            if it["kind"] == "tool"
        ]
    );
    <div className="flex gap-2.5">
        <span
            className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-gradient-to-br from-violet-500 to-indigo-600 text-white"
        >
            <Sparkles className="size-3.5"/>
        </span>
        <div className="min-w-0 flex-1 space-y-2">
            {if tools > 0 {
                <div
                    className="text-[10px] font-medium uppercase tracking-wider text-muted-foreground"
                >
                    {str(tools) + (" action" if tools == 1 else " actions")}
                </div>
            }}
            {for (i, it) in enumerate(msg["items"]) {
                if it["kind"] == "tool" {
                    <ToolChip key={"t" + str(i)} item={it}/>
                } elif it["kind"] == "card" {
                    <ChartCard
                        key={"c" + str(i)}
                        card={it["card"]}
                        onPin={onPin}
                        compact={True}
                    />
                } elif it["kind"] == "thought" {
                    <div
                        key={"h" + str(i)}
                        className="flex gap-1.5 text-xs italic text-muted-foreground"
                    >
                        <Brain className="mt-0.5 size-3 shrink-0"/>
                        <span className="line-clamp-3">{it["text"]}</span>
                    </div>
                }
            }}
            {if msg["text"] {
                <Markdown
                    text={msg["text"]}
                    className="leading-relaxed text-foreground"
                />
            } elif not msg["done"] {
                <div
                    className="flex items-center gap-1.5 text-xs text-muted-foreground"
                >
                    <span
                        className="pulse-dot inline-block size-1.5 rounded-full bg-primary"
                    ></span>
                    {"Working…" if len(msg["items"]) > 0 else "Thinking…"}
                </div>
            } }
            {if msg["usage"] {
                <div className="text-[10px] text-muted-foreground/70 tabular">
                    {str(msg["usage"]["requests"])
                        + " model calls · "
                        + str(msg["usage"]["tokens"])
                        + " tokens · $"
                        + str(round(msg["usage"]["cost"] * 1000) / 1000)}
                </div>
            }}
        </div>
    </div>
}

def from_transcript(t: any) -> list[any] {
    out: list[any] = [];
    for m in t.transcript or [] {
        if m.role == "user" {
            out.append({"role": "user", "text": m.text});
        } else {
            items: list[any] = [];
            for tr in m.tools or [] {
                parsed: any = {};
                try {
                    parsed = JSON.parse(tr.args or "{}");
                } except Exception {
                    parsed = {};
                }
                items.append(
                    {
                        "kind": "tool",
                        "tool": tr.tool,
                        "args": parsed,
                        "result": tr.result,
                        "done": True,
                        "id": ""
                    }
                );
            }
            for c in m.cards or [] {
                try {
                    items.append({"kind": "card", "card": JSON.parse(c)});
                } except Exception {
                    items = items;
                }
            }
            out.append(
                {
                    "role": "assistant",
                    "text": m.text,
                    "items": items,
                    "done": True,
                    "usage": {"tokens": m.tokens, "cost": m.cost, "requests": len(m.tools or []) + 1} if m.tokens else None
                }
            );
        }
    }
    return out;
}

def:pub CopilotPane(path: str, search: str) -> JsxElement {
    has messages: list[any] = [],
        draft: str = "",
        busy: bool = False,
        tid: str = "",
        remote: str = "",
        endRef: Ref[HTMLDivElement] = Ref(),
        inputRef: Ref[HTMLTextAreaElement] = Ref(),
        live: Ref[any] = Ref(None);

    ws = useWorkspace();
    live.current = {
        "messages": messages,
        "busy": busy,
        "tid": tid,
        "path": path,
        "search": search
    };
    async can with entry {
        first = thread_id();
        tid = first;
        loaded_msgs: list[any] = [];
        try {
            t = await chat_history(first);
            loaded_msgs = from_transcript(t);
        } except Exception {
            loaded_msgs = [];
            first = new_thread();
            tid = first;
        }
        messages = loaded_msgs;
        live.current = {** live.current, "messages": loaded_msgs, "tid": first};
        pending = take_pending_ask();
        if pending {
            await send(pending);
        }
    }
    can with entry {
        off_ask = on_channel(
            "copilot-ask",
            lambda (t: str) { if live.current and live.current["tid"] {
                take_pending_ask();
                send(t);
            }}
        );
        return lambda { off_ask(); };
    }
    can with entry {
        off = on_live(
            lambda (e: any) { if e.kind == "ui"
                and e.session
                and e.session.startswith("cli")
                and e.data {
                remote = "Terminal agent: " + str(e.data.action);
                setTimeout(lambda { remote = ""; }, 4000);
            }}
        );
        return lambda { off(); };
    }
    can with [len(messages), busy] entry {
        if endRef.current {
            endRef.current.scrollIntoView({"block": "end", "behavior": "smooth"});
        }
    }
    async def pin(card: any) {
        await pin_card(card.title, card.kind, card.caption, card.spec);
        toast("Pinned to the insight board", "success");
    }
    async def send(text: str) {
        body = text.strip();
        snap: any = live.current;
        if not body or snap["busy"] {
            return;
        }
        live.current = {** snap, "busy": True};
        busy = True;
        draft = "";
        base = snap["messages"] + [{"role": "user", "text": body}];
        cur: any = {
            "role": "assistant",
            "text": "",
            "items": [],
            "done": False,
            "usage": None
        };
        messages = base + [cur];
        state = snap["path"] + (snap["search"] or "");
        def on_frame(f: any) {
            t = f.t;
            if t == "chunk" {
                cur = {** cur, "text": cur["text"] + f.text};
            } elif t == "thought" and f.text {
                cur = {
                    ** cur,
                    "items": cur["items"] + [{"kind": "thought", "text": f.text}]
                };
            } elif t == "tool_call" {
                cur = {
                    ** cur,
                    "items": cur["items"]
                        + [
                            {
                                "kind": "tool",
                                "tool": f.tool,
                                "args": f.args,
                                "result": "",
                                "done": False,
                                "id": f.id
                            }
                        ]
                };
            } elif t == "tool_result" {
                fresh: list[any] = [];
                for it in cur["items"] {
                    if it["kind"] == "tool" and it["id"] == f.id {
                        fresh.append({** it, "result": f.result, "done": True});
                    } else {
                        fresh.append(it);
                    }
                }
                cur = {** cur, "items": fresh};
            } elif t == "card" {
                cur = {
                    ** cur,
                    "items": cur["items"] + [{"kind": "card", "card": f.card}]
                };
            } elif t == "usage" {
                cur = {
                    ** cur,
                    "usage": {
                        "tokens": f.tokens,
                        "cost": f.cost or 0,
                        "requests": f.requests
                    }
                };
            } elif t == "error" {
                cur = {
                    ** cur,
                    "text": cur["text"] + NL + NL + "_" + str(f.message) + "_"
                };
            } elif t == "done" {
                cur = {** cur, "done": True};
            } else {
                return;
            }
            messages = base + [cur];
        }
        try {
            await read_sse(
                "/function/copilot_stream",
                {
                    "thread_id": snap["tid"],
                    "message": body,
                    "ui_state": state,
                    "session": session_id()
                },
                on_frame
            );
        } except Exception as e {
            cur = {
                ** cur,
                "text": cur["text"] + NL + NL + "_Connection lost: " + str(e) + "_"
            };
        }
        cur = {** cur, "done": True};
        messages = base + [cur];
        live.current = {** live.current, "messages": base + [cur], "busy": False};
        busy = False;
    }
    async def halt {
        snap: any = live.current;
        if snap and snap["busy"] {
            await stop_turn(str(snap["tid"]));
            toast("Stopping after the current step", "info");
        }
    }
    async def reset {
        old_tid: str = str(live.current["tid"]);
        await clear_chat(old_tid);
        fresh = new_thread();
        tid = fresh;
        messages = [];
        live.current = {** live.current, "messages": [], "tid": fresh};
    }
    tips = suggestions_for(path);
    <aside
        className="fixed inset-0 z-50 flex flex-col border-l border-border bg-sidebar lg:static lg:z-auto lg:w-[420px] lg:shrink-0 xl:w-[460px]"
    >
        <div
            className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-3"
        >
            <span
                className="grid size-7 place-items-center rounded-lg bg-gradient-to-br from-violet-500 to-indigo-600 text-white shadow"
            >
                <Sparkles className="size-4"/>
            </span>
            <div className="min-w-0">
                <div className="text-sm font-semibold leading-tight">Copilot</div>
                <div
                    className="truncate text-[11px] leading-tight text-muted-foreground"
                >
                    {((ws.model if ws else "model") + " · drives this UI live")}
                </div>
            </div>
            <div className="ml-auto flex items-center gap-1">
                <button
                    type="button"
                    title="New conversation"
                    onClick={reset}
                    className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
                >
                    <SquarePen className="size-4"/>
                </button>
                <button
                    type="button"
                    title="Close"
                    onClick={lambda { set_pane(False); }}
                    className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
                >
                    <X className="size-4"/>
                </button>
            </div>
        </div>
        {if remote {
            <div
                className="fade-up flex items-center gap-2 border-b border-border bg-primary/10 px-3 py-1.5 text-xs text-primary"
            >
                <Terminal className="size-3.5"/>
                {remote}
            </div>
        }}
        <div className="min-h-0 flex-1 overflow-y-auto px-3 py-4 thin-scroll">
            {if len(messages) == 0 {
                <div className="fade-up">
                    <div className="rounded-2xl border border-border bg-card/70 p-4">
                        <div className="text-sm font-medium">
                            Ask me to review, explain, or explore.
                        </div>
                        <p
                            className="mt-1 text-xs leading-relaxed text-muted-foreground"
                        >
                            I can do anything you can do here: open pull requests, run the full review pipeline, post and resolve comments, chart the repository, and draw diagrams. You will watch me do it.
                        </p>
                    </div>
                    <div className="mt-3 space-y-1.5">
                        {for (i, tip) in enumerate(tips) {
                            <button
                                key={str(i)}
                                type="button"
                                onClick={lambda { send(tip); }}
                                className="flex w-full items-start gap-2 rounded-xl border border-border bg-background/50 px-3 py-2 text-left text-xs text-muted-foreground transition-colors hover:border-primary/40 hover:text-foreground"
                            >
                                <Sparkles
                                    className="mt-0.5 size-3 shrink-0 text-primary"
                                />
                                {tip}
                            </button>
                        }}
                    </div>
                </div>
            }}
            <div className="space-y-5">
                {for (i, m) in enumerate(messages) {
                    if m["role"] == "user" {
                        <div key={str(i)} className="flex justify-end">
                            <div
                                className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-br-md bg-primary px-3.5 py-2 text-sm text-primary-foreground"
                            >
                                {m["text"]}
                            </div>
                        </div>
                    } else {
                        <AssistantMsg key={str(i)} msg={m} onPin={pin}/>
                    }
                }}
            </div>
            <div ref={endRef} className="h-2"></div>
        </div>
        <form
            className="shrink-0 border-t border-border p-3"
            onSubmit={lambda (e: any) {
                e.preventDefault();
                send(draft);
            }}
        >
            <div
                className="flex items-end gap-2 rounded-2xl border border-border bg-background px-3 py-2 focus-within:ring-2 focus-within:ring-primary/40"
            >
                <textarea
                    ref={inputRef}
                    value={draft}
                    rows={1}
                    placeholder={"Copilot is working…"
                        if busy
                        else "Ask Copilot to review, explain, or explore…"}
                    onChange={lambda (e: any) { draft = e.target.value; }}
                    onKeyDown={lambda (e: any) { if e.key == "Enter"
                        and not e.shiftKey {
                        e.preventDefault();
                        send(draft);
                    }}}
                    className="max-h-40 min-h-[24px] flex-1 resize-none bg-transparent text-sm outline-none placeholder:text-muted-foreground"
                />
                {if busy {
                    <button
                        type="button"
                        aria-label="Stop"
                        title="Stop after the current step"
                        onClick={lambda { halt(); }}
                        className="grid size-8 shrink-0 place-items-center rounded-full bg-foreground text-background"
                    >
                        <Square className="size-3.5 fill-current"/>
                    </button>
                } else {
                    <button
                        type="submit"
                        aria-label="Send"
                        disabled={not draft.strip()}
                        className="grid size-8 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground transition-opacity disabled:opacity-40"
                    >
                        <ArrowUp className="size-4"/>
                    </button>
                }}
            </div>
            <div className="mt-1.5 px-1 text-[10px] text-muted-foreground/70">
                Enter to send · Shift+Enter for a new line · actions appear live in the app · long chats are compacted, never cut
            </div>
        </form>
    </aside>
}
