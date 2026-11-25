import from "lucide-react" {
    FileInput,
    Gauge as GaugeIcon,
    Route,
    ScanSearch,
    Network,
    Telescope,
    ShieldCheck,
    Sparkles,
    LoaderCircle,
    Check,
    X,
    Minus,
}

obj StageMeta {
    has icon: any,
        hint: str;
}

glob STAGE_META: dict[str, StageMeta] = {
    "ingest": StageMeta(icon=FileInput, hint="git diff → typed FileDiff/Hunk objects"),
    "triage": StageMeta(
        icon=GaugeIcon,
        hint="Deterministic risk per file, plus its callers, tests, and co-changing files as CodeRef nodes",
    ),
    "plan": StageMeta(icon=Route, hint="Lead reviewer infers intent and assigns lenses per file"),
    "review": StageMeta(
        icon=ScanSearch,
        hint="A walker visits every file: riskiest reviewed solo, the rest batched, all in flow workers",
    ),
    "cross": StageMeta(icon=Network, hint="Whole-change pass for API drift and broken callers"),
    "investigate": StageMeta(
        icon=Telescope, hint="visit ... by llm(): the model picks which related code to read"
    ),
    "verify": StageMeta(
        icon=ShieldCheck, hint="Per-file adversarial verifiers, in parallel, with that evidence"
    ),
    "synthesize": StageMeta(
        icon=Sparkles, hint="Summary and tests; the verdict follows from what survived"
    ),
};

def:pub default_stages -> list[StageState];

def StatusGlyph(status: str) -> JsxElement;

def StageNode(stage: StageState, index: int, last: bool) -> JsxElement;

def:pub Pipeline(stages: list[StageState]) -> JsxElement;
