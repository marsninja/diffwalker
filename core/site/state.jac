import from "@jac/runtime" { RemoteRejected }

glob _ws: WorkspaceView | None = None,
     _dark: bool = True,
     _pane: bool = True;

async def:pub refresh_workspace -> WorkspaceView | None;

def:pub useWorkspace -> WorkspaceView | None;

def:pub apply_theme(dark: bool);

def:pub init_theme -> bool;

def:pub useDark -> bool;

def:pub pane_open -> bool;

def:pub set_pane(open: bool);

def:pub usePane -> bool;
def:pub useLiveReload(
    kinds: list[str], reload: Callable[[], Coroutine[any, any, None] | None], pr_id: str = ""
);

glob _pending_ask: str = "";

def:pub ask_copilot(text: str);

def:pub take_pending_ask -> str;
