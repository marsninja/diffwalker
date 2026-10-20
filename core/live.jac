import threading;
import time;
import contextvars;

"""In-process event log behind the `live` stream.

Every event is tagged with the user (the caller's root id) and the browser or CLI
session that caused it; a subscriber only ever reads its own user's events. The log
lives in this process, which is why jac.toml pins `[serve.workers] count = 1`: a
streaming request cannot see other requests' commits to the graph (see
jaseci-labs/jac#10234), so durable state cannot carry the push channel yet.
"""
glob _log: list[dict[str, any]] = [],
     _seq: list[int] = [0],
     _cond: any = threading.Condition(),
     MAX_LOG: int = 2000,
     _session: any = contextvars.ContextVar("diffwalker_session", `default=""),
     _taps: list[Callable[[dict[str, any]], None]] = [];

def current_user -> str {
    try {
        return jid(root);
    } except Exception {
        return "";
    }
}

def set_session(session: str) {
    _session.set(session or "");
}

def current_session -> str {
    return _session.get();
}

def tap(fn: Callable[[dict[str, any]], None]) {
    _taps.append(fn);
}

def emit(
    kind: str, data: dict[str, any], session: str = "", user: str = ""
) -> dict[str, any] {
    who = user or current_user();
    with _cond {
        _seq[0] = _seq[0] + 1;
        evt = {
            "seq": _seq[0],
            "kind": kind,
            "user": who,
            "session": session or _session.get(),
            "data": data,
            "ts": time.time()
        };
        _log.append(evt);
        if len(_log) > MAX_LOG {
            del _log[:len(_log) - MAX_LOG];
        }
        _cond.notify_all();
    }
    for fn in list(_taps) {
        try {
            fn(evt);
        } except Exception as e {
            print("diffwalker: event tap failed:", e);
        }
    }
    return evt;
}

def latest_seq -> int {
    return _seq[0];
}

def _public(e: dict[str, any]) -> dict[str, any] {
    return {k: v for (k, v) in e.items() if k != "user"};
}

def events_after(user: str, after: int, limit: int = 200) -> list[dict[str, any]] {
    with _cond {
        return [
            _public(e)
            for e in _log
            if e["seq"] > after and e["user"] == user
        ][:limit];
    }
}

def wait_events(user: str, after: int, timeout: float) -> list[dict[str, any]] {
    deadline = time.time() + timeout;
    with _cond {
        while True {
            fresh = [
                _public(e)
                for e in _log
                if e["seq"] > after and e["user"] == user
            ];
            if fresh {
                return fresh[:200];
            }
            left = deadline - time.time();
            if left <= 0 {
                return [];
            }
            _cond.wait(left);
        }
    }
}

"""Ask every screen of the current user to do something (navigate, filter, toast, ...)."""
def ui(action: str, args: dict[str, any]) {
    emit("ui", {"action": action, "args": args});
}

"""Tell every screen of the current user that data changed."""
def changed(what: str, data: dict[str, any]) {
    emit("data", {"what": what} | data);
}
