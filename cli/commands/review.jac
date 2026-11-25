import json;
import threading;
import from stdjac { RemoteError, RemoteRejected }

glob STAGE_GLYPH: dict[str, str] = {"running": "◌", "done": "✓", "failed": "✗", "skipped": "–"};
def show_event(evt: LiveEvent, pr_id: str) -> bool;

def print_result(review_id: str, as_json: bool) -> int;

def run_review_offline(repo: str, pr_id: str, focus: str, as_json: bool) -> int;

obj Started {
    has brief: ReviewBrief | None = None,
        error: str = "",
        rejected: bool = False;
}

def start_on_server(pr_id: str, focus: str, session: str, started: Started);
def run_review_live(server: str, pr_id: str, focus: str) -> int;
