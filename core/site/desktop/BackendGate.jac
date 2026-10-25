import from "@jac/desktop" { backend, profiles }
import from "lucide-react" { Laptop, Server, ArrowLeftRight, LoaderCircle, UserRound, Plus }

"""Where a backend runs, in the words the picker and the switch use."""
def backend_label(b: any) -> str {
    if b["kind"] == "embedded" {
        return "On this computer";
    }
    return "Server · " + str(b["url"]).replace("https://", "").replace("http://", "");
}

def switch_label(b: any) -> str {
    if b["kind"] == "embedded" {
        return "Run on this computer instead";
    }
    return "Connect to " + backend_label(b).replace("Server · ", "") + " instead";
}

def backend_blurb(b: any) -> str {
    if b["kind"] == "embedded" {
        return "Reviews the repositories on this machine with your own model key. Nothing leaves this computer except calls to the model.";
    }
    return "Signs in to a shared diffwalker server. Reviews, findings, and Copilot threads live there.";
}

"""The desktop app's first screens: where diffwalker runs (when the build ships more
than one backend and none is chosen), then, running locally, which profile. A browser
or a server-mode window has neither and renders the app, whose own sign-in applies."""
def:pub BackendGate(children: any) -> JsxElement {
    if backend.choices() and backend.current() is None {
        return <BackendPicker/>;
    }
    if profiles.enabled() and profiles.current() is None {
        return <ProfilePicker/>;
    }
    return <>{children}</>;
}

"""Whether this window runs on local profiles, which replace sign-in."""
def:pub profiles_on -> bool {
    return profiles.enabled();
}

def since(created: float) -> str {
    return "Since " + Date(created * 1000).toLocaleDateString(
        undefined, {"month": "short", "day": "numeric", "year": "numeric"}
    );
}

"""Local profiles, like save slots: each keeps its own reviews, findings, board, and
Copilot threads, and none needs a password."""
def ProfilePicker -> JsxElement {
    has name: str = "",
        busy: str = "",
        error: str = "";
    async def start {
        if not name.strip() {
            error = "Give the profile a name.";
            return;
        }
        busy = "new";
        error = "";
        try {
            await profiles.create(name.strip());
        } except Exception as e {
            error = str(e);
            busy = "";
        }
    }
    async def resume(pid: str) {
        busy = pid;
        try {
            await profiles.use(pid);
        } except Exception as e {
            error = str(e);
            busy = "";
        }
    }
    <div className="grid-bg flex min-h-svh items-center justify-center bg-background p-4 text-foreground">
        <div className="w-full max-w-md">
            <div className="mb-6 flex justify-center">
                <Wordmark/>
            </div>
            <h1 className="text-center text-lg font-semibold tracking-tight">
                {"Continue where you left off" if profiles.choices() else "Start a profile"}
            </h1>
            <p className="mt-1 text-center text-sm text-muted-foreground">
                Each profile keeps its own reviews, findings, and Copilot threads on this computer. No account or password.
            </p>
            {if profiles.choices() {
                <div className="mt-6 space-y-2">
                    {[
                        <button
                            key={p["id"]}
                            type="button"
                            disabled={busy != ""}
                            onClick={lambda { resume(p["id"]); }}
                            className="flex w-full items-center gap-3 rounded-xl border border-border bg-card p-3 text-left shadow-sm transition hover:border-primary/60 hover:bg-muted/40 disabled:opacity-60"
                        >
                            <span className="inline-flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                {(<LoaderCircle className="size-4 animate-spin"/>) if busy == p["id"] else (<UserRound className="size-4"/>)}
                            </span>
                            <span className="min-w-0 flex-1">
                                <span className="block truncate text-sm font-semibold">{p["name"]}</span>
                                <span className="block text-xs text-muted-foreground">{since(p["created"])}</span>
                            </span>
                        </button>
                        for p in profiles.choices()
                    ]}
                </div>
            }}
            <form
                className="mt-4 flex gap-2"
                onSubmit={lambda (e: any) {
                    e.preventDefault();
                    start();
                }}
            >
                <input
                    name="profile"
                    placeholder={"New profile name" if profiles.choices() else "Profile name, e.g. Work"}
                    value={name}
                    onChange={lambda (e: any) { name = e.target.value; }}
                    className="h-10 min-w-0 flex-1 rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none focus:ring-2 focus:ring-primary/40"
                />
                <button
                    type="submit"
                    disabled={busy != ""}
                    className="inline-flex h-10 items-center gap-1.5 rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-60"
                >
                    {(<LoaderCircle className="size-4 animate-spin"/>) if busy == "new" else (<Plus className="size-4"/>)}
                    {"New profile" if profiles.choices() else "Start"}
                </button>
            </form>
            {if error {
                <p role="alert" className="mt-3 text-center text-xs text-[var(--status-critical)]">{error}</p>
            }}
            <div className="mt-6 flex justify-center">
                <ModeSwitch/>
            </div>
        </div>
    </div>
}

def BackendPicker -> JsxElement {
    has busy: str = "",
        error: str = "";
    async def pick(name: str) {
        busy = name;
        error = "";
        try {
            await backend.use(name);
        } except Exception as e {
            error = str(e);
            busy = "";
        }
    }
    <div className="grid-bg flex min-h-svh items-center justify-center bg-background p-4 text-foreground">
        <div className="w-full max-w-2xl">
            <div className="mb-6 flex justify-center">
                <Wordmark/>
            </div>
            <h1 className="text-center text-lg font-semibold tracking-tight">
                How should diffwalker run?
            </h1>
            <p className="mt-1 text-center text-sm text-muted-foreground">
                You can switch later from the sidebar. Each mode keeps its own data.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-2">
                {[
                    <button
                        key={b["name"]}
                        type="button"
                        disabled={busy != ""}
                        onClick={lambda { pick(b["name"]); }}
                        className="flex flex-col items-start gap-2 rounded-2xl border border-border bg-card p-5 text-left shadow-xl transition hover:border-primary/60 hover:bg-muted/40 disabled:opacity-60"
                    >
                        <span className="inline-flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            {(<LoaderCircle className="size-5 animate-spin"/>)
                                if busy == b["name"]
                                else ((<Laptop className="size-5"/>) if b["kind"] == "embedded" else (<Server className="size-5"/>))}
                        </span>
                        <span className="text-sm font-semibold">{backend_label(b)}</span>
                        <span className="text-xs leading-relaxed text-muted-foreground">{backend_blurb(b)}</span>
                    </button>
                    for b in backend.choices()
                ]}
            </div>
            {if error {
                <p role="alert" className="mt-4 text-center text-xs text-[var(--status-critical)]">{error}</p>
            }}
        </div>
    </div>
}

"""The running mode and profile, and switches to the others; nothing outside the desktop app."""
def:pub ModeSwitch -> JsxElement {
    has busy: bool = False;
    current = backend.current();
    profile = profiles.current();
    if current is None and profile is None {
        return <></>;
    }
    others = [b for b in backend.choices() if current is not None and b["name"] != current["name"]];
    async def change_to(name: str) {
        busy = True;
        try {
            await backend.use(name);
        } except Exception {
            busy = False;
        }
    }
    <div className="space-y-1">
        {if current is not None {
            <p className="flex items-center gap-1.5 px-1 text-[11px] text-muted-foreground">
                {(<Laptop className="size-3"/>) if current["kind"] == "embedded" else (<Server className="size-3"/>)}
                <span className="truncate">{backend_label(current)}</span>
            </p>
        }}
        {if profile is not None {
            <button
                type="button"
                disabled={busy}
                onClick={lambda {
                    busy = True;
                    profiles.leave();
                }}
                className="inline-flex w-full items-center gap-1.5 rounded-md px-1.5 py-1 text-left text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground disabled:opacity-60"
            >
                <UserRound className="size-3"/>
                <span className="truncate">{profile["name"] + " · switch profile"}</span>
            </button>
        }}
        {[
            <button
                key={b["name"]}
                type="button"
                disabled={busy}
                onClick={lambda { change_to(b["name"]); }}
                className="inline-flex w-full items-center gap-1.5 rounded-md px-1.5 py-1 text-left text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground disabled:opacity-60"
            >
                {(<LoaderCircle className="size-3 animate-spin"/>) if busy else (<ArrowLeftRight className="size-3"/>)}
                <span className="truncate">{switch_label(b)}</span>
            </button>
            for b in others
        ]}
    </div>
}
