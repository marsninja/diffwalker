# DOGFOOD.md — jac defects found while building diffwalker

When a reasonable Jac idiom, command or documented workflow fails, the defect
is fixed in jaseci-labs/jac rather than worked around in diffwalker (see
[AGENTS.md](AGENTS.md)). The same goes for outdated, wrong or missing
information in a `jac guide` skill or the jac docs that cost time while
working here. This page records those defects and their upstream fixes.

## Current compiler

The `jaseci` submodule pins the compiler source. It points at the
`diffwalker-pin` branch of `marsninja/jac`: upstream main `87267e1c2c` (jac
0.38.1) plus the seven PRs under "Open upstream". `jac.toml`'s
`[dev] jaclang_source = "jaseci/jac"` makes jac use it, and
`scripts/stage_compiler.sh` prepares it (submodule at the pin, typeshed stubs);
build the native kernel once per pin with `jac native build llvm-shim`, then
`jac native build kernel` (it builds `stubcat` too). On this pin `jac check`
passes for all four apps with 0 errors.

Until 2026-10-24 this setup exported `JAC_DEV_SOURCE`, which the launcher never
reads, so every earlier check here ran on the bundled 0.38.1 compiler (see
#10342 below).

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

In the pin:

| Defect | Upstream PR | Found by |
| --- | --- | --- |
| The `jac-sv-persistence` guide and the scale persistence reference said to declare promoted fields under `[scale.database] indexes`; the loader reads them from the top-level `[database]` table, so the key drew "unknown key ... ignored" and diffwalker's id indexes never applied (now moved to `[database]`). The config reference had no `[database]` section. | [#10350](https://github.com/jaseci-labs/jac/pull/10350) | The new `unknown key 'indexes'` warning on the pin |
| The in-process runtime behind the desktop host never set the runtime's target, so project config resolved from the app's output directory: byLLM ignored `[byllm.model]` and sent every review call to `gpt-4o-mini` ("OpenAIException - Missing credentials"). Setting the target also renames the embedded database (`jac_main_*` to `jac_<project>_*`), so the host migrates the old one at boot. | [#10348](https://github.com/jaseci-labs/jac/pull/10348) | The first review run in local mode |
| An app on its own embedded server still needed a sign-in for every protected endpoint, with nobody to sign in to. `[desktop] profiles = true` gives named, passwordless profiles (save slots), each its own user and root; the page boots signed in as the active one. | [#10347](https://github.com/jaseci-labs/jac/pull/10347) (on top of #10345) | Making diffwalker's local mode need no login |
| There was no way to let a desktop app's user choose between its embedded server and a remote one: `[desktop] backend` is fixed at build time, so offering both meant two builds. `[desktop] backends` + `default_backend` now ship every listed backend; the host boots the saved choice, switching relaunches the app, and sessions are per backend. | [#10345](https://github.com/jaseci-labs/jac/pull/10345) | Designing diffwalker's desktop app (local mode or server mode) |
| `build_jab` sealed the whole project root, dropping only build and cache dirs: the project's `.env`, with `ANTHROPIC_API_KEY`, shipped inside the desktop app's `app.jab`, and so did the entire `jaseci/` compiler checkout (about 8,000 files). The deploy bundle already left out `.env`, key files and `.jacignore`'d trees; the seal now uses the same floor and honors `.jacignore` (diffwalker's parks `jaseci/` and `docs/`). | [#10346](https://github.com/jaseci-labs/jac/pull/10346) | Inspecting the first diffwalker desktop build |
| The `jac-native` guide still said to point `JAC_DEV_SOURCE` at a compiler tree; the launcher reads only `[dev] jaclang_source` from the nearest `jac.toml`, and the `[dev]` reference did not say what it requires (path relative to `jac.toml`, typeshed stubs, nearest file only). | [#10342](https://github.com/jaseci-labs/jac/pull/10342) | `@jac/desktop` resolving into the bundled runtime instead of the pinned source |
| A second embedded desktop boot in one process reused the first app's Postgres distribution (the artifact router cached the `postgres` resolution while `host_boot` moved `JAC_PG_HOME`), so every later boot failed with `.../bin/initdb: No such file or directory`; 3 of `test_desktop_host.jac`'s 5 tests failed on upstream main. | [#10341](https://github.com/jaseci-labs/jac/pull/10341) | Running the desktop host tests for #10345 |

Found, not fixed yet:

| Defect | State | Found by |
| --- | --- | --- |
| A whole-workspace `jac check` of diffwalker reports about 40 warnings (W1051 and others) located in jac's own `client/targets/desktop/plugin/desktop_api.jac`, 20 per client app that imports `@jac/desktop`. #10066 keeps a compiler module's warnings out of an application's check, but not on this path. A scratch single-app project and a two-app workspace that import `@jac/desktop` do not reproduce it. | Open: needs a minimal repro | Adding the desktop app |
| In package mode (`jac check jac/jaclang/client`) the checker reported `E1053 Cannot assign DesktopTarget to parameter 'target' of type ClientTarget` in `targets/register.jac` once `DesktopTarget.build` imported `desktop_build`; the file checks clean on its own, and #10345 no longer has that import (the injection belongs in the shells anyway). Probably a class whose base is still being resolved through an import cycle. | Open: needs a minimal repro | Whole-repo check of #10345 |
| Whole-repo `jac check . --nowarn` on the jac repo reports different failures from run to run on near-identical trees: `byllm/llm.jac` with 7 or 27 errors, `client/targets/register.jac` (`Cannot assign DesktopTarget ...`), or `client/targets/desktop/desktop_target.jac` (`super.build` Unknown), each passing when its package is checked. | Open: needs a minimal repro | Validating #10341, #10345 and #10346 |
| Killing the desktop app (SIGTERM, as on logout or `kill`) skips the host's shutdown, so its embedded Postgres keeps running against the app's data dir; closing the window shuts down cleanly. | Open: not yet filed | Restarting the app during QA |
| Launching the embedded desktop app prints `native seam -- demoting ... Native lowering failed` lines for app functions (diffwalker's `core/review/risk.jac`): compiler detail reaching an app's users at startup. | Open: not yet filed | Running the desktop app |
| `jac build --native` ends with `Run with: .//home/.../diffwalker`: it prefixes `./` to an absolute path. | Open: not yet filed | Building the desktop app |
| A built desktop app is not yet a portable install: the launcher puts the project's `.jac/venv` site-packages on the path (litellm, mcp come from the build machine), and run from inside the project the host picks up the `[dev]` compiler source through the nearest `jac.toml`. | Open: not yet filed | Reading the generated `diffwalker-launch.sh` |

## Resolved (merged upstream)

None yet.
