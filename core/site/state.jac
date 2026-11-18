import from "@jac/runtime" { RemoteRejected }

glob _ws: WorkspaceView | None = None,
     _dark: bool = True,
     _pane: bool = True;

async def:pub refresh_workspace -> WorkspaceView | None {
    w: WorkspaceView | None = None;
    try {
        w = await get_workspace();
    } except RemoteRejected {
        signed_out();
        return None;
    } except Exception {
        return None;
    }
    _ws = w;
    publish("workspace", w);
    return w;
}

def:pub useWorkspace -> WorkspaceView | None {
    has ws: WorkspaceView | None = _ws,
        off_ws: Ref[Callable[[], None]] = Ref(),
        off_live: Ref[Callable[[], None]] = Ref();

    async can with entry {
        if not _ws {
            await refresh_workspace();
        }
    }
    can with entry {
        off_ws.current = on_channel("workspace", lambda (w: any) { ws = w; });
        off_live.current = on_live(
            lambda (e: LiveEvent) {
                if e.kind == "data" and e.data.what == "repo" {
                    queueMicrotask(lambda { refresh_workspace() });
                }
            },
        );
    }
    can with exit {
        if off_ws.current {
            off_ws.current();
        }
        if off_live.current {
            off_live.current();
        }
    }
    return ws;
}

def:pub apply_theme(dark: bool) {
    _dark = dark;
    root_el = document.documentElement;
    if dark {
        root_el.classList.add("dark");
    } else {
        root_el.classList.remove("dark");
    }
    try {
        localStorage.setItem("dw-theme", "dark" if dark else "light");
    } except Exception {
        dark = dark;
    }
    publish("theme", dark);
}

def:pub init_theme -> bool {
    saved = "";
    try {
        saved = localStorage.getItem("dw-theme") or "";
    } except Exception {
        saved = "";
    }
    dark = saved != "light";
    apply_theme(dark);
    return dark;
}

def:pub useDark -> bool {
    has dark: bool = _dark,
        off: Ref[Callable[[], None]] = Ref();

    can with entry {
        off.current = on_channel("theme", lambda (d: any) { dark = d; });
    }
    can with exit {
        if off.current {
            off.current();
        }
    }
    return dark;
}

def:pub pane_open -> bool {
    return _pane;
}

def:pub set_pane(open: bool) {
    _pane = open;
    publish("pane", open);
}

def:pub usePane -> bool {
    has open: bool = _pane,
        off: Ref[Callable[[], None]] = Ref();

    can with entry {
        off.current = on_channel("pane", lambda (v: any) { open = v; });
    }
    can with exit {
        if off.current {
            off.current();
        }
    }
    return open;
}

"""Call `reload` shortly after a live event of one of `kinds`: for a pull request's own
events only when `pr_id` names one, and for a review only as it starts and ends."""
def:pub useLiveReload(
    kinds: list[str], reload: Callable[[], Coroutine[any, any, None] | None], pr_id: str = ""
) {
    has off: Ref[Callable[[], None]] = Ref(),
        pending: Ref[any] = Ref(None);

    can with [pr_id] entry {
        off.current = on_live(
            lambda (e: LiveEvent) {
                k = e.kind;
                if k not in kinds {
                    return;
                }
                if pr_id and e.data.pr_id and e.data.pr_id != pr_id {
                    return;
                }
                if k == "review" and e.data.phase not in ("done", "failed", "start") {
                    return;
                }
                if pending.current {
                    clearTimeout(pending.current);
                }
                pending.current = setTimeout(lambda { reload() }, 350);
            },
        );
    }
    can with [pr_id] exit {
        if off.current {
            off.current();
        }
    }
}

glob _pending_ask: str = "";

def:pub ask_copilot(text: str) {
    _pending_ask = text;
    if not _pane {
        set_pane(True);
    }
    publish("copilot-ask", text);
}

def:pub take_pending_ask -> str {
    t = _pending_ask;
    _pending_ask = "";
    return t;
}
