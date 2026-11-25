impl Message.having(
    text: str | None = None,
    items: list[Item] | None = None,
    done: bool | None = None,
    usage: Usage | None = None,
) -> Message {
    return Message(
        role=self.role,
        text=self.text if text is None else text,
        items=self.items if items is None else items,
        done=self.done if done is None else done,
        usage=self.usage if usage is None else usage,
    );
}

impl tool_args(text: str) -> any {
    try {
        return JSON.parse(text or "{}");
    } except Exception {
        return JSON.parse("{}");
    }
}

impl tool_detail(tool: str, args: any) -> str {
    if not args {
        return "";
    }
    if tool in ("focus_file",) {
        return str(args["path"] or "") + ":" + str(args["line"] or "");
    }
    if tool in ("read_file", "blame") {
        return str(args["path"] or "")
            + " "
            + str(args["start_line"] or "")
            + "-"
            + str(args["end_line"] or "");
    }
    if tool in ("file_diff",) {
        return str(args["path"] or "");
    }
    if tool in ("search_code",) {
        return str(args["regex"] or "")
            + ("  in " + args["path_glob"] if args["path_glob"] else "");
    }
    if tool in ("navigate",) {
        return str(args["page"] or "");
    }
    if tool in ("show_insights",) {
        return str(args["view"] or "");
    }
    if tool in ("render_chart", "render_table", "render_diagram") {
        return str(args["title"] or "");
    }
    if tool in ("post_comment",) {
        return str(args["path"] or "")
            + ":"
            + str(args["line"] or "")
            + " · "
            + str(args["title"] or "");
    }
    if tool in ("update_finding",) {
        return str(args["finding_id"] or "") + " → " + str(args["status"] or "");
    }
    if args["pr_id"] {
        return str(args["pr_id"]);
    }
    return "";
}

impl suggestions_for(path: str) -> list[str] {
    if path.startswith("/reviews/") {
        return [
            "Walk me through the riskiest change in this PR and show me the code",
            "Run a full review of this PR focusing on correctness",
            "Chart this PR's findings by severity and pin it",
            "Draw a diagram of how the changed files interact",
        ];
    }
    if path.startswith("/reviews") {
        return [
            "Which open pull request is riskiest? Open it and explain why",
            "Review the smallest branch and summarize what you find",
            "Compare the local branches by size in a chart",
        ];
    }
    if path.startswith("/insights") {
        return [
            "Explain the top 5 hotspots and why they keep changing",
            "Which directories are knowledge silos? Show me the ownership view",
            "Draw a diagram of the most tightly coupled files",
        ];
    }
    if path.startswith("/built") {
        return [
            "How does your review pipeline work? Draw it as a diagram",
            "Show me the hotspot files of this repository on the insights page",
            "What tools do you have, and which ones change my screen?",
        ];
    }
    return [
        "Give me a tour of this repository: health, hotspots, and who owns what",
        "Which open pull request is riskiest? Open it and explain why",
        "Chart commit types over recent months and pin it to the board",
        "Find TODO or FIXME comments added recently and summarize them",
    ];
}

impl ToolChip(item: Item) -> JsxElement {
    has open: bool = False;
    meta = TOOL_META.get(item.tool) or ToolMeta(label=item.tool, icon=Terminal);
    Icon = meta.icon;
    detail = tool_detail(item.tool, item.args);
    return <div className="rounded-lg border border-border/70 bg-background/60">
        <button
            type="button"
            onClick={lambda { open = not open; }}
            className="flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-xs"
        >
            {
                if item.done {
                    <Icon className="size-3.5 shrink-0 text-primary" />
                } else {
                    <LoaderCircle className="size-3.5 shrink-0 animate-spin text-primary" />
                }
            }
            <span className={"shrink-0 font-medium " + ("" if item.done else "text-foreground")}>
                {meta.label}
            </span>
            <span className="min-w-0 truncate font-mono text-[11px] text-muted-foreground">
                {detail}
            </span>
            <ChevronRight
                className={"ml-auto size-3 shrink-0 text-muted-foreground transition-transform " + ("rotate-90" if open else "")}
            />
        </button>
        {
            if open {
                <div
                    className="border-t border-border/70 px-2.5 py-2 font-mono text-[10.5px] leading-relaxed text-muted-foreground"
                >
                    <div className="whitespace-pre-wrap break-all">
                        {"→ " + JSON.stringify(item.args)}
                    </div>
                    {
                        if item.result {
                            <div
                                className="mt-1.5 max-h-40 overflow-y-auto whitespace-pre-wrap break-words thin-scroll"
                            >{"← " + item.result}</div>
                        }
                    }
                </div>
            }
        }
    </div>;
}

impl AssistantMsg(msg: Message, onPin: Callable[[Card], Coroutine[any, any, None]]) -> JsxElement {
    tools = len([it for it in msg.items if it.kind == "tool"]);
    usage = msg.usage;
    return <div className="flex gap-2.5">
        <span
            className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-gradient-to-br from-violet-500 to-indigo-600 text-white"
        ><Sparkles className="size-3.5" /></span>
        <div className="min-w-0 flex-1 space-y-2">
            {
                if tools > 0 {
                    <div
                        className="text-[10px] font-medium uppercase tracking-wider text-muted-foreground"
                    >{str(tools) + (" action" if tools == 1 else " actions")}</div>
                }
            }
            {
                for (i, it) in enumerate(msg.items) {
                    if it.kind == "tool" {
                        <ToolChip key={"t" + str(i)} item={it} />
                    } elif it.kind == "card" {
                        <ChartCard
                            key={"c" + str(i)}
                            title={it.card.title}
                            kind={it.card.kind}
                            spec={it.card.spec}
                            caption={it.card.caption}
                            pinned={it.card.pinned}
                            created={it.card.created}
                            onPin={lambda { onPin(it.card) }}
                            compact={True}
                        />
                    } elif it.kind == "thought" {
                        <div
                            key={"h" + str(i)}
                            className="flex gap-1.5 text-xs italic text-muted-foreground"
                        >
                            <Brain className="mt-0.5 size-3 shrink-0" />
                            <span className="line-clamp-3">{it.text}</span>
                        </div>
                    }
                }
            }
            {
                if msg.text {
                    <Markdown text={msg.text} className="leading-relaxed text-foreground" />
                } elif not msg.done {
                    <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                        <span
                            className="pulse-dot inline-block size-1.5 rounded-full bg-primary"
                        ></span>
                        {"Working…" if len(msg.items) > 0 else "Thinking…"}
                    </div>
                }
            }
            {
                if usage is not None {
                    <div className="text-[10px] text-muted-foreground/70 tabular">
                        {str(usage.requests)
                            + " model calls · "
                            + str(usage.tokens)
                            + " tokens · $"
                            + num_text(round(usage.cost * 1000) / 1000)}
                    </div>
                }
            }
        </div>
    </div>;
}

impl from_transcript(transcript: list[ChatMsg]) -> list[Message] {
    out: list[Message] = [];
    for m in transcript {
        if m.role == "user" {
            out.append(Message(role="user", text=m.text));
        } else {
            items: list[Item] = [];
            for tr in m.tools {
                items.append(
                    Item(
                        kind="tool",
                        tool=tr.tool,
                        args=tool_args(tr.args),
                        result=tr.result,
                        done=True,
                    ),
                );
            }
            for c in m.cards {
                items.append(Item(kind="card", card=c));
            }
            out.append(
                Message(
                    role="assistant",
                    text=m.text,
                    items=items,
                    usage=Usage(tokens=m.tokens, cost=m.cost, requests=len(m.tools) + 1)
                        if m.tokens
                        else None,
                ),
            );
        }
    }
    return out;
}

impl CopilotPane(path: str, search: str) -> JsxElement {
    has messages: list[Message] = [],
        draft: str = "",
        busy: bool = False,
        tid: str = "",
        remote: str = "",
        endRef: Ref[HTMLDivElement] = Ref(),
        inputRef: Ref[HTMLTextAreaElement] = Ref(),
        live: Ref[Shown] = Ref(),
        off_ask: Ref[Callable[[], None]] = Ref(),
        off_live: Ref[Callable[[], None]] = Ref();

    ws = useWorkspace();
    live.current = Shown(messages=messages, busy=busy, tid=tid, path=path, search=search);
    async can with entry {
        first = thread_id();
        tid = first;
        loaded: list[Message] = [];
        try {
            loaded = from_transcript(await chat_history(first));
        } except Exception {
            loaded = [];
            first = new_thread();
            tid = first;
        }
        messages = loaded;
        now: Shown = live.current;
        now.messages = loaded;
        now.tid = first;
        pending = take_pending_ask();
        if pending {
            await send(pending);
        }
    }
    can with entry {
        off_ask.current = on_channel(
            "copilot-ask",
            lambda (t: any) {
                now: Shown = live.current;
                if now.tid {
                    take_pending_ask();
                    queueMicrotask(lambda { send(t) });
                }
            },
        );
        off_live.current = on_live(
            lambda (e: LiveEvent) {
                if e.kind == "ui" and e.session.startswith("cli") {
                    remote = "Terminal agent: " + e.data.action;
                    setTimeout(lambda { remote = ""; }, 4000);
                }
            },
        );
    }
    can with exit {
        if off_ask.current {
            off_ask.current();
        }
        if off_live.current {
            off_live.current();
        }
    }
    can with [len(messages), busy] entry {
        if endRef.current {
            endRef.current.scrollIntoView({"block": "end", "behavior": "smooth"});
        }
    }
    async def pin(card: Card) {
        await pin_card(card.title, card.kind, card.caption, card.spec);
        toast("Pinned to the insight board", "success");
    }
    async def send(text: str) {
        body = text.strip();
        snap: Shown = live.current;
        if not body or snap.busy {
            return;
        }
        snap.busy = True;
        busy = True;
        draft = "";
        base = snap.messages + [Message(role="user", text=body)];
        cur = Message(role="assistant", done=False);
        messages = base + [cur];
        state = snap.path + snap.search;
        def on_frame(f: CopilotFrame) {
            t = f.t;
            if t == "chunk" {
                cur = cur.having(text=cur.text + f.text);
            } elif t == "thought" and f.text {
                cur = cur.having(items=cur.items + [Item(kind="thought", text=f.text)]);
            } elif t == "tool_call" {
                cur = cur.having(
                    items=cur.items + [
                        Item(kind="tool", tool=f.tool, id=f.id, args=tool_args(f.args)),
                    ],
                );
            } elif t == "tool_result" {
                fresh: list[Item] = [];
                for it in cur.items {
                    if it.kind == "tool" and it.id == f.id {
                        fresh.append(
                            Item(
                                kind="tool",
                                tool=it.tool,
                                id=it.id,
                                args=it.args,
                                result=f.result,
                                done=True,
                            ),
                        );
                    } else {
                        fresh.append(it);
                    }
                }
                cur = cur.having(items=fresh);
            } elif t == "card" and f.card is not None {
                cur = cur.having(items=cur.items + [Item(kind="card", card=f.card)]);
            } elif t == "usage" {
                cur = cur.having(usage=Usage(tokens=f.tokens, cost=f.cost, requests=f.requests));
            } elif t == "done" {
                cur = cur.having(done=True);
            } else {
                return;
            }
            messages = base + [cur];
        }
        try {
            async for frame in copilot_stream(snap.tid, body, state, session_id()) {
                on_frame(frame);
            }
        } except RemoteRejected {
            signed_out();
        } except Exception as e {
            cur = cur.having(text=cur.text + NL + NL + "_Connection lost: " + str(e) + "_");
        }
        cur = cur.having(done=True);
        messages = base + [cur];
        now: Shown = live.current;
        now.messages = base + [cur];
        now.busy = False;
        busy = False;
    }
    async def submit(e: any) {
        e.preventDefault();
        await send(draft);
    }
    async def on_key(e: any) {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            await send(draft);
        }
    }
    async def halt {
        snap: Shown = live.current;
        if snap.busy {
            await stop_turn(snap.tid);
            toast("Stopping after the current step", "info");
        }
    }
    async def reset {
        old: Shown = live.current;
        await clear_chat(old.tid);
        fresh = new_thread();
        tid = fresh;
        messages = [];
        now: Shown = live.current;
        now.messages = [];
        now.tid = fresh;
    }
    tips = suggestions_for(path);
    return <aside
        className="fixed inset-0 z-50 flex flex-col border-l border-border bg-sidebar lg:static lg:z-auto lg:w-[420px] lg:shrink-0 xl:w-[460px]"
    >
        <div className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-3">
            <span
                className="grid size-7 place-items-center rounded-lg bg-gradient-to-br from-violet-500 to-indigo-600 text-white shadow"
            ><Sparkles className="size-4" /></span>
            <div className="min-w-0">
                <div className="text-sm font-semibold leading-tight">Copilot</div>
                <div className="truncate text-[11px] leading-tight text-muted-foreground">
                    {((ws.model if ws else "model") + " · drives this UI live")}
                </div>
            </div>
            <div className="ml-auto flex items-center gap-1">
                <button
                    type="button"
                    title="New conversation"
                    onClick={reset}
                    className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
                ><SquarePen className="size-4" /></button>
                <button
                    type="button"
                    title="Close"
                    onClick={lambda { set_pane(False) }}
                    className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
                ><X className="size-4" /></button>
            </div>
        </div>
        {
            if remote {
                <div
                    className="fade-up flex items-center gap-2 border-b border-border bg-primary/10 px-3 py-1.5 text-xs text-primary"
                ><Terminal className="size-3.5" />{remote}</div>
            }
        }
        <div className="min-h-0 flex-1 overflow-y-auto px-3 py-4 thin-scroll">
            {
                if len(messages) == 0 {
                    <div className="fade-up">
                        <div className="rounded-2xl border border-border bg-card/70 p-4">
                            <div className="text-sm font-medium">
                            Ask me to review, explain, or explore.
                        </div>
                            <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                            I can do anything you can do here: open pull requests, run the full review pipeline, post and resolve comments, chart the repository, and draw diagrams. You will watch me do it.
                        </p>
                        </div>
                        <div className="mt-3 space-y-1.5">
                            {
                                for (i, tip) in enumerate(tips) {
                                    <button
                                        key={str(i)}
                                        type="button"
                                        onClick={lambda { send(tip) }}
                                        className="flex w-full items-start gap-2 rounded-xl border border-border bg-background/50 px-3 py-2 text-left text-xs text-muted-foreground transition-colors hover:border-primary/40 hover:text-foreground"
                                    >
                                        <Sparkles className="mt-0.5 size-3 shrink-0 text-primary" />
                                        {tip}
                                    </button>
                                }
                            }
                        </div>
                    </div>
                }
            }
            <div className="space-y-5">
                {
                    for (i, m) in enumerate(messages) {
                        if m.role == "user" {
                            <div key={str(i)} className="flex justify-end">
                                <div
                                    className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-br-md bg-primary px-3.5 py-2 text-sm text-primary-foreground"
                                >{m.text}</div>
                            </div>
                        } else {
                            <AssistantMsg key={str(i)} msg={m} onPin={pin} />
                        }
                    }
                }
            </div>
            <div ref={endRef} className="h-2"></div>
        </div>
        <form className="shrink-0 border-t border-border p-3" onSubmit={submit}>
            <div
                className="flex items-end gap-2 rounded-2xl border border-border bg-background px-3 py-2 focus-within:ring-2 focus-within:ring-primary/40"
            >
                <textarea
                    ref={inputRef}
                    value={draft}
                    rows={1}
                    placeholder={"Copilot is working…" if busy else "Ask Copilot to review, explain, or explore…"}
                    onChange={lambda (e: any) { draft = e.target.value; }}
                    onKeyDown={on_key}
                    className="max-h-40 min-h-[24px] flex-1 resize-none bg-transparent text-sm outline-none placeholder:text-muted-foreground"
                />
                {
                    if busy {
                        <button
                            type="button"
                            aria-label="Stop"
                            title="Stop after the current step"
                            onClick={lambda { halt() }}
                            className="grid size-8 shrink-0 place-items-center rounded-full bg-foreground text-background"
                        ><Square className="size-3.5 fill-current" /></button>
                    } else {
                        <button
                            type="submit"
                            aria-label="Send"
                            disabled={not draft.strip()}
                            className="grid size-8 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground transition-opacity disabled:opacity-40"
                        ><ArrowUp className="size-4" /></button>
                    }
                }
            </div>
            <div className="mt-1.5 px-1 text-[10px] text-muted-foreground/70">
                Enter to send · Shift+Enter for a new line · actions appear live in the app · long chats are compacted, never cut
            </div>
        </form>
    </aside>;
}
