import from "@jac/runtime" { Outlet, Link, useNavigate, useLocation }
import from "lucide-react" {
    LayoutDashboard,
    GitPullRequest,
    Activity,
    LayoutGrid,
    Hammer,
    Sparkles,
    Sun,
    Moon,
    FolderGit2,
    Menu,
    X,
    Check,
    Copy,
    Github,
    Zap,
    Info,
    TriangleAlert,
    CircleCheck,
    LogOut
}

glob NAV: list[any] = [
         {"to": "/", "label": "Dashboard", "icon": LayoutDashboard},
         {"to": "/reviews", "label": "Reviews", "icon": GitPullRequest},
         {"to": "/insights", "label": "Insights", "icon": Activity},
         {"to": "/board", "label": "Insight board", "icon": LayoutGrid},
         {"to": "/built", "label": "How it's built", "icon": Hammer}
     ],
     ACTION_LABEL: dict[str, str] = {
         "navigate": "navigated",
         "filter": "filtered findings",
         "export": "opened the export",
         "confirm_publish": "asked to publish",
         "repo": "switched repository"
     };

def is_active(path: str, to: str) -> bool {
    if to == "/" {
        return path == "/";
    }
    return path.startswith(to);
}

def:pub handle_ui_action(action: str, args: any, nav: any, origin: str) {
    label = ACTION_LABEL[action] or action;
    if action == "navigate" {
        url = args.to or "/";
        parts: list[str] = [];
        for key in ["tab", "file", "line", "view"] {
            if args[key] {
                parts.append(key + "=" + encodeURIComponent(str(args[key])));
            }
        }
        parts.append("nonce=" + rand_id());
        nav(url + "?" + "&".join(parts));
        detail = args.to or "/";
        if args.file {
            detail = args.file + ":" + str(args.line or "");
        }
        publish(
            "agent-action",
            {"label": "Copilot " + label, "detail": detail, "origin": origin}
        );
        return;
    }
    if action == "filter" {
        publish("findings-filter", args);
        publish(
            "agent-action",
            {
                "label": "Copilot " + label,
                "detail": (args.severity or "all")
                    + " · "
                    + (args.status or "any status"),
                "origin": origin
            }
        );
        return;
    }
    if action == "toast" {
        toast(args.message, args.tone or "info");
        return;
    }
    if action == "export" {
        publish("export", args);
        return;
    }
    if action == "confirm_publish" {
        publish("confirm-publish", args);
        return;
    }
    if action == "repo" {
        refresh_workspace();
        nav("/");
        publish(
            "agent-action",
            {
                "label": "Copilot switched repository",
                "detail": args.path,
                "origin": origin
            }
        );
    }
}

def NavItem(item: any, active: bool, onPick: any = None) -> JsxElement {
    Icon = item["icon"];
    <Link
        to={item["to"]}
        onClick={lambda { if onPick { onPick(); }}}
        className={"group flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm transition-colors "
            + (
                "bg-primary/12 text-foreground font-medium"
                    if active
                    else "text-muted-foreground hover:bg-muted hover:text-foreground"
            )}
    >
        <span
            className={"grid size-6 place-items-center rounded-md "
                + (
                    "bg-primary text-primary-foreground"
                        if active
                        else "bg-muted/60 text-muted-foreground group-hover:text-foreground"
                )}
        >
            <Icon className="size-3.5"/>
        </span>
        {item["label"]}
    </Link>
}

def NavLinks(path: str, onPick: any = None) -> JsxElement {
    <nav className="flex flex-col gap-0.5">
        {for item in NAV {
            <NavItem
                key={item["to"]}
                item={item}
                active={is_active(path, item["to"])}
                onPick={onPick}
            />
        }}
    </nav>
}

def Sidebar(path: str, ws: any) -> JsxElement {
    <aside
        className="hidden w-60 shrink-0 flex-col border-r border-border bg-sidebar md:flex"
    >
        <Link to="/" className="flex h-14 items-center px-4">
            <Wordmark/>
        </Link>
        <div className="px-3 pt-2">
            <NavLinks path={path}/>
        </div>
        <div className="mt-auto space-y-3 p-3">
            <div className="rounded-xl border border-border bg-card/60 p-3 text-xs">
                <div
                    className="mb-1.5 flex items-center gap-1.5 font-medium text-foreground"
                >
                    <Sparkles className="size-3.5 text-primary"/>
                    Agentic reviewer
                </div>
                <p className="leading-relaxed text-muted-foreground">
                    {"Eight-stage walker pipeline on "
                        + ((ws and ws.model) or "the configured model")
                        + ". The Copilot drives this UI live."}
                </p>
                <div className="mt-2 flex items-center gap-1.5 text-[11px]">
                    <span
                        className={"inline-block size-1.5 rounded-full "
                            + (
                                "bg-[var(--status-good)]"
                                    if ws and ws.llm
                                    else "bg-[var(--status-warning)]"
                            )}
                    ></span>
                    <span className="text-muted-foreground">
                        {("LLM ready" if ws and ws.llm else "LLM key missing")
                            if ws
                            else "…"}
                    </span>
                    {if ws and ws.gh {
                        <span
                            className="ml-auto inline-flex items-center gap-1 text-muted-foreground"
                        >
                            <Github className="size-3"/>
                            gh
                        </span>
                    }}
                </div>
            </div>
            <ModeSwitch/>
            <div className="flex items-center justify-between px-1">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground/60">
                    Built with Jac
                </p>
                {if not profiles_on() {
                    <button
                        type="button"
                        onClick={lambda { signed_out(); }}
                        className="inline-flex items-center gap-1 rounded-md px-1.5 py-1 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                    >
                        <LogOut className="size-3"/>
                        Sign out
                    </button>
                }}
            </div>
        </div>
    </aside>
}

def RepoSwitcher(ws: any) -> JsxElement {
    has open: bool = False,
        path: str = "",
        busy: bool = False,
        error: str = "";
    async def choose(target: str) {
        busy = True;
        error = "";
        w = await set_repository(target);
        busy = False;
        if w.error {
            error = w.error;
            return;
        }
        publish("workspace", w);
        open = False;
        toast("Now reviewing " + w.repo.name, "success");
    }
    repo = ws.repo if ws else None;
    <div className="relative">
        <button
            type="button"
            onClick={lambda {
                open = not open;
                path = repo.path if repo else "";
            }}
            className="flex max-w-[52vw] items-center gap-2 rounded-lg border border-border bg-card/70 px-2.5 py-1.5 text-left text-sm hover:bg-muted md:max-w-[420px]"
        >
            <FolderGit2 className="size-4 shrink-0 text-primary"/>
            <span className="truncate font-medium">{repo.name if repo else "…"}</span>
            {if repo {
                <span
                    className="hidden truncate font-mono text-[11px] text-muted-foreground sm:inline"
                >
                    {repo.branch + " · " + repo.head}
                </span>
            }}
        </button>
        {if open {
            <div
                className="absolute left-0 top-11 z-40 w-[min(92vw,460px)] rounded-xl border border-border bg-popover p-3 shadow-2xl"
            >
                <div className="mb-2 text-xs font-medium text-muted-foreground">
                    Point diffwalker at a local git repository
                </div>
                <form
                    className="flex gap-2"
                    onSubmit={lambda (e: any) {
                        e.preventDefault();
                        choose(path);
                    }}
                >
                    <input
                        value={path}
                        onChange={lambda (e: any) { path = e.target.value; }}
                        placeholder="/path/to/repo"
                        className="h-9 min-w-0 flex-1 rounded-md border border-border bg-background px-2.5 font-mono text-xs outline-none focus:ring-2 focus:ring-primary/40"
                    />
                    <button
                        type="submit"
                        disabled={busy}
                        className="h-9 rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground disabled:opacity-50"
                    >
                        {"Opening…" if busy else "Open"}
                    </button>
                </form>
                {if error {
                    <p className="mt-2 text-xs text-[var(--status-critical)]">
                        {error}
                    </p>
                }}
                {if ws and len(ws.recent) > 0 {
                    <div className="mt-3">
                        <div
                            className="mb-1 text-[10px] uppercase tracking-wider text-muted-foreground"
                        >
                            Recent
                        </div>
                        {for r in ws.recent {
                            <button
                                key={r}
                                type="button"
                                onClick={lambda { choose(r); }}
                                className="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left font-mono text-xs hover:bg-muted"
                            >
                                <FolderGit2 className="size-3.5 text-muted-foreground"/>
                                <span className="truncate">{r}</span>
                                {if repo and r == repo.path {
                                    <Check className="ml-auto size-3.5 text-primary"/>
                                }}
                            </button>
                        }}
                    </div>
                }}
            </div>
        }}
    </div>
}

def LiveDot -> JsxElement {
    has status: str = live_status();
    can with entry {
        off = on_channel("live-status", lambda (s: str) { status = s; });
        return lambda { off(); };
    }
    <span
        className="hidden items-center gap-1.5 rounded-full border border-border px-2 py-1 text-[11px] text-muted-foreground sm:inline-flex"
        title="Live event stream"
    >
        <span
            className={"inline-block size-1.5 rounded-full "
                + (
                    "pulse-dot bg-[var(--status-good)]"
                        if status == "live"
                        else "bg-[var(--status-warning)]"
                )}
        ></span>
        {"Live" if status == "live" else "Reconnecting"}
    </span>
}

def Topbar(ws: any, path: str) -> JsxElement {
    dark = useDark();
    pane = usePane();
    has menu: bool = False;
    <header
        className="relative z-30 flex h-14 shrink-0 items-center gap-2 border-b border-border bg-background/80 px-3 backdrop-blur md:px-4"
    >
        <button
            type="button"
            className="rounded-md p-1.5 hover:bg-muted md:hidden"
            onClick={lambda { menu = True; }}
            aria-label="Open navigation"
        >
            <Menu className="size-5"/>
        </button>
        <span className="md:hidden">
            <BrandMark size={24}/>
        </span>
        <RepoSwitcher ws={ws}/>
        <div className="ml-auto flex items-center gap-2">
            <LiveDot/>
            <button
                type="button"
                aria-label="Toggle theme"
                onClick={lambda { apply_theme(not dark); }}
                className="rounded-md p-2 text-muted-foreground hover:bg-muted hover:text-foreground"
            >
                {(<Sun className="size-4"/>) if dark else (<Moon className="size-4"/>)}
            </button>
            <button
                type="button"
                onClick={lambda { set_pane(not pane); }}
                className={"inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors "
                    + (
                        "bg-primary/15 text-primary"
                            if pane
                            else "bg-primary text-primary-foreground hover:bg-primary/90"
                    )}
            >
                <Sparkles className="size-4"/>
                <span className="hidden sm:inline">Copilot</span>
            </button>
        </div>
        {if menu {
            <div className="fixed inset-0 z-50 md:hidden">
                <div
                    className="absolute inset-0 bg-black/50"
                    onClick={lambda { menu = False; }}
                ></div>
                <div
                    className="absolute inset-y-0 left-0 w-64 border-r border-border bg-sidebar p-3"
                >
                    <div className="mb-4 flex items-center justify-between px-1">
                        <Wordmark/>
                        <button
                            type="button"
                            className="rounded-md p-1 hover:bg-muted"
                            onClick={lambda { menu = False; }}
                            aria-label="Close navigation"
                        >
                            <X className="size-4"/>
                        </button>
                    </div>
                    <NavLinks path={path} onPick={lambda { menu = False; }}/>
                </div>
            </div>
        }}
    </header>
}

def Toaster -> JsxElement {
    has items: list[any] = [];
    can with entry {
        off = on_channel(
            "toast",
            lambda (t: any) {
                items = items + [t];
                setTimeout(
                    lambda { items = [
                        x
                        for x in items
                        if x["id"] != t["id"]
                    ]; },
                    4200
                );
            }
        );
        return lambda { off(); };
    }
    <div
        className="pointer-events-none fixed bottom-4 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2"
    >
        {for t in items {
            <div
                key={t["id"]}
                className="fade-up pointer-events-auto flex max-w-[90vw] items-center gap-2 rounded-xl border border-border bg-popover px-3.5 py-2 text-sm shadow-xl"
            >
                {if t["tone"] == "success" {
                    <CircleCheck className="size-4 text-[var(--status-good)]"/>
                } elif t["tone"] == "warning" {
                    <TriangleAlert className="size-4 text-[var(--status-warning)]"/>
                } else {
                    <Info className="size-4 text-primary"/>
                }  }
                <span>{t["message"]}</span>
            </div>
        }}
    </div>
}

def AgentBeacon -> JsxElement {
    has beacon: any = None;
    can with entry {
        off = on_channel(
            "agent-action",
            lambda (b: any) {
                stamp = rand_id();
                beacon = {
                    "label": b["label"],
                    "detail": b["detail"],
                    "origin": b["origin"],
                    "id": stamp
                };
                setTimeout(lambda { beacon = None; }, 2600);
            }
        );
        return lambda { off(); };
    }
    if not beacon {
        return <span></span>;
    }
    <div
        key={beacon["id"]}
        className="fade-up pointer-events-none fixed left-1/2 top-16 z-[55] -translate-x-1/2"
    >
        <div
            className="glow-ring flex items-center gap-2 rounded-full border border-primary/40 bg-popover/95 px-3.5 py-1.5 text-xs shadow-xl backdrop-blur"
        >
            <Zap className="size-3.5 text-primary"/>
            <span className="font-medium">{beacon["label"]}</span>
            <span className="max-w-[40vw] truncate font-mono text-muted-foreground">
                {beacon["detail"]}
            </span>
            {if beacon["origin"] and beacon["origin"] != "self" {
                <span
                    className="rounded-full bg-primary/15 px-1.5 py-0.5 text-[10px] uppercase tracking-wider text-primary"
                >
                    {"via " + beacon["origin"]}
                </span>
            }}
        </div>
    </div>
}

def ExportDialog -> JsxElement {
    has md: str = "",
        pr_id: str = "",
        copied: bool = False,
        raw: bool = False;
    can with entry {
        off = on_channel(
            "export",
            lambda (a: any) {
                md = a.markdown or "";
                pr_id = a.pr_id or "";
                copied = False;
            }
        );
        return lambda { off(); };
    }
    if not md {
        return <span></span>;
    }
    <div className="fixed inset-0 z-[70] grid place-items-center p-4">
        <div
            className="absolute inset-0 bg-black/60"
            onClick={lambda { md = ""; }}
        ></div>
        <div
            className="relative flex max-h-[85vh] w-full max-w-3xl flex-col rounded-2xl border border-border bg-popover shadow-2xl"
        >
            <div className="flex items-center gap-2 border-b border-border px-4 py-3">
                <div className="text-sm font-semibold">
                    {"Review export · " + pr_id}
                </div>
                <div
                    className="ml-auto flex items-center gap-1 rounded-lg bg-muted p-0.5 text-xs"
                >
                    <button
                        type="button"
                        onClick={lambda { raw = False; }}
                        className={"rounded-md px-2 py-1 "
                            + (
                                "bg-background shadow-sm"
                                    if not raw
                                    else "text-muted-foreground"
                            )}
                    >
                        Preview
                    </button>
                    <button
                        type="button"
                        onClick={lambda { raw = True; }}
                        className={"rounded-md px-2 py-1 "
                            + (
                                "bg-background shadow-sm"
                                    if raw
                                    else "text-muted-foreground"
                            )}
                    >
                        Markdown
                    </button>
                </div>
                <button
                    type="button"
                    onClick={lambda {
                        navigator.clipboard.writeText(md);
                        copied = True;
                    }}
                    className="inline-flex items-center gap-1.5 rounded-md bg-primary px-2.5 py-1.5 text-xs font-medium text-primary-foreground"
                >
                    {(<Check className="size-3.5"/>)
                        if copied
                        else (<Copy className="size-3.5"/>)}{"Copied"
                        if copied
                        else "Copy"}
                </button>
                <button
                    type="button"
                    className="rounded-md p-1.5 hover:bg-muted"
                    onClick={lambda { md = ""; }}
                    aria-label="Close"
                >
                    <X className="size-4"/>
                </button>
            </div>
            <div className="min-h-0 flex-1 overflow-y-auto thin-scroll p-5">
                {(
                    <pre
                        className="whitespace-pre-wrap font-mono text-xs leading-relaxed"
                    >
                        {md}
                    </pre>
                )
                    if raw
                    else (<Markdown text={md}/>)}
            </div>
        </div>
    </div>
}

def PublishDialog -> JsxElement {
    has req: any = None,
        busy: bool = False,
        result: str = "";
    can with entry {
        off = on_channel(
            "confirm-publish",
            lambda (a: any) {
                req = a;
                result = "";
            }
        );
        return lambda { off(); };
    }
    async def go {
        busy = True;
        result = await publish_review(req.pr_id);
        busy = False;
    }
    if not req {
        return <span></span>;
    }
    <div className="fixed inset-0 z-[70] grid place-items-center p-4">
        <div
            className="absolute inset-0 bg-black/60"
            onClick={lambda { req = None; }}
        ></div>
        <div
            className="relative w-full max-w-md rounded-2xl border border-border bg-popover p-5 shadow-2xl"
        >
            <div className="flex items-center gap-2 text-sm font-semibold">
                <Github className="size-4"/>
                {"Publish review to GitHub PR #" + str(req.number)}
            </div>
            <p className="mt-2 text-sm text-muted-foreground">
                This posts the latest diffwalker review as a comment on the pull request with your gh credentials. It is visible to everyone on that repository.
            </p>
            {if req.url {
                <a
                    href={req.url}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-2 block truncate font-mono text-xs text-primary underline"
                >
                    {req.url}
                </a>
            }}
            {if result {
                <p className="mt-3 rounded-md bg-muted p-2 text-xs">{result}</p>
            }}
            <div className="mt-4 flex justify-end gap-2">
                <button
                    type="button"
                    onClick={lambda { req = None; }}
                    className="rounded-md px-3 py-1.5 text-sm hover:bg-muted"
                >
                    {"Close" if result else "Cancel"}
                </button>
                {if not result {
                    <button
                        type="button"
                        disabled={busy}
                        onClick={go}
                        className="rounded-md bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
                    >
                        {"Publishing…" if busy else "Publish"}
                    </button>
                }}
            </div>
        </div>
    </div>
}

"""The root layout: the sign-in page renders bare, everything else inside the shell."""
def:pub RootLayout -> JsxElement {
    location = useLocation();
    if location.pathname.startswith("/login") {
        return <Outlet/>;
    }
    return <AppShell/>;
}

def:pub AppShell -> JsxElement {
    nav = useNavigate();
    location = useLocation();
    ws = useWorkspace();
    pane = usePane();
    can with entry {
        init_theme();
        if window.innerWidth < 1536 {
            set_pane(False);
        }
        start_live();
        me = session_id();
        off = on_live(
            lambda (e: any) {
                if e.kind != "ui" or not e.data {
                    return;
                }
                origin = "";
                if e.session == me {
                    origin = "self";
                } elif e.session and e.session.startswith("cli") {
                    origin = "cli";
                } else {
                    return;
                }
                handle_ui_action(e.data.action, e.data.args, nav, origin);
            }
        );
        return lambda { off(); };
    }
    <div className="flex h-dvh overflow-hidden bg-background text-foreground">
        <Sidebar path={location.pathname} ws={ws}/>
        <div className="flex min-w-0 flex-1 flex-col">
            <Topbar ws={ws} path={location.pathname}/>
            <main
                id="main"
                className="relative min-h-0 flex-1 overflow-y-auto overflow-x-hidden thin-scroll"
            >
                <Outlet/>
            </main>
        </div>
        {if pane {
            <CopilotPane path={location.pathname} search={location.search}/>
        }}
        <Toaster/>
        <AgentBeacon/>
        <ExportDialog/>
        <PublishDialog/>
    </div>
}
