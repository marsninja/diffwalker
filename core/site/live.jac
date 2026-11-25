import from "@jac/runtime" { RemoteRejected, jacIsLoggedIn, jacLogout }

obj Toast {
    has message: str,
        tone: str,
        id: str;
}

glob _session: str = "",
     _seq: int = 0,
     _started: bool = False,
     _listeners: list[Callable[[LiveEvent], None]] = [],
     _channels: dict[str, list[Callable[[any], None]]] = {},
     _status: str = "connecting";

def:pub rand_id -> str;

def:pub session_id -> str;

def:pub thread_id -> str;

def:pub new_thread -> str;

def:pub live_status -> str;
def:pub on_live(handler: Callable[[LiveEvent], None]) -> Callable[[], None];

def:pub publish(channel: str, payload: any);
def:pub on_channel(channel: str, handler: Callable[[any], None]) -> Callable[[], None];

def _dispatch(evt: LiveEvent);
def:pub signed_out;
async def:pub start_live;

def:pub toast(message: str, tone: str = "info");
