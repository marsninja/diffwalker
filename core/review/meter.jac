import os;
import threading;
import contextvars;
import from jaclang.byllm.telemetry { register_agent_callback }
import from jaclang.byllm.types { IterationAction, IterationContext }

"""Token, cost, and latency for one review (or one Copilot turn), split by pipeline stage.

byLLM publishes a telemetry record after every `by llm()` invocation, in the thread
that made it. `metered()` binds a meter and a stage to that thread first, so a record
from a `flow` worker lands on the right review without passing anything through prompts.
"""
obj Meter {
    has budget: float = 0.0,
        lock: any = None,
        rows: dict[str, StageCost] = {},
        order: list[str] = [];

    def postinit {
        self.lock = threading.Lock();
    }

    def add(stage: str, record: dict[str, any]) {
        tokens: dict[str, any] = record.get("tokens") or {};
        total: dict[str, any] = tokens.get("total") or {};
        with self.lock {
            if stage not in self.rows {
                self.rows[stage] = StageCost(stage=stage);
                self.order.append(stage);
            }
            row: StageCost = self.rows[stage];
            row.calls += int(tokens.get("requests", 0) or 1);
            row.tokens += int(total.get("total_tokens", 0) or 0);
            row.cached += int(total.get("cache_read_input_tokens", 0) or 0);
            row.cost += float(total.get("cost", 0.0) or 0.0);
            row.ms += float(record.get("latency_ms", 0.0) or 0.0);
        }
    }

    def total_cost -> float {
        with self.lock {
            return sum([r.cost for r in self.rows.values()]);
        }
    }

    def breakdown -> list[StageCost] {
        with self.lock {
            return [
                StageCost(
                    stage=r.stage,
                    calls=r.calls,
                    tokens=r.tokens,
                    cached=r.cached,
                    cost=round(r.cost, 5),
                    ms=round(r.ms)
                ) for r in [self.rows[k] for k in self.order]
            ];
        }
    }

    def total_calls -> int {
        with self.lock {
            return sum([r.calls for r in self.rows.values()]);
        }
    }

    def total_tokens -> int {
        with self.lock {
            return sum([r.tokens for r in self.rows.values()]);
        }
    }
}

glob _scope: any = contextvars.ContextVar("diffwalker_meter", `default=None),
     REVIEW_BUDGET: float = float(os.environ.get("DIFFWALKER_REVIEW_BUDGET", "2.0") or 2.0);

def _record(record: dict[str, any]) {
    scope = _scope.get();
    if scope {
        scope[0].add(scope[1], record);
    }
}

"""Run `fn(*args)` with every LLM call inside it billed to `meter` under `stage`."""
def metered(meter: Meter, stage: str, fn: Callable[..., any], *args: any) -> any {
    token = _scope.set([meter, stage]);
    try {
        return fn(*args);
    } finally {
        _scope.reset(token);
    }
}

"""Bill the calls the current thread makes from here on (the walker's own thread)."""
def bill_to(meter: Meter, stage: str) {
    _scope.set([meter, stage]);
}

def unbill {
    _scope.set(None);
}

"""`on_iteration` hook for every ReAct loop: stop asking for more once a review is over budget."""
def budget_guard(ctx: IterationContext) -> IterationAction {
    scope = _scope.get();
    if scope {
        m: Meter = scope[0];
        if m.budget > 0 and m.total_cost() + ctx.total_cost > m.budget {
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }
    return IterationAction.CONTINUE;
}

with entry {
    register_agent_callback(_record);
}
