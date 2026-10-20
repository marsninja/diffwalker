def:pub Arrowheads(id: str) -> JsxElement {
    <defs>
        <marker
            id={id}
            viewBox="0 0 10 10"
            refX="9"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto-start-reverse"
        >
            <path d="M0,0 L10,5 L0,10 z" fill="var(--ink-muted)"/>
        </marker>
        <marker
            id={id + "p"}
            viewBox="0 0 10 10"
            refX="9"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto-start-reverse"
        >
            <path d="M0,0 L10,5 L0,10 z" fill="var(--primary)"/>
        </marker>
    </defs>
}

def:pub Box(
    x: float,
    y: float,
    w: float,
    h: float,
    title: str,
    sub: str = "",
    accent: bool = False,
    tone: str = "",
    mono: bool = False
) -> JsxElement {
    stroke = tone or ("var(--primary)" if accent else "var(--border)");
    <g>
        <rect
            x={x}
            y={y}
            width={w}
            height={h}
            rx={10}
            fill={"color-mix(in oklab, "
                + (tone or "var(--primary)")
                + " 12%, var(--card))"
                if accent or tone
                else "var(--card)"}
            stroke={stroke}
            strokeWidth={1.5 if accent or tone else 1}
        />
        <text
            x={x + 12}
            y={y + (h / 2 - 2 if sub else h / 2 + 4)}
            fontSize={13}
            fontWeight={600}
            fill="var(--ink-1)"
            className={"font-mono" if mono else ""}
        >
            {title}
        </text>
        {if sub {
            <text x={x + 12} y={y + h / 2 + 14} fontSize={10.5} fill="var(--ink-muted)">
                {sub}
            </text>
        }}
    </g>
}

def:pub Edge(
    d: str,
    label: str = "",
    lx: float = 0,
    ly: float = 0,
    marker: str = "",
    hot: bool = False,
    dashed: bool = False,
    anchor: str = "middle"
) -> JsxElement {
    <g>
        <path
            d={d}
            fill="none"
            stroke={"var(--primary)" if hot else "var(--ink-muted)"}
            strokeWidth={1.8 if hot else 1.3}
            strokeDasharray={"5 4" if dashed else ""}
            className={"dash-flow" if hot else ""}
            markerEnd={("url(#" + marker + ("p" if hot else "") + ")")
                if marker
                else ""}
        />
        {if label {
            <text
                x={lx}
                y={ly}
                fontSize={10.5}
                textAnchor={anchor}
                fill={"var(--primary)" if hot else "var(--ink-2)"}
            >
                {label}
            </text>
        }}
    </g>
}

def:pub Lane(x: float, y: float, w: float, h: float, label: str) -> JsxElement {
    <g>
        <rect
            x={x}
            y={y}
            width={w}
            height={h}
            rx={16}
            fill="none"
            stroke="var(--border)"
            strokeDasharray="4 4"
        />
        <text
            x={x + 14}
            y={y + 20}
            fontSize={10.5}
            fontWeight={600}
            letterSpacing="0.12em"
            fill="var(--ink-muted)"
        >
            {label}
        </text>
    </g>
}

def:pub ArchitectureDiagram -> JsxElement {
    <svg
        viewBox="0 0 1080 560"
        className="block h-auto w-full"
        role="img"
        aria-label="Three apps share one core; clients call def:pub endpoints through generated RPC stubs and receive live updates over SSE; the server talks to git, gh, the model provider, and the graph store."
    >
        <Arrowheads id="arch"/>
        <Lane x={10} y={20} w={250} h={520} label="CLIENT APPS"/>
        <Lane
            x={300}
            y={20}
            w={470}
            h={520}
            label="JAC SERVER · core/ (one codebase, codespace inferred)"
        />
        <Lane x={810} y={20} w={260} h={520} label="OUTSIDE WORLD"/>
        <Box
            x={30}
            y={60}
            w={210}
            h={70}
            title="web/"
            sub="React SPA compiled from Jac JSX"
            accent={True}
        />
        <Box
            x={30}
            y={230}
            w={210}
            h={70}
            title="mobile/"
            sub="mobUI → React Native (+ this page)"
        />
        <Box
            x={30}
            y={410}
            w={210}
            h={70}
            title="cli/"
            sub="argparse; in-process or --live HTTP"
        />
        <Box
            x={330}
            y={60}
            w={200}
            h={64}
            title="api.jac"
            sub="28 def:pub endpoints"
            mono={True}
            accent={True}
        />
        <Box
            x={550}
            y={60}
            w={200}
            h={64}
            title="live.jac"
            sub="event bus + context pump"
            mono={True}
        />
        <Box
            x={330}
            y={180}
            w={200}
            h={64}
            title="agent/copilot.jac"
            sub="by llm(): 29 tools, streamed"
            mono={True}
        />
        <Box
            x={550}
            y={180}
            w={200}
            h={64}
            title="review/engine.jac"
            sub="7-stage pipeline, 5 LLM roles"
            mono={True}
        />
        <Box
            x={330}
            y={300}
            w={200}
            h={64}
            title="analytics.jac"
            sub="history mining, cached per HEAD"
            mono={True}
        />
        <Box
            x={550}
            y={300}
            w={200}
            h={64}
            title="graph.jac"
            sub="nodes · typed edges · walker"
            mono={True}
        />
        <Box
            x={330}
            y={420}
            w={420}
            h={64}
            title="git/repo.jac · git/diffparse.jac"
            sub="subprocess git, unified-diff → typed FileDiff/Hunk/DiffLine objs"
            mono={True}
        />
        <Box
            x={830}
            y={180}
            w={220}
            h={64}
            title="LLM provider"
            sub="via byLLM → litellm"
            tone="var(--series-7)"
        />
        <Box
            x={830}
            y={300}
            w={220}
            h={64}
            title="Graph store"
            sub="embedded Postgres, per-request commit"
            tone="var(--series-1)"
        />
        <Box
            x={830}
            y={420}
            w={220}
            h={64}
            title="Local git repo + gh"
            sub="the repository under review"
            tone="var(--series-3)"
        />
        <Edge
            d="M240,85 L328,85"
            label="await pr_detail(id)"
            lx={284}
            ly={78}
            marker="arch"
            hot={True}
        />
        <Edge d="M328,105 L240,105" label="SSE frames" lx={284} ly={120} marker="arch"/>
        <Edge d="M240,255 L288,255 L288,118 L328,118" marker="arch" dashed={True}/>
        <text x={135} y={318} fontSize={10.5} textAnchor="middle" fill="var(--ink-2)">
            same typed RPC stubs as web/
        </text>
        <Edge d="M240,430 L304,430 L304,124 L328,124" marker="arch" dashed={True}/>
        <Edge d="M240,460 L328,460" marker="arch"/>
        <text x={135} y={500} fontSize={10.5} textAnchor="middle" fill="var(--ink-2)">
            in-process import, or --live HTTP
        </text>
        <Edge d="M530,92 L548,92" label="emit" lx={539} ly={84} marker="arch"/>
        <Edge
            d="M430,124 L430,178"
            label="spawns turn"
            lx={436}
            ly={156}
            marker="arch"
            anchor="start"
        />
        <Edge d="M530,212 L548,212" marker="arch"/>
        <Edge
            d="M650,178 L650,126"
            label="emit(review · ui)"
            lx={656}
            ly={156}
            marker="arch"
            anchor="start"
        />
        <Edge
            d="M750,212 L828,212"
            label="by llm()"
            lx={789}
            ly={205}
            marker="arch"
            hot={True}
        />
        <Edge
            d="M480,180 L480,160 L790,160 L790,200 L828,200"
            label="by llm() · 29 tools"
            lx={600}
            ly={154}
            marker="arch"
            hot={True}
        />
        <Edge
            d="M750,332 L828,332"
            label="spawn · commit()"
            lx={789}
            ly={325}
            marker="arch"
        />
        <Edge
            d="M750,452 L828,452"
            label="git log / diff / grep"
            lx={789}
            ly={445}
            marker="arch"
        />
        <Edge d="M430,364 L430,418" marker="arch"/>
        <Edge
            d="M650,244 L650,298"
            label="persists"
            lx={656}
            ly={276}
            marker="arch"
            anchor="start"
        />
    </svg>
}

def:pub GraphDiagram -> JsxElement {
    path = "M140,240 C230,240 260,140 360,140 C460,140 480,240 560,240 C640,240 660,140 760,140 C860,140 880,240 960,240";
    <svg
        viewBox="0 0 1080 400"
        className="block h-auto w-full"
        role="img"
        aria-label="root owns Workspace, Repo and ChatThread nodes; Repo has PullRequests, each with Reviews that hold Findings; the CollectFindings walker hops Repo to PullRequest to Review to Finding."
    >
        <Arrowheads id="graph"/>
        <Box
            x={20}
            y={40}
            w={110}
            h={48}
            title="root"
            sub="guest graph"
            tone="var(--series-7)"
            mono={True}
        />
        <Box
            x={40}
            y={210}
            w={130}
            h={56}
            title="Repo"
            sub="path, name"
            accent={True}
            mono={True}
        />
        <Box
            x={290}
            y={110}
            w={150}
            h={56}
            title="PullRequest"
            sub="verdict, risk rollup"
            accent={True}
            mono={True}
        />
        <Box
            x={500}
            y={210}
            w={130}
            h={56}
            title="Review"
            sub="stages, summary"
            accent={True}
            mono={True}
        />
        <Box
            x={700}
            y={110}
            w={130}
            h={56}
            title="Finding"
            sub="sev, line, replies"
            accent={True}
            mono={True}
        />
        <Box
            x={250}
            y={300}
            w={140}
            h={50}
            title="Insight"
            sub="pinned chart spec"
            mono={True}
        />
        <Box
            x={200}
            y={30}
            w={130}
            h={50}
            title="Workspace"
            sub="active repo"
            mono={True}
        />
        <Box
            x={400}
            y={30}
            w={150}
            h={50}
            title="ChatThread"
            sub="transcript + history"
            mono={True}
        />
        <Edge
            d="M75,88 L90,208"
            label="HasRepo"
            lx={60}
            ly={160}
            marker="graph"
            anchor="end"
        />
        <Edge d="M130,60 L198,56" marker="graph"/>
        <Edge
            d="M130,78 C220,104 330,104 398,64"
            label="Talked"
            lx={366}
            ly={100}
            marker="graph"
        />
        <Edge
            d="M170,236 C230,236 230,140 288,140"
            label="HasPR"
            lx={214}
            ly={176}
            marker="graph"
            anchor="end"
        />
        <Edge
            d="M440,140 C480,140 470,236 498,236"
            label="HasReview"
            lx={486}
            ly={176}
            marker="graph"
            anchor="start"
        />
        <Edge
            d="M630,236 C670,236 660,140 698,140"
            label="Found"
            lx={668}
            ly={190}
            marker="graph"
            anchor="start"
        />
        <Edge
            d="M110,266 C110,320 180,325 248,325"
            label="Pinned"
            lx={150}
            ly={318}
            marker="graph"
            anchor="end"
        />
        <path
            d="M105,238 C230,238 230,138 365,138 C470,138 470,238 565,238 C660,238 660,138 765,138"
            fill="none"
            stroke="var(--primary)"
            strokeWidth={2}
            strokeDasharray="2 6"
            opacity={0.7}
        />
        <circle
            r={7}
            fill="var(--primary)"
            stroke="var(--chart-surface)"
            strokeWidth={2}
        >
            <animateMotion
                dur="4.5s"
                repeatCount="indefinite"
                path="M105,238 C230,238 230,138 365,138 C470,138 470,238 565,238 C660,238 660,138 765,138"
            />
        </circle>
        <g>
            <rect
                x={860}
                y={170}
                width={200}
                height={130}
                rx={12}
                fill="color-mix(in oklab, var(--primary) 10%, var(--card))"
                stroke="var(--primary)"
            />
            <text
                x={876}
                y={194}
                fontSize={12}
                fontWeight={600}
                fill="var(--ink-1)"
                className="font-mono"
            >
                walker CollectFindings
            </text>
            <text
                x={876}
                y={216}
                fontSize={10.5}
                fill="var(--ink-2)"
                className="font-mono"
            >
                Repo → visit HasPR
            </text>
            <text
                x={876}
                y={234}
                fontSize={10.5}
                fill="var(--ink-2)"
                className="font-mono"
            >
                PR → visit latest Review
            </text>
            <text
                x={876}
                y={252}
                fontSize={10.5}
                fill="var(--ink-2)"
                className="font-mono"
            >
                Review → visit Found
            </text>
            <text
                x={876}
                y={270}
                fontSize={10.5}
                fill="var(--ink-2)"
                className="font-mono"
            >
                Finding → collect
            </text>
            <text x={876} y={288} fontSize={10} fill="var(--ink-muted)">
                computation travels to the data
            </text>
        </g>
    </svg>
}

def:pub PipelineDiagram(active: int = -1) -> JsxElement {
    stages: list[any] = [
        ["1", "Ingest", "git diff", False],
        ["2", "Triage", "risk + CodeRefs", False],
        ["3", "Plan", "lead LLM", True],
        ["4", "Lenses", "flow workers", True],
        ["5", "Cross-file", "LLM + grep", True],
        ["6", "Investigate", "visit by llm()", True],
        ["7", "Verify", "per-file LLMs", True],
        ["8", "Synthesize", "rule + LLM", True]
    ];
    <svg
        viewBox="0 0 1080 300"
        className="block h-auto w-full"
        role="img"
        aria-label="Eight stages left to right; stage four fans out into parallel reviewers for every file; stage six lets the model route an investigator walker over related code; the verifier removes findings; the verdict follows from what survives."
    >
        <Arrowheads id="pipe"/>
        {for (i, s) in enumerate(stages) {
            <g key={s[0]} opacity={1 if active < 0 or active == i else 0.45}>
                <rect
                    x={14 + i * 133}
                    y={100}
                    width={114}
                    height={70}
                    rx={12}
                    fill={"color-mix(in oklab, var(--series-7) 14%, var(--card))"
                        if s[3]
                        else "color-mix(in oklab, var(--series-3) 14%, var(--card))"}
                    stroke={"var(--primary)"
                        if active == i
                        else ("var(--series-7)" if s[3] else "var(--series-3)")}
                    strokeWidth={2.5 if active == i else 1.2}
                />
                <text x={26 + i * 133} y={128} fontSize={12.5} fontWeight={600} fill="var(--ink-1)">
                    {s[0] + ". " + s[1]}
                </text>
                <text x={26 + i * 133} y={150} fontSize={10} fill="var(--ink-muted)">
                    {s[2]}
                </text>
                {if i < 7 {
                    <path
                        d={"M" + str(128 + i * 133) + ",135 L" + str(147 + i * 133) + ",135"}
                        stroke="var(--ink-muted)"
                        strokeWidth={1.3}
                        markerEnd="url(#pipe)"
                    />
                }}
            </g>
        }}
        {for (k, lens) in enumerate(["solo file", "solo file", "batch"]) {
            <g key={str(k)}>
                <path
                    d={"M" + str(14 + 3 * 133 + 57) + ",170 C" + str(14 + 3 * 133 + 57) + ",200 " + str(372 + k * 84) + ",205 " + str(372 + k * 84) + ",228"}
                    fill="none"
                    stroke="var(--series-7)"
                    strokeWidth={1.2}
                    strokeDasharray="3 3"
                />
                <rect x={334 + k * 84} y={228} width={76} height={24} rx={7} fill="var(--card)" stroke="var(--series-7)"/>
                <text x={372 + k * 84} y={244} fontSize={10} textAnchor="middle" fill="var(--ink-2)">{lens}</text>
            </g>
        }}
        <text x={456} y={278} fontSize={10.5} textAnchor="middle" fill="var(--ink-muted)">
            flow reviewer.review_file(…) · every reviewable file, riskiest solo, the rest batched
        </text>
        {for (k, kind) in enumerate(["CalledFrom", "TestedBy", "ChangesWith"]) {
            <g key={kind}>
                <path
                    d={"M" + str(14 + 5 * 133 + 57) + ",170 C" + str(14 + 5 * 133 + 57) + ",196 " + str(690 + k * 96) + ",204 " + str(690 + k * 96) + ",228"}
                    fill="none"
                    stroke="var(--primary)"
                    strokeWidth={1.2}
                    strokeDasharray={"0" if k == 0 else "3 3"}
                />
                <rect x={646 + k * 96} y={228} width={88} height={24} rx={7} fill="var(--card)" stroke="var(--primary)"/>
                <text x={690 + k * 96} y={244} fontSize={10} textAnchor="middle" fill="var(--ink-2)">{kind}</text>
            </g>
        }}
        <text x={786} y={278} fontSize={10.5} textAnchor="middle" fill="var(--ink-muted)">
            the model picks which CodeRef edges to walk
        </text>
        <g>
            <text x={14 + 6 * 133 + 57} y={70} fontSize={10.5} textAnchor="middle" fill="var(--status-critical)">✕ drops false positives</text>
            <path d={"M" + str(14 + 6 * 133 + 57) + ",76 L" + str(14 + 6 * 133 + 57) + ",98"} stroke="var(--status-critical)" strokeWidth={1.2} strokeDasharray="3 3"/>
        </g>
        <g>
            <text x={14 + 1 * 133 + 57} y={70} fontSize={10.5} textAnchor="middle" fill="var(--series-3)">static patterns → drafts</text>
            <path d={"M" + str(14 + 1 * 133 + 57) + ",76 L" + str(14 + 1 * 133 + 57) + ",98"} stroke="var(--series-3)" strokeWidth={1.2} strokeDasharray="3 3"/>
        </g>
        <g>
            <rect x={14} y={14} width={12} height={12} rx={3} fill="color-mix(in oklab, var(--series-3) 30%, var(--card))" stroke="var(--series-3)"/>
            <text x={32} y={24} fontSize={10.5} fill="var(--ink-2)">deterministic Jac</text>
            <rect x={150} y={14} width={12} height={12} rx={3} fill="color-mix(in oklab, var(--series-7) 30%, var(--card))" stroke="var(--series-7)"/>
            <text x={168} y={24} fontSize={10.5} fill="var(--ink-2)">by llm() with typed output</text>
        </g>
    </svg>
}

def:pub AgentLoopDiagram(active: int = -1) -> JsxElement {
    lanes = [
        "Copilot pane",
        "copilot_stream",
        "worker: byLLM ReAct",
        "Model",
        "tools",
        "live bus",
        "AppShell"
    ];
    msgs: list[any] = [
        [0, 1, "POST message + ui_state (SSE)", 92],
        [1, 2, "run_in_worker(pump)", 122],
        [2, 3, "prompt + 29 tool schemas", 152],
        [3, 2, "tool_call: open_pull_request", 182],
        [2, 4, "execute tool", 212],
        [4, 5, "ui(navigate, /reviews/…)", 242],
        [5, 6, "SSE event (session match)", 272],
        [4, 1, "graph write via pump.call()", 302],
        [2, 1, "tool_call / tool_result frames", 332],
        [1, 0, "frames → chips, cards, tokens", 362],
        [3, 2, "final answer (streamed chunks)", 392]
    ];
    W = 1080;
    gap = (W - 160) / 6;
    <svg
        viewBox={"0 0 " + str(W) + " 430"}
        className="block h-auto w-full"
        role="img"
        aria-label="Sequence of one Copilot turn: the pane streams a request; a worker runs byLLM's ReAct loop; tool calls emit UI events onto the live bus that the shell applies, while graph writes go back through the request context."
    >
        <Arrowheads id="seq"/>
        {for (i, lane) in enumerate(lanes) {
            <g key={lane}>
                <rect
                    x={80 + i * gap - 62}
                    y={20}
                    width={124}
                    height={34}
                    rx={8}
                    fill={"color-mix(in oklab, var(--primary) 14%, var(--card))"
                        if i in (2, 4)
                        else "var(--card)"}
                    stroke={"var(--primary)" if i in (2, 4) else "var(--border)"}
                />
                <text
                    x={80 + i * gap}
                    y={41}
                    fontSize={11}
                    fontWeight={600}
                    textAnchor="middle"
                    fill="var(--ink-1)"
                >
                    {lane}
                </text>
                <line
                    x1={80 + i * gap}
                    x2={80 + i * gap}
                    y1={56}
                    y2={415}
                    stroke="var(--border)"
                    strokeDasharray="3 4"
                />
            </g>
        }}
        {for (k, m) in enumerate(msgs) {
            <g key={str(k)} opacity={1 if active < 0 or active == k else 0.55}>
                <path
                    d={"M"
                        + str(80 + m[0] * gap + (6 if m[1] > m[0] else -6))
                        + ","
                        + str(m[3])
                        + " L"
                        + str(80 + m[1] * gap + (-6 if m[1] > m[0] else 6))
                        + ","
                        + str(m[3])}
                    stroke={"var(--primary)" if active == k else "var(--ink-muted)"}
                    strokeWidth={2 if active == k else 1.3}
                    strokeDasharray={"5 4" if m[1] < m[0] else ""}
                    markerEnd={"url(#seq" + ("p" if active == k else "") + ")"}
                />
                <circle
                    cx={80 + min(m[0], m[1]) * gap + 14}
                    cy={m[3] - 10}
                    r={8}
                    fill="var(--card)"
                    stroke="var(--border)"
                />
                <text
                    x={80 + min(m[0], m[1]) * gap + 14}
                    y={m[3] - 6.5}
                    fontSize={9}
                    textAnchor="middle"
                    fill="var(--ink-2)"
                >
                    {str(k + 1)}
                </text>
                <text
                    x={(160 + (m[0] + m[1]) * gap) / 2 + 8}
                    y={m[3] - 6}
                    fontSize={10.5}
                    textAnchor="middle"
                    fill={"var(--primary)" if active == k else "var(--ink-2)"}
                >
                    {m[2]}
                </text>
            </g>
        }}
    </svg>
}

def:pub WalkerDiagram -> JsxElement {
    <svg
        viewBox="0 0 1080 250"
        className="block h-auto w-full"
        role="img"
        aria-label="The ReviewRun walker's entry abilities launch flow workers that only call the model; its Review exit ability, which runs after every file is visited, writes findings to the graph and commits stage by stage."
    >
        <Arrowheads id="walk"/>
        <Lane x={10} y={20} w={420} h={210} label="WALKER (request context: graph reads, writes, commit())"/>
        <Box x={30} y={56} w={380} h={44} title="can start with Review entry" sub="ingest · triage · CodeRef context · plan · visit files" mono={True}/>
        <Box x={30} y={112} w={380} h={44} title="can lens with FileChange entry" sub="self.submit(Job(…)) → flow run_job(…)" mono={True} accent={True}/>
        <Box x={30} y={168} w={380} h={44} title="can finish with Review exit" sub="gather · anchor · dedupe · investigate · verify · verdict" mono={True}/>
        <Lane x={480} y={20} w={260} h={210} label="FLOW WORKERS (no graph)"/>
        <Box x={500} y={56} w={220} h={44} title="reviewer.review_file" sub="by llm(tools=[self.read_file, …])"/>
        <Box x={500} y={112} w={220} h={44} title="reviewer.review_batch" sub="small files together"/>
        <Box x={500} y={168} w={220} h={44} title="verify_file × N" sub="per-file, in parallel"/>
        <Lane x={790} y={20} w={280} h={210} label="GRAPH"/>
        <Box x={810} y={56} w={240} h={44} title="Review → FileChange → Finding" sub="committed per stage"/>
        <Box x={810} y={112} w={240} h={44} title="FileChange → CodeRef" sub="CalledFrom · TestedBy · ChangesWith"/>
        <Box x={810} y={168} w={240} h={44} title="Investigate walker" sub="visit [-->] by llm(select=(1,3))" accent={True}/>
        <Edge d="M410,134 L498,80" label="flow" lx={452} ly={98} marker="walk" hot={True}/>
        <Edge d="M498,96 C470,140 440,170 412,182" label="as_completed" lx={452} ly={150} marker="walk" dashed={True}/>
        <Edge d="M410,190 L498,190" label="flow" lx={452} ly={184} marker="walk"/>
        <Edge d="M410,62 C560,4 700,4 808,62" label="writes + commit()" lx={609} ly={14} marker="walk"/>
        <Edge d="M410,196 C600,236 760,236 808,196" label="fc spawn Investigate(…)" lx={640} ly={232} marker="walk" hot={True}/>
    </svg>
}
