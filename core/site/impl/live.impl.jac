impl rand_id -> str {
    return str(int(Math.random() * 1000000000));
}

impl session_id -> str {
    if not _session {
        existing = "";
        try {
            existing = sessionStorage.getItem("dw-session") or "";
        } except Exception {
            existing = "";
        }
        if existing {
            _session = existing;
        } else {
            _session = "w-" + rand_id();
            try {
                sessionStorage.setItem("dw-session", _session);
            } except Exception {
                _session = _session;
            }
        }
    }
    return _session;
}

impl thread_id -> str {
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

impl new_thread -> str {
    tid = "t-" + rand_id();
    try {
        localStorage.setItem("dw-thread", tid);
    } except Exception {
        tid = tid;
    }
    return tid;
}

impl live_status -> str {
    return _status;
}

impl on_live(handler: Callable[[LiveEvent], None]) -> Callable[[], None] {
    _listeners.append(handler);
    return lambda {
        if handler in _listeners {
            _listeners.remove(handler);
        }
    };
}

impl publish(channel: str, payload: any) {
    subs = list(_channels.get(channel, []));
    for fn in subs {
        try {
            fn(payload);
        } except Exception as e {
            console.error("[channel]", channel, e);
        }
    }
}

impl on_channel(channel: str, handler: Callable[[any], None]) -> Callable[[], None] {
    if channel not in _channels {
        _channels[channel] = [];
    }
    _channels[channel].append(handler);
    return lambda {
        subs = _channels.get(channel, []);
        if handler in subs {
            subs.remove(handler);
        }
    };
}

impl _dispatch(evt: LiveEvent) {
    if evt.seq > _seq {
        _seq = evt.seq;
    }
    for fn in list(_listeners) {
        try {
            fn(evt);
        } except Exception as e {
            console.error("[live] handler", e);
        }
    }
}

impl signed_out {
    if profiles_on() {
        last = 0;
        try {
            last = int(sessionStorage.getItem("dw-reauth") or "0");
        } except Exception {
            last = 0;
        }
        now = Date.now();
        if now - last < 30000 {
            queueMicrotask(lambda { leave_profile() });
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

impl start_live {
    if _started {
        return;
    }
    _started = True;
    while jacIsLoggedIn() {
        try {
            _status = "live";
            publish("live-status", "live");
            async for evt in live(max(0, _seq)) {
                _dispatch(evt);
            }
        } except RemoteRejected {
            signed_out();
        } except Exception as e {
            console.warn("[live] reconnecting", e);
        }
        _status = "reconnecting";
        publish("live-status", "reconnecting");
        await new(Promise, lambda (resolve: any) { setTimeout(resolve, 1500) });
    }
    _started = False;
}

impl toast(message: str, tone: str = "info") {
    publish("toast", Toast(message=message, tone=tone, id=rand_id()));
}
