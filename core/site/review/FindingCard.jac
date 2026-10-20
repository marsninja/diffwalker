import from "lucide-react" {
    Check,
    X,
    RotateCcw,
    MessageCircle,
    Sparkles,
    ShieldCheck,
    FileCode2,
    Bot,
    User,
    Send
}

glob SOURCE_LABEL: dict[str, str] = {
         "static": "static analysis",
         "lens:batch": "batch lens",
         "lens:cross-file": "cross-file pass",
         "copilot": "Copilot",
         "you": "you",
         "agent": "agent"
     };

def source_label(src: str) -> str {
    if src.startswith("lens:") {
        return src[5:] + " lens";
    }
    return SOURCE_LABEL[src] or src;
}

def:pub FindingCard(
    f: any,
    onChanged: any = None,
    onJump: any = None,
    inline: bool = False,
    flash: bool = False
) -> JsxElement {
    has replying: bool = False,
        reply: str = "",
        busy: bool = False,
        local: any = None;
    cur = local or f;
    async def set_status(status: str) {
        busy = True;
        updated = await set_finding_status(cur.id, status, "");
        busy = False;
        if updated {
            local = updated;
        }
        if onChanged {
            onChanged();
        }
    }
    async def send_reply {
        if not reply.strip() {
            return;
        }
        busy = True;
        updated = await reply_finding(cur.id, reply);
        busy = False;
        reply = "";
        replying = False;
        if updated {
            local = updated;
        }
    }
    closed = cur.status != "open";
    <div
        id={"finding-" + cur.id}
        className={"rounded-xl border bg-card text-sm shadow-sm transition-all "
            + ("agent-flash " if flash else "")
            + ("opacity-60" if closed else "")}
        style={{
            "borderColor": "color-mix(in oklab, "
                + sev_color(cur.severity)
                + " 35%, var(--border))"
        }}
    >
        <div className="flex flex-wrap items-start gap-2 px-3.5 pt-3">
            <SevBadge sev={cur.severity}/>
            <span
                className="rounded-full bg-muted px-1.5 py-0.5 text-[10.5px] text-muted-foreground"
            >
                {cur.category}
            </span>
            {if cur.verified {
                <span
                    className="inline-flex items-center gap-1 text-[10.5px] text-[var(--status-good)]"
                    title={cur.verifier_note or "Survived the adversarial verifier"}
                >
                    <ShieldCheck className="size-3"/>
                    verified
                </span>
            }}
            <span className="ml-auto font-mono text-[10.5px] text-muted-foreground">
                {cur.id}
            </span>
        </div>
        <div className="px-3.5 pb-3 pt-1.5">
            <div
                className={"font-medium leading-snug "
                    + ("line-through" if cur.status == "dismissed" else "")}
            >
                {cur.title}
            </div>
            {if not inline {
                <button
                    type="button"
                    onClick={lambda { if onJump { onJump(cur); }}}
                    className="mt-0.5 inline-flex items-center gap-1 font-mono text-[11px] text-primary hover:underline"
                >
                    <FileCode2 className="size-3"/>
                    {cur.path + ":" + str(cur.line)}
                </button>
            }}
            <Markdown
                text={cur.body}
                className="mt-1 text-[13px] text-muted-foreground"
            />
            {if cur.suggestion {
                <div
                    className="mt-2 overflow-hidden rounded-lg border border-[var(--status-good)]/30"
                >
                    <div
                        className="bg-[var(--status-good)]/10 px-2.5 py-1 text-[10.5px] font-medium text-[var(--status-good)]"
                    >
                        Suggested change
                    </div>
                    <pre
                        className="overflow-x-auto bg-background/60 p-2.5 font-mono text-[11.5px] leading-relaxed thin-scroll"
                    >
                        {cur.suggestion}
                    </pre>
                </div>
            }}
            {if cur.verifier_note and not inline {
                <p className="mt-2 text-[11px] italic text-muted-foreground">
                    {"Verifier: " + cur.verifier_note}
                </p>
            }}
            {if len(cur.looked_at or []) > 0 and not inline {
                <p className="mt-1 font-mono text-[10.5px] text-muted-foreground" title="Related code the investigator walker chose to read before verification">
                    {"Checked against: " + ", ".join(cur.looked_at[:4])}
                </p>
            }}
            {if cur.anchored == False {
                <p className="mt-1 text-[10.5px] text-[var(--status-warning)]">
                    The reviewer pointed outside the diff; pinned to the nearest changed line.
                </p>
            }}
            {if len(cur.replies or []) > 0 {
                <div className="mt-2 space-y-1.5 border-l-2 border-border pl-2.5">
                    {for (i, r) in enumerate(cur.replies) {
                        <div key={str(i)} className="text-xs">
                            <span
                                className="inline-flex items-center gap-1 font-medium"
                            >
                                {(<Bot className="size-3 text-primary"/>)
                                    if r.author == "Copilot"
                                    else (<User className="size-3"/>)}{r.author}
                            </span>
                            <span className="ml-1.5 text-muted-foreground">
                                {ago(r.ts)}
                            </span>
                            <div className="mt-0.5 text-muted-foreground">{r.text}</div>
                        </div>
                    }}
                </div>
            }}
            <div className="mt-3 flex flex-wrap items-center gap-1.5">
                {if not closed {
                    <button
                        type="button"
                        disabled={busy}
                        onClick={lambda { set_status("resolved"); }}
                        className="inline-flex items-center gap-1 rounded-md border border-border px-2 py-1 text-[11px] hover:bg-muted disabled:opacity-50"
                    >
                        <Check className="size-3"/>
                        Resolve
                    </button>
                    <button
                        type="button"
                        disabled={busy}
                        onClick={lambda { set_status("dismissed"); }}
                        className="inline-flex items-center gap-1 rounded-md border border-border px-2 py-1 text-[11px] hover:bg-muted disabled:opacity-50"
                    >
                        <X className="size-3"/>
                        Dismiss
                    </button>
                } else {
                    <button
                        type="button"
                        disabled={busy}
                        onClick={lambda { set_status("open"); }}
                        className="inline-flex items-center gap-1 rounded-md border border-border px-2 py-1 text-[11px] hover:bg-muted disabled:opacity-50"
                    >
                        <RotateCcw className="size-3"/>
                        {"Reopen (" + cur.status + ")"}
                    </button>
                } }
                <button
                    type="button"
                    onClick={lambda { replying = not replying; }}
                    className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                >
                    <MessageCircle className="size-3"/>
                    Reply
                </button>
                <button
                    type="button"
                    onClick={lambda { ask_copilot(
                        "Explain finding "
                            + cur.id
                            + " ("
                            + cur.title
                            + ") at "
                            + cur.path
                            + ":"
                            + str(cur.line)
                            + ". Show me the code, check whether it is real, and propose a fix."
                    ); }}
                    className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] text-primary hover:bg-primary/10"
                >
                    <Sparkles className="size-3"/>
                    Ask Copilot
                </button>
                <span className="ml-auto text-[10.5px] text-muted-foreground">
                    {source_label(cur.source)
                        + " · "
                        + str(round(cur.confidence * 100))
                        + "% conf"}
                </span>
            </div>
            {if replying {
                <form
                    className="mt-2 flex gap-2"
                    onSubmit={lambda (e: any) {
                        e.preventDefault();
                        send_reply();
                    }}
                >
                    <input
                        value={reply}
                        autoFocus={True}
                        onChange={lambda (e: any) { reply = e.target.value; }}
                        placeholder="Reply to this finding"
                        className="h-8 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-xs outline-none focus:ring-2 focus:ring-primary/40"
                    />
                    <button
                        type="submit"
                        className="grid size-8 place-items-center rounded-md bg-primary text-primary-foreground"
                        aria-label="Send reply"
                    >
                        <Send className="size-3.5"/>
                    </button>
                </form>
            }}
        </div>
    </div>
}
