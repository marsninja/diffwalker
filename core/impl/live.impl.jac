impl current_user -> str {
    try {
        return jid(root);
    } except Exception {
        return "";
    }
}

impl set_session(session: str) {
    _session.set(session);
}

impl current_session -> str {
    return _session.get();
}

impl tap(fn: Callable[[LiveEvent], None]) {
    _taps.append(fn);
}

impl emit(kind: str, data: LiveData, session: str = "", user: str = "") -> LiveEvent {
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

impl latest_seq -> int {
    return _seq;
}

impl events_after(user: str, after: int, limit: int = 200) -> list[LiveEvent] {
    with _cond {
        return [l.event for l in _log if l.event.seq > after and l.user == user][:limit];
    }
}

impl wait_events(user: str, after: int, timeout: float) -> list[LiveEvent] {
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

impl ui(action: str, args: UiArgs) {
    emit("ui", LiveData(action=action, args=args));
}

impl changed(what: str, pr_id: str = "", id: str = "", path: str = "", url: str = "") {
    emit("data", LiveData(what=what, pr_id=pr_id, id=id, path=path, url=url));
}
