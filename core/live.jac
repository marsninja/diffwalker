"""In-process event log behind the `live` stream.

Every event is tagged with the user (the caller's root id) and the browser or CLI
session that caused it; a subscriber only ever reads its own user's events. The server
answers its calls on threads of one process, so the log is this module's own state,
guarded by its condition.
"""
import threading;
import time;
import contextvars;

"""An event as the log keeps it: with the user it belongs to, which no subscriber is sent."""
obj Logged {
    has user: str,
        event: LiveEvent;
}

glob _log: list[Logged] = [],
     _seq: int = 0,
     _cond: threading.Condition = threading.Condition(),
     MAX_LOG: int = 2000,
     _session: contextvars.ContextVar[str] = contextvars.ContextVar(
         "diffwalker_session", default=""
     ),
     _taps: list[Callable[[LiveEvent], None]] = [];

def current_user -> str {
    try {
        return jid(root);
    } except Exception {
        return "";
    }
}

def set_session(session: str) {
    _session.set(session);
}

def current_session -> str {
    return _session.get();
}

def tap(fn: Callable[[LiveEvent], None]) {
    _taps.append(fn);
}

def emit(kind: str, data: LiveData, session: str = "", user: str = "") -> LiveEvent {
    who = user or current_user();
    with _cond {
        _seq += 1;
        evt = LiveEvent(
            seq=_seq, kind=kind, session=session or _session.get(), data=data, ts=time.time()
        );
        _log.append(Logged(user=who, event=evt));
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
    return _seq;
}

def events_after(user: str, after: int, limit: int = 200) -> list[LiveEvent] {
    with _cond {
        return [l.event for l in _log if l.event.seq > after and l.user == user][:limit];
    }
}

def wait_events(user: str, after: int, timeout: float) -> list[LiveEvent] {
    deadline = time.time() + timeout;
    with _cond {
        while True {
            fresh = [l.event for l in _log if l.event.seq > after and l.user == user];
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
def ui(action: str, args: UiArgs) {
    emit("ui", LiveData(action=action, args=args));
}

"""Tell every screen of the current user that data changed: `what`, and which of it."""
def changed(what: str, pr_id: str = "", id: str = "", path: str = "", url: str = "") {
    emit("data", LiveData(what=what, pr_id=pr_id, id=id, path=path, url=url));
}
