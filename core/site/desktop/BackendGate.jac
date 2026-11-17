import from "lucide-react" { Laptop, Server, ArrowLeftRight, LoaderCircle, UserRound, Plus }

"""Where a mode runs, in the words the picker and the switch use."""
def mode_label(mode: str) -> str {
    return "On this computer" if mode == "local" else "A diffwalker server";
}

def switch_label(mode: str) -> str {
    return "Run on this computer instead" if mode == "local" else "Connect to a server instead";
}

def mode_blurb(mode: str) -> str {
    if mode == "local" {
        return "Reviews the repositories on this machine with your own model key. Nothing leaves this computer except calls to the model.";
    }
    return "Signs in to a shared diffwalker server. Reviews, findings, and Copilot threads live there.";
}

"""The desktop app's first screens: where diffwalker runs (when the app can run more than
one way and its user has chosen none), then, running locally, which profile. A browser
or a server-mode window has neither and renders the app, whose own sign-in applies."""
def:pub BackendGate(children: any) -> JsxElement {
    has d: Desk = desk();

    async can with entry {
        d = await load_desk();
    }

    if not d.loaded {
        return <></>;
    }
    if len(d.modes) > 1 and not d.chosen {
        return <BackendPicker d={d} />;
    }
    if d.local and d.profile == "" {
        return <ProfilePicker d={d} onOpen={lambda (opened: Desk) { d = opened; }} />;
    }
    return <>{children}</>;
}

"""Local profiles, like save slots: each keeps its own reviews, findings, board, and
Copilot threads, and none needs a password."""
def ProfilePicker(d: Desk, onOpen: Callable[[Desk], None]) -> JsxElement {
    has name: str = "",
        busy: str = "",
        error: str = "";
    async def start(e: any) {
        e.preventDefault();
        if not name.strip() {
            error = "Give the profile a name.";
            return;
        }
        busy = "new";
        error = "";
        try {
            onOpen(await open_profile(name.strip()));
        } except Exception as err {
            error = str(err);
            busy = "";
        }
    }
    async def resume(pid: str) {
        busy = pid;
        try {
            onOpen(await open_profile(pid));
        } except Exception as e {
            error = str(e);
            busy = "";
        }
    }
    return <div
        className="grid-bg flex min-h-svh items-center justify-center bg-background p-4 text-foreground"
    >
        <div className="w-full max-w-md">
            <div className="mb-6 flex justify-center"><Wordmark /></div>
            <h1 className="text-center text-lg font-semibold tracking-tight">
                {"Continue where you left off" if d.profiles else "Start a profile"}
            </h1>
            <p className="mt-1 text-center text-sm text-muted-foreground">
                Each profile keeps its own reviews, findings, and Copilot threads on this computer. No account or password.
            </p>
            {
                if d.profiles {
                    <div className="mt-6 space-y-2">
                        {[
                            <button
                                key={p}
                                type="button"
                                disabled={busy != ""}
                                onClick={lambda { resume(p) }}
                                className="flex w-full items-center gap-3 rounded-xl border border-border bg-card p-3 text-left shadow-sm transition hover:border-primary/60 hover:bg-muted/40 disabled:opacity-60"
                            >
                                <span
                                    className="inline-flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary"
                                >
                                    {(<LoaderCircle className="size-4 animate-spin" />)
                                        if busy == p
                                        else (<UserRound className="size-4" />)}
                                </span>
                                <span className="min-w-0 flex-1">
                                    <span className="block truncate text-sm font-semibold">
                                        {p}
                                    </span>
                                </span>
                            </button>
                            for p in d.profiles
                        ]}
                    </div>
                }
            }
            <form className="mt-4 flex gap-2" onSubmit={start}>
                <input
                    name="profile"
                    placeholder={"New profile name" if d.profiles else "Profile name, e.g. Work"}
                    value={name}
                    onChange={lambda (e: any) { name = e.target.value; }}
                    className="h-10 min-w-0 flex-1 rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none focus:ring-2 focus:ring-primary/40"
                />
                <button
                    type="submit"
                    disabled={busy != ""}
                    className="inline-flex h-10 items-center gap-1.5 rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-60"
                >
                    {(<LoaderCircle className="size-4 animate-spin" />)
                        if busy == "new"
                        else (<Plus className="size-4" />)}
                    {"New profile" if d.profiles else "Start"}
                </button>
            </form>
            {
                if error {
                    <p
                        role="alert"
                        className="mt-3 text-center text-xs text-[var(--status-critical)]"
                    >{error}</p>
                }
            }
            <div className="mt-6 flex justify-center"><ModeSwitch /></div>
        </div>
    </div>;
}

def BackendPicker(d: Desk) -> JsxElement {
    has busy: str = "",
        error: str = "";
    async def pick(name: str) {
        busy = name;
        error = "";
        try {
            await choose_mode(name);
        } except Exception as e {
            error = str(e);
            busy = "";
        }
    }
    return <div
        className="grid-bg flex min-h-svh items-center justify-center bg-background p-4 text-foreground"
    >
        <div className="w-full max-w-2xl">
            <div className="mb-6 flex justify-center"><Wordmark /></div>
            <h1 className="text-center text-lg font-semibold tracking-tight">
                How should diffwalker run?
            </h1>
            <p className="mt-1 text-center text-sm text-muted-foreground">
                You can switch later from the sidebar. Each mode keeps its own data.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-2">
                {[
                    <button
                        key={b}
                        type="button"
                        disabled={busy != ""}
                        onClick={lambda { pick(b) }}
                        className="flex flex-col items-start gap-2 rounded-2xl border border-border bg-card p-5 text-left shadow-xl transition hover:border-primary/60 hover:bg-muted/40 disabled:opacity-60"
                    >
                        <span
                            className="inline-flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary"
                        >
                            {(<LoaderCircle className="size-5 animate-spin" />)
                                if busy == b
                                else (
                                    (<Laptop className="size-5" />)
                                        if b == "local"
                                        else (<Server className="size-5" />)
                                )}
                        </span>
                        <span className="text-sm font-semibold">{mode_label(b)}</span>
                        <span className="text-xs leading-relaxed text-muted-foreground">
                            {mode_blurb(b)}
                        </span>
                    </button>
                    for b in d.modes
                ]}
            </div>
            {
                if error {
                    <p
                        role="alert"
                        className="mt-4 text-center text-xs text-[var(--status-critical)]"
                    >{error}</p>
                }
            }
        </div>
    </div>;
}

"""The running mode and profile, and switches to the others; nothing outside the desktop app."""
def:pub ModeSwitch -> JsxElement {
    has busy: bool = False;
    d = desk();
    if len(d.modes) < 2 and not d.local {
        return <></>;
    }
    others = [m for m in d.modes if m != d.mode];
    async def change_to(name: str) {
        busy = True;
        try {
            await choose_mode(name);
        } except Exception {
            busy = False;
        }
    }
    async def close_profile {
        busy = True;
        await leave_profile();
    }
    return <div className="space-y-1">
        {
            if len(d.modes) > 1 {
                <p className="flex items-center gap-1.5 px-1 text-[11px] text-muted-foreground">
                    {(<Laptop className="size-3" />)
                        if d.mode == "local"
                        else (<Server className="size-3" />)}
                    <span className="truncate">{mode_label(d.mode)}</span>
                </p>
            }
        }
        {
            if d.profile != "" {
                <button
                    type="button"
                    disabled={busy}
                    onClick={close_profile}
                    className="inline-flex w-full items-center gap-1.5 rounded-md px-1.5 py-1 text-left text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground disabled:opacity-60"
                >
                    <UserRound className="size-3" />
                    <span className="truncate">{d.profile + " · switch profile"}</span>
                </button>
            }
        }
        {[
            <button
                key={m}
                type="button"
                disabled={busy}
                onClick={lambda { change_to(m) }}
                className="inline-flex w-full items-center gap-1.5 rounded-md px-1.5 py-1 text-left text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground disabled:opacity-60"
            >
                {(<LoaderCircle className="size-3 animate-spin" />)
                    if busy
                    else (<ArrowLeftRight className="size-3" />)}
                <span className="truncate">{switch_label(m)}</span>
            </button>
            for m in others
        ]}
    </div>;
}
