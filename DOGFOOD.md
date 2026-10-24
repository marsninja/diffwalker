# DOGFOOD.md — jac defects found while building diffwalker

When a reasonable Jac idiom, command or documented workflow fails, the defect
is fixed in jaseci-labs/jac rather than worked around in diffwalker (see
[AGENTS.md](AGENTS.md)). The same goes for outdated, wrong or missing
information in a `jac guide` skill or the jac docs that cost time while
working here. This page records those defects and their upstream fixes.

## Current compiler

The `jaseci` submodule pins the compiler source. It points at the
`diffwalker-pin` branch of `marsninja/jac`, which matches upstream main
`87267e1c2c` exactly (jac 0.38.1): no fix is in review yet.
`scripts/stage_compiler.sh` prepares that source (and the typeshed stubs it
needs) and prints the `JAC_DEV_SOURCE` to export; build the native kernel once
per pin with `jac native build llvm-shim`, then `jac native build kernel` (it
builds `stubcat` too). On this pin `jac check` passes for all three apps
(0 errors, 4 W1037 in diffwalker's own code).

## Workarounds to retire

diffwalker was written before this policy, and these workarounds remain from
then. The defects were reported together in
[jaseci-labs/jac#10234](https://github.com/jaseci-labs/jac/issues/10234), but
none has its own fix yet. Each one needs the full workflow: a minimal repro, a
fix on upstream main, a PR, the fix in `diffwalker-pin`, and then deleting the
workaround here (and its bullet under "Notes on the Jac toolchain" in
`README.md`).

| Defect | Workaround in diffwalker | State |
| --- | --- | --- |
| Function endpoints record every default as `str(param.default)` (`ModuleIntrospector.introspect_callable`, `jaclang/server/impl/server.impl.jac:620`), so a REST caller that omits an `int` argument gets the string `"40"`, and the OpenAPI schema shows `{"type": "integer", "default": "40"}`. Walker fields keep the real default. | `cli/commands/common.jac` `post_json` passes every argument explicitly. | Open: still on the pin |
| `flow f(args)` lowers to `thread_run(lambda: f(args))`, so the arguments are evaluated later on the pool thread and not at the `flow` line. E1308 rejects plain locals (contrary to `jac-concurrency`'s "unannotated code is unaffected"), yet accepts attribute reads such as `self.batch`, which race with the caller. | `core/review/engine.jac` `ReviewWalker.submit` parks each job under a fresh key so that only the scalar key crosses. | Open: not yet filed on its own |
| A `flow` worker does not inherit the request's context: `JacContext.thread_run` (`jaclang/runtime/impl/runtime.impl.jac:1932`) submits without `contextvars.copy_context()`, while byLLM's parallel tool pool does copy it. | (Root cause behind the old `Pump`; the rebuild keeps graph writes in the walker's own thread.) | Open: still on the pin |
| A long-lived streaming endpoint never sees other requests' commits, even after calling `commit()`: its anchor cache is never refreshed, and there is no public way to re-read a node. | `core/live.jac` is an in-process event bus, so `jac.toml` pins `[serve.workers] count = 1`. | Open: needs a refresh primitive upstream |
| The optimistic read-only unit tier turns a write made after a mid-request `commit()` into a replay of the whole endpoint, which in a long review means every model call again. In the other direction, a mid-request `commit()` silently loses concurrent updates. | `core/env.jac` sets `JAC_DB_RO_UNITS=0`. | Open: not yet filed on its own |
| jac 0.38.0 can hand byLLM a function record with an empty parameter list, which crashes every `by llm` call that takes arguments (`IndexError` in `MTIR.factory`). | `core/env.jac` `install_byllm_compat` monkey-patches `JacLLM.fetch_mtir` to fall back to the signature. | Open: needs a minimal repro on the pin |
| byLLM's conversation list can hold provider objects (litellm tool-call records), and a node that stores them cannot be read back. | `core/api.jac` `_json_only` round-trips the history through JSON before persisting it. | Open: needs a minimal repro on the pin |
| byLLM's MCP client does not work with the `mcp` 2.x that litellm requires. | `core/agent/copilot.jac` `jac_tools` returns no tools, and the Copilot says so. | Open: needs a minimal repro on the pin |

## Open upstream

In the pin: none.

## Resolved (merged upstream)

None yet.
