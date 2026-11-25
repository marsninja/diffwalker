import os;
import json;
import time;
import logging;
import threading;
import subprocess;
import from stdjac { ByEnd, ByEvent, ByEventKind, ByUsage, commit, latest_turns }

glob _env_loaded: int = load_env(),
     _warmed: set[str] = set(),
     _warm_lock: threading.Lock = threading.Lock(),
     SNIPPET_FILES: list[str] = ["jac.toml", "README.md", "archwire.jac"];

def _default_repo -> str;
def active_repo -> str;

def _rows(repo: str) -> list[PRRow];

def _brief(rv: Review) -> ReviewBrief;

def _view(rv: Review) -> ReviewView;
def _settle(reviews: list[Review]);

def:pub server_info -> ServerInfo;

def:protect get_workspace -> WorkspaceView;

def:protect set_repository(path: str) -> WorkspaceView;

def:protect list_reviews(refresh: bool) -> list[PRRow];

def:protect dashboard -> DashboardView;
def:protect pr_detail(pr_id: str, review_id: str) -> PRDetail;
def:protect start_review(pr_id: str, focus: str, session: str) -> ReviewBrief;

def:protect set_finding_status(finding_id: str, status: str, note: str) -> Finding | None;

def:protect reply_finding(finding_id: str, text: str) -> Finding | None;

def:protect add_comment(
    pr_id: str,
    path: str,
    line: int,
    severity: str,
    category: str,
    title: str,
    body: str,
    suggestion: str,
) -> Finding | None;

def:protect export_markdown(pr_id: str) -> str;

def _post_to_github(slug: str, number: int, body: str, pr_id: str, user: str);

def _toast(message: str, tone: str, user: str);
def:protect publish_review(pr_id: str) -> str;

def:protect activity_view -> ActivityView;

def:protect hotspots_view(limit: int) -> list[Hotspot];

def:protect people_view -> PeopleView;

def:protect structure_view -> StructureView;

def:protect coupling_view -> CouplingGraph;

def:protect board -> list[Insight];

def:protect pin_card(title: str, kind: str, caption: str, spec: str) -> Insight;

def:protect unpin_card(insight_id: str) -> bool;

def:protect chat_history(thread_id: str) -> list[ChatMsg];

def:protect clear_chat(thread_id: str) -> bool;

def:protect stop_turn(thread_id: str) -> bool;

glob ENDED: dict[ByEnd, str] = {
    ByEnd.STOPPED: "Stopped: wrapping up with what I have.",
    ByEnd.ROUNDS: "Out of steps for this turn: wrapping up with what I have.",
    ByEnd.CUT: "The answer was cut at its length limit.",
};
def _frame(ev: ByEvent, reply: ChatReply, spent: ByUsage) -> CopilotFrame | None;
def _turn(
    thread_id: str, message: str, ui_state: str, session: str, reply: ChatReply
) -> Iterator[CopilotFrame];
def:protect copilot_stream(
    thread_id: str, message: str, ui_state: str, session: str
) -> Iterator[CopilotFrame];
def:protect copilot_ask(thread_id: str, message: str, ui_state: str, session: str) -> ChatReply;
def:protect live(after: int) -> Iterator[LiveEvent];
def:protect source_snippet(path: str, needle: str, before: int, after: int) -> CodeSnippet;

def:protect build_stats -> BuildStats;
