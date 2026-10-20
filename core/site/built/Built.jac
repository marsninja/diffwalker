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
    Database
}

glob PIPELINE_STEPS: list[any] = [
         {
             "title": "Ingest: the diff becomes typed objects",
             "body": "git diff base...head (or the worktree, or gh pr diff) is parsed into FileDiff → Hunk → DiffLine objs with old and new line numbers, including quoted and space-containing paths. GitHub pull requests are fetched into refs/diffwalker/pr/<n>, so reviewers read the PR's code, not your worktree.",
             "path": "core/git/diffparse.jac",
             "needle": "def parse_unified_diff"
         },
         {
             "title": "Triage: risk and context before any model call",
             "body": "Pure Jac scores each file 0-100 and creates a FileChange node for it under the Review, linked by typed edges to CodeRef nodes: CalledFrom (callers of the symbols the change edits), TestedBy, and ChangesWith (temporal coupling from the history). Static pattern hits become drafts. With no API key this stage alone still yields a verdict.",
             "path": "core/review/context.jac",
             "needle": "def build_context"
         },
         {
             "title": "Plan: a lead reviewer assigns lenses",
             "body": "plan_review has no body: by llm() returns a typed ReviewPlan. Priority 1 files are reviewed on their own; everything else is still reviewed, in batches. Bad JSON is re-asked with the schema (max_output_retries), not a failed stage.",
             "path": "core/review/agents.jac",
             "needle": "def plan_review"
         },
         {
             "title": "Lenses: a walker fans every file out to flow workers",
             "body": "ReviewRun visits each FileChange. Its entry ability parks a Job under a fresh key and starts a flow worker on it; the worker calls a Reviewer method, an obj whose fields are the prompt context and whose bound methods are the tools. Workers never touch the graph, so they need no request context.",
             "path": "core/review/engine.jac",
             "needle": "can lens with FileChange entry"
         },
         {
             "title": "Cross-file: what no single file shows",
             "body": "One more agent reads every file summary plus the planner's cross-cutting questions and greps the PR's version of the repository for broken callers, signature drift, and config that no longer matches code.",
             "path": "core/review/agents.jac",
             "needle": "def cross_file_review"
         },
         {
             "title": "Investigate: the model chooses where to look",
             "body": "For each flagged file an Investigate walker is spawned on its FileChange. visit [here-->][?:CodeRef] by llm(select=(1, 3)) shows the model each related-code edge with its sem string and lets it pick which to read; the walker reads those excerpts and they become the verifier's evidence.",
             "path": "core/review/engine.jac",
             "needle": "walker Investigate"
         },
         {
             "title": "Verify: per-file adversaries, in parallel",
             "body": "Drafts are anchored to lines the diff shows and deduplicated in code, then verified per file (eight at a time, in parallel) with the investigator's evidence. Verdicts key on draft ids, so one bad reply cannot shift every decision.",
             "path": "core/review/engine.jac",
             "needle": "def verify(rv: Review"
         },
         {
             "title": "Synthesize: the verdict follows from the findings",
             "body": "A typed ReviewSummary supplies the prose; the verdict is recomputed in code from what survived (any high or critical finding means request changes). Findings become Finding nodes under their FileChange, every stage is committed as it finishes, and the meter records spend per stage.",
             "path": "core/review/engine.jac",
             "needle": "def verdict_for"
         }
     ],
     AGENT_STEPS: list[any] = [
         [
             "The pane posts the message and what you are looking at (page, pull request, filters) with your session token and opens an SSE stream.",
             "core/site/copilot/CopilotPane.jac",
             "await read_sse("
         ],
         [
             "The endpoint reports a generator. Each step of it runs inside the caller's request context, so tools read and write the caller's own graph directly.",
             "core/api.jac",
             "def:protect copilot_stream"
         ],
         [
             "copilot() has no body. by llm(tools=..., stream=True, logging=True, parallelize=True, compaction_enabled=True) builds the prompt from sem strings and the tool signatures.",
             "core/agent/copilot.jac",
             "def copilot(request"
         ],
         [
             "The model answers with tool calls. Independent read-only lookups run in parallel; tools that write are marked sequential with mark_serialize.",
             "core/agent/copilot.jac",
             "def open_pull_request"
         ],
         [
             "UI tools only describe intent; data tools read git or the graph; jac mcp adds validate_jac, lint_jac, and search_docs for Jac repositories.",
             "core/agent/copilot.jac",
             "def jac_tools"
         ],
         [
             "ui() publishes an event tagged with your user and browser session onto the live bus; only your own screens receive it.",
             "core/live.jac",
             "def ui("
         ],
         [
             "AppShell's live subscription matches the session and turns the event into navigation, filters, toasts, or dialogs.",
             "core/site/shell/AppShell.jac",
             "def:pub handle_ui_action"
         ],
         [
             "Writes (post a comment, resolve a finding, pin a chart) go through core/actions.jac, the same code the buttons call, and commit.",
             "core/actions.jac",
             "def set_status"
         ],
         [
             "Between ReAct steps, turn_guard stops the turn on your Stop button or when it passes its budget; byLLM then asks for a summary.",
             "core/agent/copilot.jac",
             "def turn_guard"
         ],
         [
             "Each StreamEvent becomes a compact frame: tool_call, tool_result, thought, card, chunk, usage (with cost).",
             "core/api.jac",
             "def _frame"
         ],
         [
             "When the model stops calling tools the answer streams; the conversation list persists on the ChatThread node and byLLM compacts it when it grows.",
             "core/api.jac",
             "t.history = history;"
         ]
     ],
     FEATURES: list[list[str]] = [
         [
             "by llm() + sem",
             "Planner, reviewers, verifier, synthesizer, and Copilot are bodiless functions and methods with typed returns."
         ],
         [
             "Walkers as agents",
             "ReviewRun fans files out from entry abilities and reduces in its exit ability; Investigate routes with visit by llm()."
         ],
         [
             "Typed graph + queries",
             "Review → FileChange → Finding/CodeRef; id lookups are one compiled query with promoted indexes."
         ],
         [
             "def:protect endpoints",
             "Every endpoint runs on the caller's own root: per-user reviews and chats with no user-id plumbing."
         ],
         [
             "flow / wait",
             "Model calls run in flow workers over immutable jobs; only the walker touches the graph, so nothing is marshalled back."
         ],
         [
             "byLLM telemetry",
             "A metered() scope bills every call to its review and stage; the UI shows tokens and dollars per stage."
         ],
         [
             "mobUI",
             "The phone below is View/Text/Pressable compiled to React Native, rendered here by react-native-web."
         ],
         [
             "One workspace, three apps",
             "jac.toml declares web, mobile, and cli over a single core/ tree, wired in archwire.jac."
         ]
     ];

def PipelineExplorer -> JsxElement {
    has step: int = 3;
    s = PIPELINE_STEPS[step];
    <div className="space-y-4">
        <div className="rounded-2xl border border-border bg-card/60 p-3 sm:p-4">
            <PipelineDiagram active={step}/>
        </div>
        <div className="flex flex-wrap gap-1.5">
            {for (i, st) in enumerate(PIPELINE_STEPS) {
                <button
                    key={str(i)}
                    type="button"
                    onClick={lambda { step = i; }}
                    className={"rounded-full border px-3 py-1 text-xs transition-colors "
                        + (
                            "border-primary bg-primary/15 text-foreground"
                                if step == i
                                else "border-border text-muted-foreground hover:text-foreground"
                        )}
                >
                    {str(i + 1) + ". " + st["title"].split(":")[0]}
                </button>
            }}
        </div>
        <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
            <div className="fade-up" key={"t" + str(step)}>
                <h3 className="text-lg font-semibold tracking-tight">{s["title"]}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                    {s["body"]}
                </p>
            </div>
            <CodeSpotlight
                path={s["path"]}
                needle={s["needle"]}
                before={1}
                after={16}
                title={"stage " + str(step + 1)}
            />
        </div>
    </div>
}

def AgentWalkthrough -> JsxElement {
    has step: int = 0,
        playing: bool = True;
    can with [playing] entry {
        if not playing {
            return;
        }
        timer = setInterval(lambda { step = (step + 1) % len(AGENT_STEPS); }, 4200);
        return lambda { clearInterval(timer); };
    }
    s = AGENT_STEPS[step];
    <div className="space-y-4">
        <div className="rounded-2xl border border-border bg-card/60 p-3 sm:p-4">
            <AgentLoopDiagram active={step}/>
        </div>
        <div className="flex items-center gap-2">
            <button
                type="button"
                onClick={lambda {
                    playing = False;
                    step = (step + len(AGENT_STEPS) - 1) % len(AGENT_STEPS);
                }}
                className="rounded-md border border-border p-1.5 hover:bg-muted"
                aria-label="Previous step"
            >
                <ChevronLeft className="size-4"/>
            </button>
            <button
                type="button"
                onClick={lambda { playing = not playing; }}
                className="inline-flex items-center gap-1.5 rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-muted"
            >
                {(<Pause className="size-3.5"/>)
                    if playing
                    else (<Play className="size-3.5"/>)}{"Pause" if playing else "Play"}
            </button>
            <button
                type="button"
                onClick={lambda {
                    playing = False;
                    step = (step + 1) % len(AGENT_STEPS);
                }}
                className="rounded-md border border-border p-1.5 hover:bg-muted"
                aria-label="Next step"
            >
                <ChevronRight className="size-4"/>
            </button>
            <div className="ml-2 h-1 flex-1 overflow-hidden rounded-full bg-muted">
                <div
                    className="h-full rounded-full bg-primary transition-all duration-500"
                    style={{
                        "width": str(round(100 * (step + 1) / len(AGENT_STEPS))) + "%"
                    }}
                ></div>
            </div>
            <span className="text-xs tabular text-muted-foreground">
                {str(step + 1) + " / " + str(len(AGENT_STEPS))}
            </span>
        </div>
        <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
            <div key={"a" + str(step)} className="fade-up">
                <div
                    className="text-[11px] font-medium uppercase tracking-[0.16em] text-primary"
                >
                    {"Step " + str(step + 1)}
                </div>
                <p className="mt-2 text-base leading-relaxed">{s[0]}</p>
            </div>
            <CodeSpotlight path={s[1]} needle={s[2]} before={1} after={14}/>
        </div>
    </div>
}

def Section(
    eyebrow: str, title: str, lead: str, children: any = None, id: str = ""
) -> JsxElement {
    <section
        id={id}
        className="scroll-mt-6 border-t border-border/60 py-12 first:border-0 first:pt-4"
    >
        <div className="mb-6 max-w-3xl">
            <div
                className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary"
            >
                {eyebrow}
            </div>
            <h2 className="mt-1.5 text-2xl font-semibold tracking-tight sm:text-3xl">
                {title}
            </h2>
            <p
                className="mt-2 text-sm leading-relaxed text-muted-foreground sm:text-base"
            >
                {lead}
            </p>
        </div>
        {children}
    </section>
}

def TerminalLine(prompt: bool, text: str, tone: str = "") -> JsxElement {
    <div className="whitespace-pre-wrap">
        {if prompt {
            <span className="text-[var(--series-3)]">{"$ "}</span>
        }}
        <span style={{"color": tone} if tone else {}}>{text}</span>
    </div>
}

def:pub Built -> JsxElement {
    has stats: any = None;
    async can with entry {
        stats = await build_stats();
    }
    <div className="mx-auto max-w-6xl px-4 pb-24 sm:px-6">
        <header
            className="grid-bg relative -mx-4 overflow-hidden border-b border-border px-4 pb-10 pt-10 sm:-mx-6 sm:px-6"
        >
            <div
                className="pointer-events-none absolute -right-24 -top-24 size-80 rounded-full bg-primary/25 blur-3xl"
            ></div>
            <div className="relative max-w-3xl">
                <div
                    className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary"
                >
                    How it's built
                </div>
                <h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-5xl">
                    An agentic code reviewer in one language.
                </h1>
                <p
                    className="mt-4 text-base leading-relaxed text-muted-foreground sm:text-lg"
                >
                    diffwalker is a Jac workspace: a web app, a mobile app, and a CLI over one shared core. The reviewer is seven stages of typed functions, five of them delegated to a model with by llm(). The Copilot is one more such function with 29 tools, and every tool that changes your screen arrives as an event the UI applies live.
                </p>
                <div className="mt-6 flex flex-wrap gap-2 text-xs">
                    {for (label, target) in [
                        ("Architecture", "#arch"),
                        ("Graph", "#graph"),
                        ("Review pipeline", "#pipeline"),
                        ("Agent loop", "#agent"),
                        ("Mobile", "#mobile"),
                        ("CLI", "#cli")
                    ] {
                        <a
                            key={target}
                            href={target}
                            className="rounded-full border border-border bg-background/60 px-3 py-1 text-muted-foreground hover:text-foreground"
                        >
                            {label}
                        </a>
                    }}
                </div>
            </div>
            {if stats {
                <div className="relative mt-8 grid grid-cols-2 gap-3 md:grid-cols-4">
                    <StatTile
                        label="Jac source"
                        value={fmt_num(stats.jac_lines) + " lines"}
                        hint={str(stats.jac_files) + " .jac files, zero .ts/.py"}
                    />
                    <StatTile
                        label="Endpoints"
                        value={str(stats.endpoints)}
                        hint="def:pub functions, RPC generated"
                    />
                    <StatTile
                        label="LLM functions"
                        value={str(stats.llm_functions)}
                        hint="by llm() with typed returns"
                    />
                    <StatTile
                        label="Copilot tools"
                        value={str(stats.tools)}
                        hint={str(stats.nodes)
                            + " node types · "
                            + str(stats.walkers)
                            + " walker"}
                    />
                </div>
            }}
        </header>
        <Section
            id="arch"
            eyebrow="Architecture"
            title="Three apps, one core, no glue code"
            lead="jac.toml declares three apps over a shared core/ tree. Where each declaration runs is inferred: JSX compiles to the browser bundle, subprocess and graph code stays on the server, and a client call to a def:pub function becomes a generated RPC stub with the server's types."
        >
            <figure className="rounded-2xl border border-border bg-card/60 p-3 sm:p-5">
                <ArchitectureDiagram/>
                <figcaption className="mt-3 text-xs text-muted-foreground">
                    Solid violet edges carry the hot path: typed RPC in, SSE out, by llm() to the model. Dashed edges are optional routes: the phone uses the same stubs, and the CLI runs in-process or drives a running server with --live.
                </figcaption>
            </figure>
            {if stats {
                <div className="mt-5 grid gap-5 lg:grid-cols-2">
                    <Panel
                        title="Where the code lives"
                        subtitle="Lines of Jac per top-level directory, measured live"
                    >
                        <HBars
                            labels={[a.app for a in stats.apps]}
                            sub={[str(a.files) + " files" for a in stats.apps]}
                            values={[float(a.lines) for a in stats.apps]}
                            colors={[
                                series_color(i) for (i, a) in enumerate(stats.apps)
                            ]}
                        />
                    </Panel>
                    <CodeSpotlight
                        path="jac.toml"
                        needle="[apps.web]"
                        before={0}
                        after={12}
                        title="the workspace"
                    />
                </div>
            }}
        </Section>
        <Section
            id="graph"
            eyebrow="Data model"
            title="State is a graph, and code walks it"
            lead="Reviews are not rows in tables. Repo, PullRequest, Review, and Finding are nodes joined by typed edges under root, persisted automatically. Queries that span the hierarchy are walkers: CollectFindings carries its filter from node to node and gathers matches where they live."
        >
            <figure className="rounded-2xl border border-border bg-card/60 p-3 sm:p-5">
                <GraphDiagram/>
                <figcaption className="mt-3 text-xs text-muted-foreground">
                    The moving dot is the CollectFindings walker that feeds the dashboard's latest findings.
                </figcaption>
            </figure>
            <div className="mt-5 grid gap-5 lg:grid-cols-2">
                <CodeSpotlight
                    path="core/graph.jac"
                    needle="edge HasRepo"
                    before={0}
                    after={12}
                    title="typed edges"
                />
                <CodeSpotlight
                    path="core/graph.jac"
                    needle="walker CollectFindings"
                    before={0}
                    after={28}
                    title="walker"
                />
            </div>
        </Section>
        <Section
            id="pipeline"
            eyebrow="The reviewer"
            title="Eight stages from diff to verdict"
            lead="Deterministic Jac does what code does well (parsing, scoring, linking related code, enforcing rules); typed LLM functions do judgment. Click a stage to see the real source that runs it."
        >
            <PipelineExplorer/>
        </Section>
        <Section
            id="agent"
            eyebrow="The Copilot"
            title="An agent that shares your screen"
            lead="Copilot is a single by llm() function with 29 tools: some read the repository, some change review state, some render charts and diagrams, and some drive the interface. Because its tools emit the same events your clicks do, anything you can do in the UI it can do in front of you. Here is one turn, step by step."
        >
            <AgentWalkthrough/>
            <div className="mt-8 grid gap-4 md:grid-cols-4">
                {for (title, tools, Icon) in [
                    (
                        "Drive the UI",
                        "navigate, open_pull_request, focus_file, filter_findings, show_insights, notify, switch_repository",
                        Workflow
                    ),
                    (
                        "Read the repo",
                        "list_pull_requests, pull_request_details, file_diff, read_file, search_code, blame, repo_overview, hotspot_report, contributor_report, ownership_report, coupling_report, activity_report",
                        Cpu
                    ),
                    (
                        "Change review state",
                        "review_pull_request, post_comment, update_finding, reply_to_finding, list_findings, export_review, publish_to_github (asks you first)",
                        Database
                    ),
                    (
                        "Render insights",
                        "render_chart, render_table, render_diagram: cards in the chat that pin to the Insight board",
                        Boxes
                    )
                ] {
                    <div
                        key={title}
                        className="rounded-2xl border border-border bg-card/70 p-4"
                    >
                        <div className="flex items-center gap-2 text-sm font-semibold">
                            <Icon className="size-4 text-primary"/>
                            {title}
                        </div>
                        <p
                            className="mt-2 font-mono text-[11px] leading-relaxed text-muted-foreground"
                        >
                            {tools}
                        </p>
                    </div>
                }}
            </div>
            <div
                className="mt-10 grid gap-5 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]"
            >
                <div>
                    <h3 className="text-lg font-semibold tracking-tight">
                        Model calls in workers, graph writes in the walker
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                        Jac persists the graph per request. The review walker runs inside the request that started it, so it reads and writes nodes directly and calls commit() after every stage; other screens see each stage land. The model calls it fans out run in flow workers that read an immutable Job and return typed results, never touching the graph, so nothing has to be marshalled back.
                    </p>
                </div>
                <CodeSpotlight
                    path="core/review/engine.jac"
                    needle="def run_job"
                    before={1}
                    after={14}
                    title="run_job"
                />
            </div>
            <figure
                className="mt-5 rounded-2xl border border-border bg-card/60 p-3 sm:p-5"
            >
                <WalkerDiagram/>
                <figcaption className="mt-3 text-xs text-muted-foreground">
                    Entry abilities fan out, the exit ability reduces: workers only call the model, the walker owns every write.
                </figcaption>
            </figure>
            <div className="mt-6 flex flex-wrap gap-2">
                {for q in [
                    "Draw your review pipeline as a Mermaid diagram",
                    "Which of your tools change my screen? Show me one",
                    "Open the riskiest pull request and explain why it is risky"
                ] {
                    <button
                        key={q}
                        type="button"
                        onClick={lambda { ask_copilot(q); }}
                        className="inline-flex items-center gap-1.5 rounded-full border border-border px-3 py-1.5 text-xs text-muted-foreground hover:border-primary/50 hover:text-foreground"
                    >
                        <Sparkles className="size-3.5 text-primary"/>
                        {q}
                    </button>
                }}
            </div>
        </Section>
        <Section
            id="mobile"
            eyebrow="mobUI"
            title="The phone on this page is the mobile app"
            lead="Not a screenshot. mobile/main.jac renders DiffwalkerMobile with View, Text, and Pressable. Built for a device it is React Native; here react-native-web draws the same component, talking to the same server and the same graph."
        >
            <div className="grid items-start gap-10 lg:grid-cols-[auto_minmax(0,1fr)]">
                <PhoneFrame>
                    <DiffwalkerMobile embedded={True}/>
                </PhoneFrame>
                <div className="min-w-0 space-y-5">
                    <CodeSpotlight
                        path="core/site/built/Built.jac"
                        needle="<DiffwalkerMobile embedded={True}/>"
                        before={2}
                        after={3}
                        title="the whole embed"
                    />
                    <ul className="space-y-3 text-sm text-muted-foreground">
                        <li className="flex gap-2">
                            <Smartphone
                                className="mt-0.5 size-4 shrink-0 text-primary"
                            />
                            Four tabs: inbox, review, insights, Copilot. Resolve a finding on the phone and the web review updates.
                        </li>
                        <li className="flex gap-2">
                            <Sparkles className="mt-0.5 size-4 shrink-0 text-primary"/>
                            The phone's Copilot is the same agent. Its navigate actions come back in the reply and move the phone's own tabs.
                        </li>
                        <li className="flex gap-2">
                            <Network className="mt-0.5 size-4 shrink-0 text-primary"/>
                            The phone signs in with jacLogin, then calls start_review, the same walker pipeline, and polls pr_detail for each stage as it commits.
                        </li>
                    </ul>
                    <CodeSpotlight
                        path="core/native/DiffwalkerMobile.jac"
                        needle="async def ask("
                        before={0}
                        after={22}
                        title="mobile Copilot"
                    />
                </div>
            </div>
        </Section>
        <Section
            id="cli"
            eyebrow="CLI"
            title="The same engine from a terminal"
            lead="cli/main.jac imports the core directly, so jac run cli works offline against any repository. With --live it posts to a running server instead, and the browser that has diffwalker open follows along."
        >
            <div className="grid gap-5 lg:grid-cols-2">
                <div
                    className="overflow-hidden rounded-xl border border-border bg-[#0b0a10] font-mono text-[12px] leading-relaxed text-[#d8d6e6] shadow-lg"
                >
                    <div
                        className="flex items-center gap-2 border-b border-white/10 px-3 py-2 text-[11px] text-white/50"
                    >
                        <Terminal className="size-3.5"/>
                        diffwalker
                    </div>
                    <div className="space-y-1 p-4">
                        <TerminalLine
                            prompt={True}
                            text="jac run cli -- review b-6fabbb2aff"
                        />
                        <TerminalLine
                            prompt={False}
                            text="▸ review R-b8e9a1  Format the guard as the formatter has it"
                            tone="#9085e9"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  ✓ ingest     2 files, +6 -5, 2 commits"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  ✓ triage     Top risk type_evaluator.impl.jac (27); 0 static hits"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  ✓ plan       Fix the type checker so a flow-analysis lookup…"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="      draft low     New hardcoded depth cap of 32 silently drops narrowing"
                            tone="#eda100"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  ✓ review     2 files reviewed, 1 draft findings"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="      ✗ verifier dropped: New hardcoded depth cap of 32…"
                            tone="#e66767"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  ✓ verify     Kept 0, dropped 1 as false positives"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="verdict: approve   risk 22/100   0 findings   6 model calls"
                            tone="#ecebf3"
                        />
                        <TerminalLine
                            prompt={True}
                            text="jac run cli -- ask --live 'show me the people view; who owns the compiler?'"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  → show_insights({view: people})  → contributor_report  → blame(…)"
                            tone="#9085e9"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  card: Compiler ownership"
                            tone="#a9a6bd"
                        />
                        <TerminalLine
                            prompt={False}
                            text="  (the open browser just switched to Insights → People)"
                            tone="#eda100"
                        />
                    </div>
                </div>
                <CodeSpotlight
                    path="cli/main.jac"
                    needle="def build_parser"
                    before={0}
                    after={30}
                    title="cli/main.jac"
                />
            </div>
        </Section>
        <Section
            eyebrow="Language features"
            title="What Jac did that would otherwise be glue"
            lead="Each row is something a conventional stack would need a separate framework, schema, or service for."
        >
            <div className="grid gap-3 md:grid-cols-2">
                {for f in FEATURES {
                    <div
                        key={f[0]}
                        className="rounded-2xl border border-border bg-card/70 p-4"
                    >
                        <div className="font-mono text-sm font-semibold text-primary">
                            {f[0]}
                        </div>
                        <p
                            className="mt-1.5 text-sm leading-relaxed text-muted-foreground"
                        >
                            {f[1]}
                        </p>
                    </div>
                }}
            </div>
        </Section>
    </div>
}
