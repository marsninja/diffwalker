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

"""A stage of the review pipeline: what it does, and the source that runs it."""
obj PipelineStep {
    has title: str,
        body: str,
        path: str,
        needle: str;
}

"""A step of one Copilot turn: what happens, and the source where it happens."""
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
             path="core/site/copilot/CopilotPane.jac",
             needle="async for frame in copilot_stream(",
         ),
         AgentStep(
             text="The endpoint returns an Iterator[CopilotFrame], which makes it a stream: the server sends each frame as it is yielded. The turn runs on one thread as its caller, so tools read and write the caller's own graph directly.",
             path="core/api.jac",
             needle="def:protect copilot_stream",
         ),
         AgentStep(
             text="copilot() has no body. by llm(tools=[...], conversation=history, system_prompt=SYSTEM, parallelize=True) builds the request from sem strings and the tool signatures, and its Iterator[ByEvent] result makes the call a streamed one.",
             path="core/agent/copilot.jac",
             needle="def copilot(request",
         ),
         AgentStep(
             text="The model answers with tool calls. The calls of one round run at once, each on its own thread with the turn's context; a tool that writes takes a lock in core/actions.jac.",
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
             text="Between rounds, turn_guard stops the turn on your Stop button or when it passes its budget; stdjac.llm then asks the model to answer with no more tool calls.",
             path="core/agent/copilot.jac",
             needle="def turn_guard",
         ),
         AgentStep(
             text="Each ByEvent becomes a compact frame: chunk, tool_call, tool_result, usage (tokens and cost); a card a tool rendered is a frame too.",
             path="core/api.jac",
             needle="def _frame",
         ),
         AgentStep(
             text="When the model stops calling tools the answer streams; the conversation, a list of Message, is kept on the ChatThread node, and trim_history keeps its most recent turns when it grows.",
             path="core/api.jac",
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
             "stdjac.llm reports the tokens of every request; a metered() scope bills them to their review and stage, and the UI shows tokens and dollars per stage.",
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

def PipelineExplorer -> JsxElement {
    has step: int = 3;
    s = PIPELINE_STEPS[step];
    return <div className="space-y-4">
        <div className="rounded-2xl border border-border bg-card/60 p-3 sm:p-4">
            <PipelineDiagram active={step} />
        </div>
        <div className="flex flex-wrap gap-1.5">
            {
                for (i, st) in enumerate(PIPELINE_STEPS) {
                    <button
                        key={str(i)}
                        type="button"
                        onClick={lambda { step = i; }}
                        className={"rounded-full border px-3 py-1 text-xs transition-colors " + ("border-primary bg-primary/15 text-foreground" if step == i else "border-border text-muted-foreground hover:text-foreground")}
                    >{str(i + 1) + ". " + st.title.split(":")[0]}</button>
                }
            }
        </div>
        <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
            <div className="fade-up" key={"t" + str(step)}>
                <h3 className="text-lg font-semibold tracking-tight">{s.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{s.body}</p>
            </div>
            <CodeSpotlight
                path={s.path}
                needle={s.needle}
                before={1}
                after={16}
                title={"stage " + str(step + 1)}
            />
        </div>
    </div>;
}

def AgentWalkthrough -> JsxElement {
    has step: int = 0,
        playing: bool = True,
        timer: Ref[any] = Ref(None);

    can with [playing] entry {
        if not playing {
            return;
        }
        timer.current = setInterval(lambda { step = (step + 1) % len(AGENT_STEPS); }, 4200);
    }
    can with [playing] exit {
        if timer.current {
            clearInterval(timer.current);
            timer.current = None;
        }
    }
    s = AGENT_STEPS[step];
    return <div className="space-y-4">
        <div className="rounded-2xl border border-border bg-card/60 p-3 sm:p-4">
            <AgentLoopDiagram active={step} />
        </div>
        <div className="flex items-center gap-2"><button type="button" onClick={lambda {
                    playing = False;
                    step = (step + len(AGENT_STEPS) - 1) % len(AGENT_STEPS);
                }} className="rounded-md border border-border p-1.5 hover:bg-muted" aria-label="Previous step"><ChevronLeft className="size-4" /></button><button type="button" onClick={lambda { playing = not playing; }} className="inline-flex items-center gap-1.5 rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-muted">{(<Pause className="size-3.5" />) if playing else (<Play className="size-3.5" />)}{"Pause" if playing else "Play"}</button><button type="button" onClick={lambda {
                    playing = False;
                    step = (step + 1) % len(AGENT_STEPS);
                }} className="rounded-md border border-border p-1.5 hover:bg-muted" aria-label="Next step"><ChevronRight className="size-4" /></button><div className="ml-2 h-1 flex-1 overflow-hidden rounded-full bg-muted"><div className="h-full rounded-full bg-primary transition-all duration-500" style={{"width": str(round(100 * (step + 1) / len(AGENT_STEPS))) + "%"}}></div></div><span className="text-xs tabular text-muted-foreground">{str(step + 1) + " / " + str(len(AGENT_STEPS))}</span></div>
        <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
            <div key={"a" + str(step)} className="fade-up">
                <div className="text-[11px] font-medium uppercase tracking-[0.16em] text-primary">
                    {"Step " + str(step + 1)}
                </div>
                <p className="mt-2 text-base leading-relaxed">{s.text}</p>
            </div>
            <CodeSpotlight path={s.path} needle={s.needle} before={1} after={14} />
        </div>
    </div>;
}

def Section(eyebrow: str, title: str, lead: str, children: any = None, id: str = "") -> JsxElement {
    return <section
        id={id}
        className="scroll-mt-6 border-t border-border/60 py-12 first:border-0 first:pt-4"
    >
        <div className="mb-6 max-w-3xl">
            <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary">
                {eyebrow}
            </div>
            <h2 className="mt-1.5 text-2xl font-semibold tracking-tight sm:text-3xl">{title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground sm:text-base">
                {lead}
            </p>
        </div>
        {children}
    </section>;
}

def TerminalLine(prompt: bool, text: str, tone: str = "") -> JsxElement {
    return <div className="whitespace-pre-wrap">
        {
            if prompt {
                <span className="text-[var(--series-3)]">{"$ "}</span>
            }
        }
        <span style={{"color": tone} if tone else {}}>{text}</span>
    </div>;
}

def:pub Built -> JsxElement {
    has stats: BuildStats | None = None;
    async can with entry {
        stats = await build_stats();
    }
    return <div className="mx-auto max-w-6xl px-4 pb-24 sm:px-6">
        <header
            className="grid-bg relative -mx-4 overflow-hidden border-b border-border px-4 pb-10 pt-10 sm:-mx-6 sm:px-6"
        >
            <div
                className="pointer-events-none absolute -right-24 -top-24 size-80 rounded-full bg-primary/25 blur-3xl"
            ></div>
            <div className="relative max-w-3xl">
                <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-primary">
                    How it's built
                </div>
                <h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-5xl">
                    An agentic code reviewer in one language.
                </h1>
                <p className="mt-4 text-base leading-relaxed text-muted-foreground sm:text-lg">
                    diffwalker is one Jac project, built with neojac: a web app, a desktop app, a mobile app, and a CLI over one shared core. The reviewer is eight stages, six of which ask a model through by llm(). The Copilot is one more such function with 29 tools, and every tool that changes your screen arrives as an event the UI applies live.
                </p>
                <div className="mt-6 flex flex-wrap gap-2 text-xs">
                    {
                        for (label, target) in [
                            ("Architecture", "#arch"),
                            ("Graph", "#graph"),
                            ("Review pipeline", "#pipeline"),
                            ("Agent loop", "#agent"),
                            ("Mobile", "#mobile"),
                            ("CLI", "#cli"),
                        ] {
                            <a
                                key={target}
                                href={target}
                                className="rounded-full border border-border bg-background/60 px-3 py-1 text-muted-foreground hover:text-foreground"
                            >{label}</a>
                        }
                    }
                </div>
            </div>
            {
                if stats {
                    <div className="relative mt-8 grid grid-cols-2 gap-3 md:grid-cols-4">
                        <StatTile
                            label="Jac source"
                            value={fmt_num(stats.jac_lines) + " lines"}
                            hint={str(stats.jac_files) + " .jac files of app code"}
                        />
                        <StatTile
                            label="Endpoints"
                            value={str(stats.endpoints)}
                            hint="def:protect functions, called as typed functions"
                        />
                        <StatTile
                            label="LLM functions"
                            value={str(stats.llm_functions)}
                            hint="by llm() with typed returns"
                        />
                        <StatTile
                            label="Copilot tools"
                            value={str(stats.tools)}
                            hint={str(stats.nodes) + " node types · " + str(stats.walkers) + " walker"}
                        />
                    </div>
                }
            }
        </header>
        <Section
            id="arch"
            eyebrow="Architecture"
            title="Four apps, one core, no glue code"
            lead="archwire.jac declares the spaces code runs in (the site in a browser, the phone app, the server, the CLI) and the four apps made of them, over a shared core/ tree; the desktop app is the site in a window. core/api.jac is the server, and a page's call of one of its functions is an ordinary call, checked against the server's types and sent as a request."
        >
            <figure className="rounded-2xl border border-border bg-card/60 p-3 sm:p-5">
                <ArchitectureDiagram />
                <figcaption className="mt-3 text-xs text-muted-foreground">
                    Solid violet edges carry the hot path: typed calls in, streams out, by llm() to the model. Dashed edges are optional routes: the phone calls the same endpoints, and the CLI runs in-process or drives a running server with --live.
                </figcaption>
            </figure>
            {
                if stats {
                    <div className="mt-5 grid gap-5 lg:grid-cols-2">
                        <Panel
                            title="Where the code lives"
                            subtitle="Lines of Jac per top-level directory, measured live"
                        >
                            <HBars
                                labels={[a.app for a in stats.apps]}
                                sub={[str(a.files) + " files" for a in stats.apps]}
                                values={[float(a.lines) for a in stats.apps]}
                                colors={[series_color(i) for (i, a) in enumerate(stats.apps)]}
                            />
                        </Panel>
                        <CodeSpotlight
                            path="archwire.jac"
                            needle="graph spaces {"
                            before={0}
                            after={14}
                            title="the spaces and apps"
                        />
                    </div>
                }
            }
        </Section>
        <Section
            id="graph"
            eyebrow="Data model"
            title="State is a graph, and code walks it"
            lead="Reviews are not rows in tables. Repo, PullRequest, Review, and Finding are nodes joined by typed edges under each user's root, and the server keeps the graph with no storage code in the app. Queries that span the hierarchy are walkers: CollectFindings carries its filter from node to node and gathers matches where they live."
        >
            <figure className="rounded-2xl border border-border bg-card/60 p-3 sm:p-5">
                <GraphDiagram />
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
                    needle="walker:priv CollectFindings"
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
        ><PipelineExplorer /></Section>
        <Section
            id="agent"
            eyebrow="The Copilot"
            title="An agent that shares your screen"
            lead="Copilot is a single by llm() function with 29 tools: some read the repository, some change review state, some render charts and diagrams, and some drive the interface. Because its tools emit the same events your clicks do, anything you can do in the UI it can do in front of you. Here is one turn, step by step."
        >
            <AgentWalkthrough />
            <div className="mt-8 grid gap-4 md:grid-cols-4">
                {
                    for (title, tools, Icon) in [
                        (
                            "Drive the UI",
                            "navigate, open_pull_request, focus_file, filter_findings, show_insights, notify, switch_repository",
                            Workflow,
                        ),
                        (
                            "Read the repo",
                            "list_pull_requests, pull_request_details, file_diff, read_file, search_code, blame, repo_overview, hotspot_report, contributor_report, ownership_report, coupling_report, activity_report",
                            Cpu,
                        ),
                        (
                            "Change review state",
                            "review_pull_request, post_comment, update_finding, reply_to_finding, list_findings, export_review, publish_to_github (asks you first)",
                            Database,
                        ),
                        (
                            "Render insights",
                            "render_chart, render_table, render_diagram: cards in the chat that pin to the Insight board",
                            Boxes,
                        ),
                    ] {
                        <div
                            key={title}
                            className="rounded-2xl border border-border bg-card/70 p-4"
                        >
                            <div className="flex items-center gap-2 text-sm font-semibold">
                                <Icon className="size-4 text-primary" />
                                {title}
                            </div>
                            <p
                                className="mt-2 font-mono text-[11px] leading-relaxed text-muted-foreground"
                            >{tools}</p>
                        </div>
                    }
                }
            </div>
            <div className="mt-10 grid gap-5 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
                <div><h3 className="text-lg font-semibold tracking-tight">
                        Model calls in tasks, graph writes in the walker
                    </h3><p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                        The server writes the graph when a call returns. A review is one long call, so its walker reads and writes nodes directly and calls commit() after every stage; other screens see each stage land. The model calls it fans out are flow tasks that read a Job nobody changes and return typed results, never touching the graph, so nothing has to be marshalled back.
                    </p></div>
                <CodeSpotlight
                    path="core/review/engine.jac"
                    needle="def review_job"
                    before={2}
                    after={18}
                    title="review_job"
                />
            </div>
            <figure className="mt-5 rounded-2xl border border-border bg-card/60 p-3 sm:p-5">
                <WalkerDiagram />
                <figcaption className="mt-3 text-xs text-muted-foreground">
                    Entry abilities queue the files, the exit ability runs their reviewers and reduces: tasks only call the model, the walker owns every write.
                </figcaption>
            </figure>
            <div className="mt-6 flex flex-wrap gap-2">
                {
                    for q in [
                        "Draw your review pipeline as a Mermaid diagram",
                        "Which of your tools change my screen? Show me one",
                        "Open the riskiest pull request and explain why it is risky",
                    ] {
                        <button
                            key={q}
                            type="button"
                            onClick={lambda { ask_copilot(q) }}
                            className="inline-flex items-center gap-1.5 rounded-full border border-border px-3 py-1.5 text-xs text-muted-foreground hover:border-primary/50 hover:text-foreground"
                        ><Sparkles className="size-3.5 text-primary" />{q}</button>
                    }
                }
            </div>
        </Section>
        <Section
            id="mobile"
            eyebrow="mobUI"
            title="The phone on this page is the mobile app"
            lead="Not a screenshot. mobile/main.jac renders DiffwalkerMobile with View, Text, and Pressable. Built for a device it is React Native; here react-native-web draws the same component, talking to the same server and the same graph."
        >
            <div className="grid items-start gap-10 lg:grid-cols-[auto_minmax(0,1fr)]">
                <PhoneFrame><DiffwalkerMobile embedded={True} /></PhoneFrame>
                <div className="min-w-0 space-y-5">
                    <CodeSpotlight
                        path="core/site/built/Built.jac"
                        needle="<DiffwalkerMobile embedded={True} />"
                        before={2}
                        after={3}
                        title="the whole embed"
                    />
                    <ul className="space-y-3 text-sm text-muted-foreground">
                        <li className="flex gap-2"><Smartphone
                            className="mt-0.5 size-4 shrink-0 text-primary"
                        />
                            Four tabs: inbox, review, insights, Copilot. Resolve a finding on the phone and the web review updates.
                        </li>
                        <li className="flex gap-2"><Sparkles
                            className="mt-0.5 size-4 shrink-0 text-primary"
                        />
                            The phone's Copilot is the same agent. Its navigate actions come back in the reply and move the phone's own tabs.
                        </li>
                        <li className="flex gap-2"><Network
                            className="mt-0.5 size-4 shrink-0 text-primary"
                        />
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
            lead="The cli app compiles the core into its own program, so neojac run cli reviews any repository in-process. With --live it calls a running server instead, and the browser that has diffwalker open follows along."
        >
            <div className="grid gap-5 lg:grid-cols-2">
                <div
                    className="overflow-hidden rounded-xl border border-border bg-[#0b0a10] font-mono text-[12px] leading-relaxed text-[#d8d6e6] shadow-lg"
                >
                    <div
                        className="flex items-center gap-2 border-b border-white/10 px-3 py-2 text-[11px] text-white/50"
                    ><Terminal className="size-3.5" />
                        diffwalker
                    </div>
                    <div className="space-y-1 p-4">
                        <TerminalLine prompt={True} text="neojac run cli -- review b-6fabbb2aff" />
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
                            text="  ✓ review     2/2 files reviewed (2 solo, 0 batches) · 1 drafts"
                            tone="#1baf7a"
                        />
                        <TerminalLine
                            prompt={False}
                            text="      ✗ dropped: New hardcoded depth cap of 32…"
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
                            text="neojac run cli -- ask --live 'show me the people view; who owns the compiler?'"
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
                {
                    for f in FEATURES {
                        <div key={f[0]} className="rounded-2xl border border-border bg-card/70 p-4">
                            <div className="font-mono text-sm font-semibold text-primary">
                                {f[0]}
                            </div>
                            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                                {f[1]}
                            </p>
                        </div>
                    }
                }
            </div>
        </Section>
    </div>;
}
