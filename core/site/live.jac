import from "@jac/runtime" { jacLogout, jacIsLoggedIn }
import from "@jac/desktop" { profiles }

glob NL: str = chr(10),
     _session: list[str] = [""],
     _seq: list[int] = [0],
     _started: list[bool] = [False],
     _listeners: list[any] = [],
     _channels: dict[str, list[any]] = {},
     _status: list[str] = ["connecting"];

def:pub rand_id -> str {
    return str(int(Math.random() * 1000000000));
}

def:pub session_id -> str {
    if not _session[0] {
        existing = "";
        try {
            existing = sessionStorage.getItem("dw-session") or "";
        } except Exception {
            existing = "";
        }
        if existing {
            _session[0] = existing;
        } else {
            _session[0] = "w-" + rand_id();
            try {
                sessionStorage.setItem("dw-session", _session[0]);
            } except Exception {
                _session[0] = _session[0];
            }
        }
    }
    return _session[0];
}

def:pub thread_id -> str {
    tid = "";
    try {
        tid = localStorage.getItem("dw-thread") or "";
    } except Exception {
        tid = "";
    }
    if not tid {
        tid = "t-" + rand_id();
        try {
            localStorage.setItem("dw-thread", tid);
        } except Exception {
            tid = tid;
        }
    }
    return tid;
}

def:pub new_thread -> str {
    tid = "t-" + rand_id();
    try {
        localStorage.setItem("dw-thread", tid);
    } except Exception {
        tid = tid;
    }
    return tid;
}

def:pub live_status -> str {
    return _status[0];
}

def:pub on_live(handler: any) -> any {
    _listeners.append(handler);
    return lambda { if handler in _listeners { _listeners.remove(handler); }};
}

def:pub publish(channel: str, payload: any) {
    subs = list(_channels[channel] or []);
    for fn in subs {
        try {
            fn.call(None, payload);
        } except Exception as e {
            console.error("[channel]", channel, e);
        }
    }
}

def:pub on_channel(channel: str, handler: any) -> any {
    if not _channels[channel] {
        _channels[channel] = [];
    }
    _channels[channel].append(handler);
    return lambda {
        subs = _channels[channel] or [];
        if handler in subs {
            subs.remove(handler);
        }
    };
}

def _dispatch(evt: any) {
    if evt.seq and evt.seq > _seq[0] {
        _seq[0] = evt.seq;
    }
    for fn in list(_listeners) {
        try {
            fn.call(None, evt);
        } except Exception as e {
            console.error("[live] handler", e);
        }
    }
}

"""Headers for a raw fetch to a `def:protect` endpoint: the jac client keeps its session token in localStorage."""
def:pub auth_headers -> dict[str, str] {
    headers: dict[str, str] = {"Content-Type": "application/json"};
    token = "";
    try {
        token = localStorage.getItem("jac_token") or "";
    } except Exception {
        token = "";
    }
    if token {
        headers["Authorization"] = "Bearer " + token;
    }
    return headers;
}

"""A rejected session. On local profiles there is no sign-in to return to: reload, and
the desktop host signs the page in again as the active profile; a second rejection
within half a minute leaves the profile instead of looping."""
def:pub signed_out {
    if profiles.enabled() {
        last = 0;
        try {
            last = int(sessionStorage.getItem("dw-reauth") or "0");
        } except Exception {
            last = 0;
        }
        now = Date.now();
        if now - last < 30000 {
            profiles.leave();
            return;
        }
        sessionStorage.setItem("dw-reauth", str(now));
        window.location.reload();
        return;
    }
    jacLogout();
    publish("signed-out", True);
    if not window.location.pathname.startswith("/login") {
        window.location.assign("/login");
    }
}

async def:pub read_sse(url: str, body: any, on_frame: any) -> bool {
    resp = await fetch(
        url,
        {
            "method": "POST",
            "headers": auth_headers(),
            "body": JSON.stringify(body)
        }
    );
    if resp.status == 401 {
        signed_out();
        return False;
    }
    if not resp.ok or not resp.body {
        return False;
    }
    reader = resp.body.getReader();
    decoder = new(TextDecoder);
    buf = "";
    feeding = True;
    while feeding {
        part = await reader.read();
        if part.done {
            feeding = False;
            continue;
        }
        buf = buf + decoder.decode(part.value, {"stream": True});
        frames = buf.split(NL + NL);
        buf = frames.pop();
        for frame in frames {
            if frame.startswith("event:") {
                continue;
            }
            for line in frame.split(NL) {
                if line.startswith("data: ") {
                    try {
                        on_frame.call(None, JSON.parse(line[6:]));
                    } except Exception as e {
                        console.error("[sse] frame", e);
                    }
                }
            }
        }
    }
    return True;
}

async def:pub start_live {
    if _started[0] {
        return;
    }
    _started[0] = True;
    while jacIsLoggedIn() {
        try {
            _status[0] = "live";
            publish("live-status", "live");
            await read_sse("/function/live", {"after": max(0, _seq[0])}, _dispatch);
        } except Exception as e {
            console.warn("[live] reconnecting", e);
        }
        _status[0] = "reconnecting";
        publish("live-status", "reconnecting");
        await new(Promise, lambda (resolve: any) { setTimeout(resolve, 1500); });
    }
    _started[0] = False;
}

def:pub toast(message: str, tone: str = "info") {
    publish("toast", {"message": message, "tone": tone, "id": rand_id()});
}
