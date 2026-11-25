import threading;
import time;
import contextvars;

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

def current_user -> str;

def set_session(session: str);

def current_session -> str;

def tap(fn: Callable[[LiveEvent], None]);

def emit(kind: str, data: LiveData, session: str = "", user: str = "") -> LiveEvent;

def latest_seq -> int;

def events_after(user: str, after: int, limit: int = 200) -> list[LiveEvent];

def wait_events(user: str, after: int, timeout: float) -> list[LiveEvent];
def ui(action: str, args: UiArgs);
def changed(what: str, pr_id: str = "", id: str = "", path: str = "", url: str = "");
