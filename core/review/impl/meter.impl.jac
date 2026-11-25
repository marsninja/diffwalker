impl tokens_of(usage: ByUsage) -> int {
    return usage.input_tokens
        + usage.output_tokens
        + usage.cache_read_tokens
        + usage.cache_write_tokens;
}

impl over_budget(usage: ByUsage, budget: float) -> bool {
    cost = usage.cost;
    return usage.requests > 0 and (cost is None or cost > budget);
}

impl Meter.add(stage: str, usage: ByUsage) {
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

impl Meter.unbudgeted -> bool {
    with self.lock {
        return self.budget > 0 and self.unpriced;
    }
}

impl Meter.total_cost -> float {
    with self.lock {
        return sum([r.cost for r in self.rows.values()]);
    }
}

impl Meter.breakdown -> list[StageCost] {
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

impl Meter.total_calls -> int {
    with self.lock {
        return sum([r.calls for r in self.rows.values()]);
    }
}

impl Meter.total_tokens -> int {
    with self.lock {
        return sum([r.tokens for r in self.rows.values()]);
    }
}

impl _record(usage: ByUsage) {
    if usage.model {
        _answered[0] = usage.model;
    }
    scope = _scope.get();
    if scope is not None {
        scope.meter.add(scope.stage, usage);
    }
}

impl answered_by -> str {
    return _answered[0];
}

impl metered[T](meter: Meter, stage: str, work: Callable[[], T]) -> T {
    token = _scope.set(Scope(meter=meter, stage=stage));
    try {
        return work();
    } finally {
        _scope.reset(token);
    }
}

impl bill_to(meter: Meter, stage: str) {
    _scope.set(Scope(meter=meter, stage=stage));
}

impl unbill {
    _scope.set(None);
}

impl budget_guard(ctx: IterationContext) -> IterationAction {
    scope = _scope.get();
    if scope is not None {
        m = scope.meter;
        if m.budget > 0 and (m.unbudgeted() or m.total_cost() > m.budget) {
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }
    return IterationAction.CONTINUE;
}
