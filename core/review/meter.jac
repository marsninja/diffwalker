"""Token, cost, and latency for one review (or one Copilot turn), split by pipeline stage.

`stdjac.llm` reports the usage of every model request on the thread that made it.
`metered()` binds a meter and a stage to that thread first, so a request made in a
`flow` task lands on the right review without passing anything through prompts.
"""
import os;
import threading;
import contextvars;
import from stdjac.by { ByUsage }
import from stdjac.llm { IterationAction, IterationContext, on_usage }

"""What a model charges, in dollars per million tokens."""
obj Rate {
    has input: float,
        output: float,
        cache_read: float,
        cache_write: float;
}

"""The models diffwalker prices. A request to any other model costs nothing here."""
glob RATES: dict[str, Rate] = {
    "claude-sonnet-5-5": Rate(input=2.0, output=10.0, cache_read=0.1, cache_write=2.5),
    "claude-opus-5-5": Rate(input=4.0, output=20.0, cache_read=0.2, cache_write=5.0),
    "claude-haiku-5-5": Rate(input=0.1, output=0.5, cache_read=0.01, cache_write=0.125),
};

"""What `usage` cost in dollars, by its model's rates."""
def cost_of(usage: ByUsage) -> float {
    rate = RATES.get(usage.model);
    if rate is None {
        return 0.0;
    }
    return (
        usage.input_tokens * rate.input
        + usage.output_tokens * rate.output
        + usage.cache_read_tokens * rate.cache_read
        + usage.cache_write_tokens * rate.cache_write
    )
        / 1000000.0;
}

"""Every token of `usage`: read, written, and kept in or read from the cache."""
def tokens_of(usage: ByUsage) -> int {
    return usage.input_tokens
        + usage.output_tokens
        + usage.cache_read_tokens
        + usage.cache_write_tokens;
}

obj Meter {
    has budget: float = 0.0,
        lock: threading.Lock = threading.Lock(),
        rows: dict[str, StageCost] = {},
        order: list[str] = [];

    def add(stage: str, usage: ByUsage) {
        with self.lock {
            if stage not in self.rows {
                self.rows[stage] = StageCost(stage=stage);
                self.order.append(stage);
            }
            row = self.rows[stage];
            row.calls += usage.requests;
            row.tokens += tokens_of(usage);
            row.cached += usage.cache_read_tokens;
            row.cost += cost_of(usage);
            row.ms += usage.seconds * 1000.0;
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
     REVIEW_BUDGET: float = float(os.environ.get("DIFFWALKER_REVIEW_BUDGET", "2.0") or 2.0);

def _record(usage: ByUsage) {
    scope = _scope.get();
    if scope is not None {
        scope.meter.add(scope.stage, usage);
    }
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
        if m.budget > 0 and m.total_cost() > m.budget {
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }
    return IterationAction.CONTINUE;
}

with entry {
    on_usage(_record);
}
