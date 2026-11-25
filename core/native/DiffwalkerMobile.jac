import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    ScrollView,
    TextInput,
    ActivityIndicator,
    useWindowDimensions,
}
import from "@jac/runtime" { jacLogin, jacSignup, jacIsLoggedIn, jacLogout }

obj Tab {
    has key: str,
        label: str,
        icon: str;
}

obj Msg {
    has role: str,
        text: str,
        tools: list[str] = [];
}

glob TABS: list[Tab] = [
         Tab(key="inbox", label="Inbox", icon="inbox"),
         Tab(key="review", label="Review", icon="review"),
         Tab(key="insights", label="Insights", icon="insights"),
         Tab(key="copilot", label="Copilot", icon="copilot"),
     ],
     VERDICT_TEXT: dict[str, str] = {
         "approve": "Approve",
         "comment": "Comment",
         "request_changes": "Changes requested",
     },
     STAGE_ORDER: list[str] = [
         "ingest",
         "triage",
         "plan",
         "review",
         "cross",
         "investigate",
         "verify",
         "synthesize",
     ],
     QUICK: list[str] = [
         "Which pull request is riskiest right now?",
         "Summarize the open findings for me",
         "What are this repo's hotspots?",
     ];

def short(n: int) -> str;

def mobile_session -> str;

def plain(md: str) -> str;

def Pill(label: str, tone: str, icon: str = "") -> JsxElement;

def RiskBar(score: int) -> JsxElement;

def KindIcon(kind: str) -> JsxElement;

def PRCard(row: PRRow, onOpen: Callable[[str], Coroutine[any, any, None]]) -> JsxElement;

def InboxScreen(
    rows: list[PRRow],
    loading: bool,
    onOpen: Callable[[str], Coroutine[any, any, None]],
    onRefresh: Callable[[], Coroutine[any, any, None]],
) -> JsxElement;

def StageRow(stage: StageState) -> JsxElement;

def FindingRow(f: Finding, onStatus: Callable[[str, str], Coroutine[any, any, None]]) -> JsxElement;

def ReviewScreen(
    detail: PRDetail | None,
    loading: bool,
    busy: bool,
    onRun: Callable[[], Coroutine[any, any, None]],
    onStatus: Callable[[str, str], Coroutine[any, any, None]],
    onBack: Callable[[], None],
) -> JsxElement;

def MiniBars(values: list[float], tone: str) -> JsxElement;

def InsightsScreen(data: DashboardView | None) -> JsxElement;

def CopilotScreen(
    msgs: list[Msg],
    draft: str,
    busy: bool,
    onDraft: Callable[[str], None],
    onSend: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;

def TabBar(active: str, onPick: Callable[[str], Coroutine[any, any, None]]) -> JsxElement;
def SignInScreen(onDone: Callable[[], None]) -> JsxElement;

def DiffwalkerMobile(embedded: bool = False) -> JsxElement;
