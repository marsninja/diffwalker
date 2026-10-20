glob _ws: list[any] = [None],
     _dark: list[bool] = [True],
     _pane: list[bool] = [True];

async def:pub refresh_workspace -> any {
    w: any = None;
    try {
        w = await get_workspace();
    } except Exception as e {
        if "UNAUTHORIZED" in str(e) {
            signed_out();
        }
        return None;
    }
    _ws[0] = w;
    publish("workspace", w);
    return w;
}

def:pub useWorkspace -> any {
    has ws: any = _ws[0];
    async can with entry {
        if not _ws[0] {
            await refresh_workspace();
        }
    }
    can with entry {
        off_ws = on_channel("workspace", lambda (w: any) { ws = w; });
        off_live = on_live(
            lambda (e: any) { if e.kind == "data" and e.data and e.data.what == "repo" {
                refresh_workspace();
            }}
        );
        return lambda {
            off_ws();
            off_live();
        };
    }
    return ws;
}

def:pub apply_theme(dark: bool) {
    _dark[0] = dark;
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
    has dark: bool = _dark[0];
    can with entry {
        off = on_channel("theme", lambda (d: bool) { dark = d; });
        return lambda { off(); };
    }
    return dark;
}

def:pub pane_open -> bool {
    return _pane[0];
}

def:pub set_pane(open: bool) {
    _pane[0] = open;
    publish("pane", open);
}

def:pub usePane -> bool {
    has open: bool = _pane[0];
    can with entry {
        off = on_channel("pane", lambda (v: bool) { open = v; });
        return lambda { off(); };
    }
    return open;
}

def:pub useLiveReload(kinds: list[str], reload: any, pr_id: str = "") {
    can with [pr_id] entry {
        pending: list[any] = [None];
        off = on_live(
            lambda (e: any) {
                k = e.kind;
                if k not in kinds {
                    return;
                }
                if pr_id and e.data and e.data.pr_id and e.data.pr_id != pr_id {
                    return;
                }
                if k == "review"
                    and e.data
                    and e.data.phase not in ("done", "failed", "start") {
                    return;
                }
                if pending[0] {
                    clearTimeout(pending[0]);
                }
                pending[0] = setTimeout(lambda { reload(); }, 350);
            }
        );
        return lambda { off(); };
    }
}

glob _pending_ask: list[str] = [""];

def:pub ask_copilot(text: str) {
    _pending_ask[0] = text;
    if not _pane[0] {
        set_pane(True);
    }
    publish("copilot-ask", text);
}

def:pub take_pending_ask -> str {
    t = _pending_ask[0];
    _pending_ask[0] = "";
    return t;
}
