impl SignIn -> JsxElement {
    nav = useNavigate();
    has mode: str = "signin",
        name: str = "",
        password: str = "",
        busy: bool = False,
        error: str = "",
        info: ServerInfo | None = None;
    async can with entry {
        try {
            info = await server_info();
        } except Exception {
            info = None;
        }
    }
    async def submit(e: any) {
        e.preventDefault();
        ok: bool = False;
        if not name.strip() or not password {
            error = "Enter a username and a password.";
            return;
        }
        busy = True;
        error = "";
        try {
            if mode == "signup" {
                made = await jacSignup(name.strip(), password);
                if not made.success {
                    error = made.error or "Could not create the account.";
                    busy = False;
                    return;
                }
            }
            ok = await jacLogin(name.strip(), password);
        } except Exception as err {
            error = "The server did not answer: " + str(err);
        }
        busy = False;
        if ok {
            nav("/", {"replace": True});
        } elif not error {
            error = "Wrong username or password.";
        }
    }
    if jacIsLoggedIn() {
        return <Navigate to="/" replace={True} />;
    }
    return <div
        className="grid-bg flex min-h-svh items-center justify-center bg-background p-4 text-foreground"
    >
        <div className="w-full max-w-sm">
            <div className="mb-6 flex justify-center"><Wordmark /></div>
            <div className="rounded-2xl border border-border bg-card p-6 shadow-xl">
                <h1 className="text-lg font-semibold tracking-tight">
                    {"Create your account" if mode == "signup" else "Sign in"}
                </h1>
                <p className="mt-1 text-sm text-muted-foreground">
                    Your reviews, findings, and Copilot threads are private to your account.
                </p>
                <form className="mt-5 space-y-3" onSubmit={submit}>
                    <label className="block text-xs font-medium text-muted-foreground">
                        Username
                        <input
                        name="username"
                        autoComplete="username"
                        value={name}
                        onChange={lambda (e: any) { name = e.target.value; }}
                        className="mt-1 h-10 w-full rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none focus:ring-2 focus:ring-primary/40"
                    /></label>
                    <label className="block text-xs font-medium text-muted-foreground">
                        Password
                        <input
                        name="password"
                        type="password"
                        autoComplete={"new-password" if mode == "signup" else "current-password"}
                        value={password}
                        onChange={lambda (e: any) { password = e.target.value; }}
                        className="mt-1 h-10 w-full rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none focus:ring-2 focus:ring-primary/40"
                    /></label>
                    {
                        if error {
                            <p role="alert" className="text-xs text-[var(--status-critical)]">
                                {error}
                            </p>
                        }
                    }
                    <button
                        type="submit"
                        disabled={busy}
                        className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg bg-primary text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-60"
                    >
                        {(<LoaderCircle className="size-4 animate-spin" />)
                            if busy
                            else (
                                (<UserPlus className="size-4" />)
                                    if mode == "signup"
                                    else (<LogIn className="size-4" />)
                            )}
                        {"Create account" if mode == "signup" else "Sign in"}
                    </button>
                </form>
                <button
                    type="button"
                    onClick={lambda {
                        mode = "signin" if mode == "signup" else "signup";
                        error = "";
                    }}
                    className="mt-4 w-full text-center text-xs text-muted-foreground hover:text-foreground"
                >
                    {"Already have an account? Sign in"
                        if mode == "signup"
                        else "New here? Create an account"}
                </button>
            </div>
            {
                if info {
                    <div
                        className="mt-4 flex items-center justify-center gap-1.5 text-[11px] text-muted-foreground"
                    >
                        <ShieldCheck className="size-3.5 text-primary" />
                        {"Reviewer model "
                            + info.model
                            + (" · ready" if info.llm else " · credentials missing")}
                    </div>
                }
            }
            <div className="mt-4 flex justify-center"><ModeSwitch /></div>
        </div>
    </div>;
}
