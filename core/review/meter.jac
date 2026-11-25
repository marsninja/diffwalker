import os;
import threading;
import contextvars;
import from stdjac { ByUsage, IterationAction, IterationContext, on_usage }
def tokens_of(usage: ByUsage) -> int;

glob UNPRICED: str = "jac.toml gives no rate for the model that answered, so the review's budget cannot be kept: add the model to [llm.anthropic] rates, or set DIFFWALKER_REVIEW_BUDGET=0 to review without one";
def over_budget(usage: ByUsage, budget: float) -> bool;

obj Meter {
    has budget: float = 0.0,
        lock: threading.Lock = threading.Lock(),
        rows: dict[str, StageCost] = {},
        order: list[str] = [],
        unpriced: bool = False;

    def add(stage: str, usage: ByUsage);
    def unbudgeted -> bool;

    def total_cost -> float;

    def breakdown -> list[StageCost];

    def total_calls -> int;

    def total_tokens -> int;
}

obj Scope {
    has meter: Meter,
        stage: str;
}

glob _scope: contextvars.ContextVar[Scope | None] = contextvars.ContextVar(
         "diffwalker_meter", default=None
     ),
     _answered: list[str] = [""],
     REVIEW_BUDGET: float = float(os.environ.get("DIFFWALKER_REVIEW_BUDGET", "2.0") or 2.0);

def _record(usage: ByUsage);
def answered_by -> str;
def metered[T](meter: Meter, stage: str, work: Callable[[], T]) -> T;
def bill_to(meter: Meter, stage: str);

def unbill;
def budget_guard(ctx: IterationContext) -> IterationAction;

with entry {
    on_usage(_record);
}
