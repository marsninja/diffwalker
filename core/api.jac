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

def:prot get_workspace -> WorkspaceView;

def:prot set_repository(path: str) -> WorkspaceView;

def:prot list_reviews(refresh: bool) -> list[PRRow];

def:prot dashboard -> DashboardView;
def:prot pr_detail(pr_id: str, review_id: str) -> PRDetail;
def:prot start_review(pr_id: str, focus: str, session: str) -> ReviewBrief;

def:prot set_finding_status(finding_id: str, status: str, note: str) -> Finding | None;

def:prot reply_finding(finding_id: str, text: str) -> Finding | None;

def:prot add_comment(
    pr_id: str,
    path: str,
    line: int,
    severity: str,
    category: str,
    title: str,
    body: str,
    suggestion: str,
) -> Finding | None;

def:prot export_markdown(pr_id: str) -> str;

def _post_to_github(slug: str, number: int, body: str, pr_id: str, user: str);

def _toast(message: str, tone: str, user: str);
def:prot publish_review(pr_id: str) -> str;

def:prot activity_view -> ActivityView;

def:prot hotspots_view(limit: int) -> list[Hotspot];

def:prot people_view -> PeopleView;

def:prot structure_view -> StructureView;

def:prot coupling_view -> CouplingGraph;

def:prot board -> list[Insight];

def:prot pin_card(title: str, kind: str, caption: str, spec: str) -> Insight;

def:prot unpin_card(insight_id: str) -> bool;

def:prot chat_history(thread_id: str) -> list[ChatMsg];

def:prot clear_chat(thread_id: str) -> bool;

def:prot stop_turn(thread_id: str) -> bool;

glob ENDED: dict[ByEnd, str] = {
    ByEnd.STOPPED: "Stopped: wrapping up with what I have.",
    ByEnd.ROUNDS: "Out of steps for this turn: wrapping up with what I have.",
    ByEnd.CUT: "The answer was cut at its length limit.",
};
def _frame(ev: ByEvent, reply: ChatReply, spent: ByUsage) -> CopilotFrame | None;
def _turn(
    thread_id: str, message: str, ui_state: str, session: str, reply: ChatReply
) -> Iterator[CopilotFrame];
def:prot copilot_stream(
    thread_id: str, message: str, ui_state: str, session: str
) -> Iterator[CopilotFrame];
def:prot copilot_ask(thread_id: str, message: str, ui_state: str, session: str) -> ChatReply;
def:prot live(after: int) -> Iterator[LiveEvent];
def:prot source_snippet(path: str, needle: str, before: int, after: int) -> CodeSnippet;

def:prot build_stats -> BuildStats;
