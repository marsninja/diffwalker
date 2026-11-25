"""Token, cost, and latency for one review (or one Copilot turn), split by pipeline stage.

`on_usage` reports what every model request used on the thread that made it, its cost
among it: the plugin prices a request by the rates jac.toml gives it (`[llm.anthropic]
rates`). `metered()` binds a meter and a stage to that thread first, so a request made
in a `flow` task lands on the right review without passing anything through prompts.
"""
import os;
import threading;
import contextvars;
import from stdjac { ByUsage, IterationAction, IterationContext, on_usage }

"""Every token of `usage`: read, written, and kept in or read from the cache."""
def tokens_of(usage: ByUsage) -> int {
    return usage.input_tokens
        + usage.output_tokens
        + usage.cache_read_tokens
        + usage.cache_write_tokens;
}

"""Why a budgeted review of an unpriced model is refused, said where it fails."""
glob UNPRICED: str = "jac.toml gives no rate for the model that answered, so the review's budget cannot be kept: add the model to [llm.anthropic] rates, or set DIFFWALKER_REVIEW_BUDGET=0 to review without one";

"""Whether `usage` has passed `budget` dollars. A request the plugin could not price
counts as having passed it: a budget that cannot be kept is not one."""
def over_budget(usage: ByUsage, budget: float) -> bool {
    cost = usage.cost;
    return usage.requests > 0 and (cost is None or cost > budget);
}

obj Meter {
    has budget: float = 0.0,
        lock: threading.Lock = threading.Lock(),
        rows: dict[str, StageCost] = {},
        order: list[str] = [],
        unpriced: bool = False;

    def add(stage: str, usage: ByUsage) {
        cost = usage.cost;
        with self.lock {
            if stage not in self.rows {
                self.rows[stage] = StageCost(stage=stage);
                self.order.append(stage);
            }
            row = self.rows[stage];
            row.calls += usage.requests;
            row.tokens += tokens_of(usage);
            row.cached += usage.cache_read_tokens;
            if cost is None {
                self.unpriced = True;
            } else {
                row.cost += cost;
            }
            row.ms += usage.seconds * 1000.0;
        }
    }

    """Whether the meter has a budget it cannot keep: a request it took was not priced."""
    def unbudgeted -> bool {
        with self.lock {
            return self.budget > 0 and self.unpriced;
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
                    ms=float(round(r.ms)),
                )
                for r in [self.rows[k] for k in self.order]
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

"""Where the current thread's model requests are billed."""
obj Scope {
    has meter: Meter,
        stage: str;
}

glob _scope: contextvars.ContextVar[Scope | None] = contextvars.ContextVar(
         "diffwalker_meter", default=None
     ),
     _answered: list[str] = [""],
     REVIEW_BUDGET: float = float(os.environ.get("DIFFWALKER_REVIEW_BUDGET", "2.0") or 2.0);

def _record(usage: ByUsage) {
    if usage.model {
        _answered[0] = usage.model;
    }
    scope = _scope.get();
    if scope is not None {
        scope.meter.add(scope.stage, usage);
    }
}

"""The model that answered the last request, and "" before any has."""
def answered_by -> str {
    return _answered[0];
}

"""Run `work` with every model request inside it billed to `meter` under `stage`."""
def metered[T](meter: Meter, stage: str, work: Callable[[], T]) -> T {
    token = _scope.set(Scope(meter=meter, stage=stage));
    try {
        return work();
    } finally {
        _scope.reset(token);
    }
}

"""Bill the requests the current thread makes from here on (the walker's own thread)."""
def bill_to(meter: Meter, stage: str) {
    _scope.set(Scope(meter=meter, stage=stage));
}

def unbill {
    _scope.set(None);
}

"""`on_iteration` hook for every ReAct loop: stop asking for more once a review is over
budget. The meter already holds the requests of the call that asks."""
def budget_guard(ctx: IterationContext) -> IterationAction {
    scope = _scope.get();
    if scope is not None {
        m = scope.meter;
        if m.budget > 0 and (m.unbudgeted() or m.total_cost() > m.budget) {
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }
    return IterationAction.CONTINUE;
}

with entry {
    on_usage(_record);
}
