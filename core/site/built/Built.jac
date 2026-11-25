import from "lucide-react" {
    Play,
    Pause,
    ChevronLeft,
    ChevronRight,
    Sparkles,
    Terminal,
    Smartphone,
    Network,
    Boxes,
    Workflow,
    Cpu,
    Database,
}

obj PipelineStep {
    has title: str,
        body: str,
        path: str,
        needle: str;
}

obj AgentStep {
    has text: str,
        path: str,
        needle: str;
}

glob PIPELINE_STEPS: list[PipelineStep] = [
         PipelineStep(
             title="Ingest: the diff becomes typed objects",
             body="git diff base...head (or the worktree, or gh pr diff) is parsed into FileDiff → Hunk → DiffLine objs with old and new line numbers, including quoted and space-containing paths. GitHub pull requests are fetched into refs/diffwalker/pr/<n>, so reviewers read the PR's code, not your worktree.",
             path="core/git/diffparse.jac",
             needle="def parse_unified_diff",
         ),
         PipelineStep(
             title="Triage: risk and context before any model call",
             body="Pure Jac scores each file 0-100 and creates a FileChange node for it under the Review, linked by typed edges to CodeRef nodes: CalledFrom (callers of the symbols the change edits), TestedBy, and ChangesWith (temporal coupling from the history). Static pattern hits become drafts. With no API key this stage alone still yields a verdict.",
             path="core/review/context.jac",
             needle="def build_context",
         ),
         PipelineStep(
             title="Plan: a lead reviewer assigns lenses",
             body="plan_review has no body: by llm() returns a typed ReviewPlan. Priority 1 files are reviewed on their own; everything else is still reviewed, in batches. A reply that does not fit the type is asked for again (max_output_retries), not a failed stage.",
             path="core/review/agents.jac",
             needle="def plan_review",
         ),
         PipelineStep(
             title="Lenses: a walker fans every file out to flow tasks",
             body="ReviewRun visits each FileChange. Its entry ability queues a Job for the file, or adds the file to a batch of small ones; the walker's exit ability runs each Job as a flow task. The task calls a bodiless by function given the Reviewer, an obj whose fields are the prompt context and whose bound methods are the tools. Tasks never touch the graph, so nothing has to be handed back to the walker but their results.",
             path="core/review/engine.jac",
             needle="can lens with FileChange entry",
         ),
         PipelineStep(
             title="Cross-file: what no single file shows",
             body="One more agent reads every file summary plus the planner's cross-cutting questions and greps the PR's version of the repository for broken callers, signature drift, and config that no longer matches code.",
             path="core/review/agents.jac",
             needle="def cross_file_review",
         ),
         PipelineStep(
             title="Investigate: the model chooses where to look",
             body="For each flagged file an Investigate walker is spawned on its FileChange. visit [here --> [?:CodeRef]] by llm(select=(1, 3)) shows the model each related-code node and the edge that leads to it, with their sem strings, and lets it pick which to read; the walker reads those excerpts and they become the verifier's evidence.",
             path="core/review/engine.jac",
             needle="walker:priv Investigate",
         ),
         PipelineStep(
             title="Verify: per-file adversaries",
             body="Drafts are anchored to lines the diff shows and deduplicated in code, then verified per file, eight drafts to a call and each call a flow task, with the investigator's evidence. Verdicts key on draft ids, so one bad reply cannot shift every decision.",
             path="core/review/engine.jac",
             needle="def verify(rv: Review",
         ),
         PipelineStep(
             title="Synthesize: the verdict follows from the findings",
             body="A typed ReviewSummary supplies the prose; the verdict is recomputed in code from what survived (any high or critical finding means request changes). Findings become Finding nodes under their FileChange, every stage is committed as it finishes, and the meter records spend per stage.",
             path="core/review/engine.jac",
             needle="def verdict_for",
         ),
     ],
     AGENT_STEPS: list[AgentStep] = [
         AgentStep(
             text="The pane calls copilot_stream with the message and what you are looking at (page, pull request, filters), as the signed-in user, and reads the frames it yields with async for.",
             path="core/site/copilot/impl/CopilotPane.impl.jac",
             needle="async for frame in copilot_stream(",
         ),
         AgentStep(
             text="The endpoint returns an Iterator[CopilotFrame], which makes it a stream: the server sends each frame as it is yielded. The turn runs on one thread as its caller, so tools read and write the caller's own graph directly.",
             path="core/api.jac",
             needle="def:protect copilot_stream",
         ),
         AgentStep(
             text="copilot() has no body. by llm(tools=TOOLS, conversation=history, system_prompt=SYSTEM) builds the request from sem strings and the tool signatures, and its Iterator[ByEvent] result makes the call a streamed one.",
             path="core/agent/copilot.jac",
             needle="def copilot(request",
         ),
         AgentStep(
             text="The model answers with tool calls. Those of one round that only read (@reads) run at once, each on its own thread with the turn's context; every other tool runs alone, in the order the model asked.",
             path="core/agent/copilot.jac",
             needle="def open_pull_request",
         ),
         AgentStep(
             text="UI tools only describe intent; data tools read git or the graph, through the functions the pages' endpoints use.",
             path="core/agent/copilot.jac",
             needle="def repo_overview",
         ),
         AgentStep(
             text="ui() adds an event tagged with your user and browser session to the live log; only your own screens are sent it.",
             path="core/live.jac",
             needle="def ui(",
         ),
         AgentStep(
             text="AppShell reads the live stream, matches the session and turns the event into navigation, filters, toasts, or dialogs.",
             path="core/site/shell/AppShell.jac",
             needle="def:pub handle_ui_action",
         ),
         AgentStep(
             text="Writes (post a comment, resolve a finding, pin a chart) go through core/actions.jac, the same code the buttons call, and commit.",
             path="core/actions.jac",
             needle="def set_status",
         ),
         AgentStep(
             text="Between rounds, turn_guard stops the turn on your Stop button or when it passes its budget; llm() then asks the model to answer with no more tool calls, and the stream's last event says the turn was stopped.",
             path="core/agent/copilot.jac",
             needle="def turn_guard",
         ),
         AgentStep(
             text="Each ByEvent becomes a compact frame: chunk, tool_call, tool_result, usage (tokens and cost); a card a tool rendered is a frame too.",
             path="core/api.jac",
             needle="def _frame",
         ),
         AgentStep(
             text="When the model stops calling tools the answer streams; the conversation, a list of Message, is kept on the ChatThread node, and a turn is given latest_turns of it: the most recent whole turns that fit.",
             path="core/impl/api.impl.jac",
             needle="t.history = history;",
         ),
     ],
     FEATURES: list[list[str]] = [
         [
             "by llm() + sem",
             "Planner, reviewers, verifier, synthesizer, and Copilot are bodiless functions with typed returns; their sem strings are the prompts.",
         ],
         [
             "Walkers as agents",
             "ReviewRun queues files from its entry abilities and reduces in its exit ability; Investigate routes with visit ... by llm().",
         ],
         [
             "Typed graph + queries",
             "Review → FileChange → Finding/CodeRef; an id lookup is one edge-reference query from the caller's root.",
         ],
         [
             "def:protect endpoints",
             "Every endpoint runs on the caller's own root: per-user reviews and chats with no user-id plumbing. One that returns an Iterator is a stream.",
         ],
         [
             "flow / wait",
             "Model calls are flow tasks over jobs that never change; only the walker touches the graph, so nothing is marshalled back.",
         ],
         [
             "on_usage metering",
             "on_usage reports the tokens and the cost of every request, priced by jac.toml's rates; a metered() scope bills them to their review and stage, and the UI shows tokens and dollars per stage.",
         ],
         [
             "mobUI",
             "The phone below is View/Text/Pressable from @jac/mobui: React Native on a device, rendered here by react-native-web.",
         ],
         [
             "One project, four apps",
             "archwire.jac declares web, desktop, mobile, and cli over a single core/ tree, and holds every import between modules as a wire.",
         ],
     ];

def PipelineExplorer -> JsxElement;

def AgentWalkthrough -> JsxElement;

def Section(eyebrow: str, title: str, lead: str, children: any = None, id: str = "") -> JsxElement;

def TerminalLine(prompt: bool, text: str, tone: str = "") -> JsxElement;

def:pub Built -> JsxElement;
