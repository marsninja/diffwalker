obj RepoInfo {
    has path: str = "",
        name: str = "",
        branch: str = "",
        head: str = "",
        base: str = "",
        remote: str = "",
        github: str = "",
        commits: int = 0,
        files: int = 0,
        contributors: int = 0,
        first_commit: str = "",
        last_commit: str = "",
        is_git: bool = False,
        error: str = "";
}

obj PullRequestRef {
    has id: str = "",
        kind: str = "branch",
        number: int = 0,
        title: str = "",
        head: str = "",
        base: str = "",
        author: str = "",
        updated: str = "",
        updated_ts: int = 0,
        ahead: int = 0,
        behind: int = 0,
        files_changed: int = 0,
        additions: int = 0,
        deletions: int = 0,
        url: str = "",
        state: str = "open",
        body: str = "";
}

obj CommitInfo {
    has sha: str = "",
        author: str = "",
        ts: int = 0,
        subject: str = "";
}

obj DiffLine {
    has kind: str = "ctx",
        old_no: int = 0,
        new_no: int = 0,
        text: str = "";
}

obj Hunk {
    has header: str = "",
        old_start: int = 0,
        old_len: int = 0,
        new_start: int = 0,
        new_len: int = 0,
        lines: list[DiffLine] = [];
}

obj FileDiff {
    has path: str = "",
        old_path: str = "",
        status: str = "modified",
        additions: int = 0,
        deletions: int = 0,
        binary: bool = False,
        language: str = "",
        hunks: list[Hunk] = [],
        truncated: bool = False;
}

obj FileRisk {
    has path: str = "",
        score: int = 0,
        kind: str = "code",
        signals: list[str] = [],
        additions: int = 0,
        deletions: int = 0,
        language: str = "";
}

obj Reply {
    has author: str = "",
        text: str = "",
        ts: float = 0.0;
}

obj StageState {
    has key: str = "",
        label: str = "",
        status: str = "pending",
        detail: str = "",
        started: float = 0.0,
        finished: float = 0.0;
}

obj StageCost {
    has stage: str = "",
        calls: int = 0,
        tokens: int = 0,
        cached: int = 0,
        cost: float = 0.0,
        ms: float = 0.0;
}

obj FeedItem {
    has kind: str = "info",
        title: str = "",
        detail: str = "",
        ts: float = 0.0;
}

obj ToolTrace {
    has tool: str = "",
        args: str = "",
        result: str = "",
        ok: bool = True;
}

obj ChatMsg {
    has role: str = "user",
        text: str = "",
        ts: float = 0.0,
        tools: list[ToolTrace] = [],
        cards: list[Card] = [],
        tokens: int = 0,
        cost: float = 0.0;
}

node Finding {
    has id: str = "",
        review_id: str = "",
        pr_id: str = "",
        path: str = "",
        line: int = 0,
        end_line: int = 0,
        severity: str = "medium",
        category: str = "correctness",
        title: str = "",
        body: str = "",
        suggestion: str = "",
        evidence: str = "",
        confidence: float = 0.7,
        status: str = "open",
        source: str = "agent",
        verified: bool = False,
        verifier_note: str = "",
        looked_at: list[str] = [],
        anchored: bool = True,
        created: float = 0.0,
        replies: list[Reply] = [];
}

node Insight {
    has id: str = "",
        title: str = "",
        kind: str = "bar",
        caption: str = "",
        spec: str = "{}",
        created: float = 0.0,
        pinned: bool = True,
        prompt: str = "";
}

obj DayCount {
    has day: str = "",
        count: int = 0;
}

obj WeekBucket {
    has week: str = "",
        commits: int = 0,
        additions: int = 0,
        deletions: int = 0;
}

obj KindMonth {
    has month: str = "",
        counts: dict[str, int] = {};
}

obj Hotspot {
    has path: str = "",
        changes: int = 0,
        churn: int = 0,
        authors: int = 0,
        size: int = 0,
        language: str = "",
        last_ts: int = 0,
        score: float = 0.0;
}

obj Contributor {
    has name: str = "",
        commits: int = 0,
        additions: int = 0,
        deletions: int = 0,
        files: int = 0,
        first_ts: int = 0,
        last_ts: int = 0,
        top_area: str = "";
}

obj Ownership {
    has area: str = "",
        owner: str = "",
        share: float = 0.0,
        commits: int = 0,
        authors: int = 0;
}

obj LangSlice {
    has language: str = "",
        size: int = 0,
        files: int = 0;
}

obj TreeCell {
    has path: str = "",
        size: int = 0,
        files: int = 0,
        language: str = "",
        churn: int = 0;
}

obj CouplingNode {
    has id: str = "",
        changes: int = 0,
        area: str = "";
}

obj CouplingEdge {
    has a: str = "",
        b: str = "",
        weight: int = 0,
        strength: float = 0.0;
}

obj CouplingGraph {
    has nodes: list[CouplingNode] = [],
        edges: list[CouplingEdge] = [];
}

obj RepoStats {
    has commits_90d: int = 0,
        authors_90d: int = 0,
        additions_90d: int = 0,
        deletions_90d: int = 0,
        busiest_day: str = "",
        busiest_count: int = 0,
        streak_days: int = 0,
        median_commit_size: int = 0,
        bus_factor: int = 0,
        test_ratio: float = 0.0;
}

obj ServerInfo {
    has llm: bool = False,
        model: str = "",
        gh: bool = False;
}

obj WorkspaceView {
    has repo: RepoInfo = RepoInfo(),
        recent: list[str] = [],
        llm: bool = False,
        model: str = "",
        gh: bool = False,
        seq: int = 0,
        error: str = "";
}

obj PRRow {
    has pr: PullRequestRef = PullRequestRef(),
        verdict: str = "",
        risk: int = -1,
        open_findings: int = 0,
        last_review: str = "",
        reviewing: bool = False;
}

obj ReviewBrief {
    has id: str = "",
        status: str = "",
        verdict: str = "",
        risk: int = 0,
        started: float = 0.0,
        finished: float = 0.0,
        findings: int = 0,
        cost: float = 0.0,
        trigger: str = "";
}

obj FileNote {
    has path: str = "",
        summary: str = "",
        risk: int = 0,
        lenses: list[str] = [],
        status: str = "queued",
        findings: int = 0,
        additions: int = 0,
        deletions: int = 0,
        related: list[str] = [],
        read: list[str] = [];
}

obj ReviewView {
    has id: str = "",
        pr_id: str = "",
        status: str = "",
        verdict: str = "",
        risk: int = 0,
        triage_risk: int = 0,
        summary: str = "",
        intent: str = "",
        focus: str = "",
        highlights: list[str] = [],
        concerns: list[str] = [],
        tests: list[str] = [],
        walkthrough: list[FileNote] = [],
        stages: list[StageState] = [],
        feed: list[FeedItem] = [],
        costs: list[StageCost] = [],
        started: float = 0.0,
        finished: float = 0.0,
        model: str = "",
        ref: str = "",
        llm_calls: int = 0,
        tokens: int = 0,
        cost: float = 0.0,
        dropped: int = 0,
        error: str = "",
        trigger: str = "";
}

obj PRDetail {
    has pr: PullRequestRef = PullRequestRef(),
        files: list[FileDiff] = [],
        risks: list[FileRisk] = [],
        commits: list[CommitInfo] = [],
        review: ReviewView | None = None,
        findings: list[Finding] = [],
        history: list[ReviewBrief] = [],
        found: bool = False;
}

obj DashboardView {
    has repo: RepoInfo = RepoInfo(),
        stats: RepoStats = RepoStats(),
        activity: list[DayCount] = [],
        languages: list[LangSlice] = [],
        hotspots: list[Hotspot] = [],
        prs: list[PRRow] = [],
        findings: list[Finding] = [],
        insights: int = 0,
        spend: float = 0.0,
        reviews: int = 0;
}

obj ActivityView {
    has days: list[DayCount] = [],
        weeks: list[WeekBucket] = [],
        kinds: list[KindMonth] = [],
        stats: RepoStats = RepoStats();
}

obj PeopleView {
    has contributors: list[Contributor] = [],
        ownership: list[Ownership] = [];
}

obj StructureView {
    has cells: list[TreeCell] = [],
        languages: list[LangSlice] = [];
}

obj ChatReply {
    has text: str = "",
        tools: list[ToolTrace] = [],
        cards: list[Card] = [],
        actions: list[UiCommand] = [],
        tokens: int = 0,
        cost: float = 0.0;
}

obj CodeSnippet {
    has path: str = "",
        start: int = 0,
        lines: list[str] = [],
        total: int = 0;
}

obj AppSize {
    has app: str = "",
        files: int = 0,
        lines: int = 0;
}

obj BuildStats {
    has apps: list[AppSize] = [],
        jac_files: int = 0,
        jac_lines: int = 0,
        endpoints: int = 0,
        tools: int = 0,
        llm_functions: int = 0,
        nodes: int = 0,
        walkers: int = 0;
}

obj Card {
    has id: str = "",
        title: str = "",
        kind: str = "bar",
        caption: str = "",
        spec: str = "{}",
        pinned: bool = False,
        created: float = 0.0;
}

obj UiArgs {
    has to: str = "",
        tab: str = "",
        file: str = "",
        line: int = 0,
        view: str = "",
        severity: str = "",
        category: str = "",
        status: str = "",
        message: str = "",
        tone: str = "",
        path: str = "",
        pr_id: str = "",
        markdown: str = "",
        number: int = 0,
        url: str = "";
}

obj UiCommand {
    has action: str = "",
        args: UiArgs = UiArgs();
}

obj DraftNote {
    has id: str = "",
        path: str = "",
        line: int = 0,
        severity: str = "medium",
        category: str = "correctness",
        title: str = "",
        body: str = "",
        source: str = "",
        confidence: float = 0.0;
}

obj LiveData {
    has action: str = "",
        args: UiArgs = UiArgs(),
        what: str = "",
        id: str = "",
        url: str = "",
        phase: str = "",
        review_id: str = "",
        pr_id: str = "",
        title: str = "",
        detail: str = "",
        trigger: str = "",
        stage: str = "",
        status: str = "",
        stages: list[StageState] = [],
        risk: int = 0,
        files: list[FileRisk] = [],
        path: str = "",
        summary: str = "",
        findings: int = 0,
        drafts: list[DraftNote] = [],
        verdict: str = "",
        seconds: float = 0.0,
        cost: float = 0.0,
        error: str = "";
}

obj LiveEvent {
    has seq: int = 0,
        kind: str = "",
        session: str = "",
        data: LiveData = LiveData(),
        ts: float = 0.0;
}

obj CopilotFrame {
    has t: str = "",
        text: str = "",
        tool: str = "",
        id: str = "",
        args: str = "",
        result: str = "",
        card: Card | None = None,
        tokens: int = 0,
        cost: float = 0.0,
        requests: int = 0;
}
