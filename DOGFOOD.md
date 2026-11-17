# DOGFOOD.md: neojac defects and gaps found by building diffwalker

diffwalker is built with [neojac](https://github.com/marsninja/neojac), and
part of its purpose is to exercise it. When a reasonable Jac idiom, a command
or a documented workflow fails here, the defect or gap is fixed in neojac at
its root cause and never worked around in diffwalker (see
[AGENTS.md](AGENTS.md); rule 4 of neojac's own `AGENTS.md` says the same from
its side). This page records what was found, what fixed it, and what is still
open.

diffwalker was first written for jaseci's `jac`. The record of that compiler's
defects is in this file's git history.

## What has been run

All four apps build. The web app, the CLI (in-process and `--live`) and the
desktop app's two modes were run end to end against a scripted stand-in for
the model API (`ANTHROPIC_BASE_URL`), driving the site in headless Chromium.
The web app and the desktop app were stopped and started again on the data
they kept.
The phone app was built but not run on a device. Nothing has been run against
a real model yet.

## Found and fixed in neojac

Each row is something diffwalker needed that neojac refused, lacked or got
wrong, and what neojac does now. The fixes are on neojac's `diffwalker-compat`
branch.

| Found | What failed | What neojac does now | Where diffwalker uses it |
| --- | --- | --- | --- |
| Calls at once, and stream endpoints | A server answered one call at a time, so a review or a Copilot turn held up every other call for as long as it ran. An endpoint could only return its whole result, so the live feed and the Copilot's answer could not arrive as they were made. | Each call runs on a thread of its own, and one that waits (for the model, for an event another call makes) holds no other up. `root` and the caller belong to the call's thread and to the threads it starts. A function whose result is `Iterator[T]` is a stream endpoint: the server sends each item as the function yields it, and a native caller reads them with `for`. | `live` and `copilot_stream` in `core/api.jac`; `review --live` and `ask --live` in `cli/commands/` |
| `commit()` | The graph was written only when a call returned, so nothing a review wrote was kept until the whole review ended. | `commit()` in `stdjac.graph` writes the graph where it is called. | `ReviewRun` in `core/review/engine.jac` commits after each stage; `core/actions.jac` after each action |
| `visit ... by` | There was no way to let a model choose where a walker goes. | `visit <nodes> by <chooser>;` asks a chooser which of the nodes to visit. It is shown the walker, the node it is at, and each option with the edges that lead to it, each by its type, its `sem` and its fields. `llm(select=..., intent=...)` is one. | `Investigate` in `core/review/engine.jac` |
| `sem` on classes, methods and method parameters | `sem` described a function, a function's parameter and a field. `sem CodeRef = ...`, `sem Reviewer.read_file = ...` and `sem Reviewer.read_file.path = ...` named nothing it knew. | `sem` describes a class, a method and a method's parameter too. | The node and edge types of `core/graph.jac`; `Reviewer`'s tools in `core/review/agents.jac` |
| Tools that are a parameter's methods | A `by` function's tools had to be functions, so a reviewer's tools could not be the methods of the `Reviewer` the call is given. | A tool may be a method of one of the function's parameters, called on that argument: `tools=[r.read_file, r.search_code]`. | `review_file`, `review_batch` and `cross_file_review` in `core/review/agents.jac` |
| A parameter given whole to the plugin | `by llm(conversation=history)` also sent `history` to the model as an argument of the call. | A parameter the `by` expression is given whole is the plugin's, and is not sent as an argument. | `copilot` in `core/agent/copilot.jac` |
| Streamed `by` functions | A `by` function gave its result only once the model had finished. | A `by` function declared to give `Iterator[ByEvent]` is answered as the model goes: each piece of its text, each tool call and its result, and what each request used. | `copilot` in `core/agent/copilot.jac`, read by `_turn` in `core/api.jac` and by `ask` in `cli/commands/ask.jac` |
| `stdjac.llm`: system prompt, typed conversation, parallel tools, usage hook, base URL | `llm()` took no system prompt and kept no conversation between calls. A conversation kept as JSON (`list[dict[str, any]]`) could not be a node's field (E1229, E0109). A round's tool calls ran one at a time, and when run on threads they lost the caller's context variables. Nothing reported what a request used. The API's address was fixed. | `llm()` takes `system_prompt`, `conversation` (a `list[Message]`, which a node may keep, and to which the call adds its turn) and `parallelize` (a round's tool calls at once, each with its caller's context variables). `on_usage` tells a program the tokens of every request, and `on_iteration`'s context carries the call's total. `ANTHROPIC_BASE_URL` names a gateway. | `copilot` and `turn_guard` in `core/agent/copilot.jac`; `ChatThread.history` in `core/graph.jac`; `core/review/meter.jac` |
| Several arrangements in one artifact, chosen where it runs | An app was built as one arrangement of spaces, so a desktop app that runs either against a server or on its own computer was two builds. | `[apps.<app>] profiles` in `jac.toml` lists the archwire profiles one artifact holds. The app starts as the first until its user chooses another; a page asks with `jacArrangement` and chooses with `jacUseArrangement` (`@jac/runtime`), and the app starts again as what was chosen. | `[apps.desktop] profiles = ["default", "local"]`; `core/site/desktop/` |
| Local users | An app in a window that runs its own server still required a sign-in, with nobody to sign in to. | `[apps.<app>] local_users = true` takes the people at the machine as the app's users, with no password, each with a root of their own. Pages list them and sign one in with `jacLocalUsers` and `jacUseLocalUser`. | The desktop app's profiles: `core/site/desktop/desk.jac`, `BackendGate.jac` |
| `None` in a union of classes | `contextvars.ContextVar[Scope \| None]("...", default=None)` was E1053: the `None` of the type argument was lost where the parameter's type was worked out. | `None` is a value of a union of classes, as it is of a class, and a type parameter that stands for a union is spread into the union it is in. | `_scope` in `core/review/meter.jac`; `_ctx` and `_sink` in `core/agent/copilot.jac` |
| A hook called as a statement | `useLiveReload([...], load);` as a statement of a component was E1216, though the same call assigned to a name was accepted. | A hook called as a statement of its own is accepted. | `core/site/pages/Board.jac`, `Dashboard.jac`, `Insights.jac`, `Reviews.jac` |
| A lambda that ends without a value | `lambda { epoch = epoch + 1; }` where a `Callable[[], Coroutine[any, any, None] \| None]` is wanted was E1004. | A lambda that declares no result may end without a value where its result admits `None`. | `core/site/pages/Insights.jac` |
| The truth of a `str` that is `None`, in JavaScript | In a page, `if q.get("file")` was true when the key was missing: a `str`'s truth was a comparison with `""`, which `None` passes. | On a JavaScript host the truth of a `str`, a list, a dict and a set is false for `None`, as it is natively. | `core/site/review/ReviewWorkspace.jac` |
| `async for` over a stream, in a page | A page could not read a stream endpoint with `async for`: what the call gave was not Jac's async iterator. | A JavaScript host's stream is Jac's async iterator. | `start_live` in `core/site/live.jac`; `core/site/copilot/CopilotPane.jac` |
| A node space's calls from a server's call threads | Once calls ran on threads of their own, a call into a node space was made off the thread that started Node, and failed. neojac's own app tests found this; diffwalker has no node space. | A node space's calls are made on the thread that started Node, by the server's loop, for the call's own thread. | Not used |
| `flow` tasks that run at once | A native program evaluated a `flow` task to its end at the `flow`, so the reviewers and the verifiers ran one after another, a stage's drafts reached the screens together when its last call ended, and the review's deadline could not cut a running reviewer short. | `flow f(args)` evaluates the callee and the arguments where it is written and runs the call on a thread of a pool the runtime keeps; `wait` runs a task no thread has taken. A task runs for the caller of the call that made it, with its context variables. | `ReviewRun.gather`, `cross` and `verify` in `core/review/engine.jac`: reviewers and verifiers overlap, and drafts reach the screens as each call ends. |
| A lambda that captures nothing, evaluated often | Each evaluation of `lambda (x: T) -> ... { ... }` with nothing captured took 32 bytes that were never freed. Found while measuring the tasks above. | Such a lambda is one constant closure, as a named function's value is. | Every `key=lambda ...` and callback in the server. |
| Starting again on kept data | The server could not start a second time: `web can't start with the data it kept ... holds 1 core.graph.Review ... whose types this program no longer has`. A module starts on its first use unless it serves an endpoint, the node types are declared in `core/graph.jac`, which serves none, and the store read its rows before that module had started. | A module that declares a node or an edge type the app keeps starts with the program. | `core/graph.jac` and `core/wire.jac`: the web app and the desktop app start again with their reviews. |
| A stream whose reader leaves | A stream whose client had gone was dropped where it paused: a generator had no `close`, so nothing after its `yield` ran, and a Copilot turn whose pane closed mid-answer lost what it had said. | A generator has `close()` and `throw()`, one let go while paused is closed, and the server closes a stream whose client has gone: its `finally` blocks run, and what it wrote is kept. | `_turn` in `core/api.jac` keeps the turn in its `finally`, so a pane closed mid-answer keeps the words it got. |
| A task's type | A task's type could not be written (`list[Task[int]]` was E5090), so a field could not hold one, and `ReviewRun` had to queue its jobs and start every task in one comprehension in `gather`. | `Task[T]` is the type of a task whose value is a `T`. | `Pending.task` in `core/review/engine.jac`: `ReviewRun.submit` starts a file's reviewer where the walker visits the file, and `gather` waits for it in the walker's exit. |
| Memory that one thread allocates and another frees | A block freed by a thread that did not allocate it stayed with the freeing thread for ever, so a server that answers calls on threads grew with every call. | A small block goes back to the page it came from, and a large one past what a thread keeps is any thread's to take. | The server, under any load. |

## Open

Each of these is a defect or gap in neojac that still shows in diffwalker,
either as code left in its natural form or as code written around it. None has
its fix yet.

### Tasks, crossings and streams

| Defect or gap | Where it shows in diffwalker |
| --- | --- |
| A native caller gives a crossing 30 seconds (`RemoteTimeout`), and nothing lets a call say it runs longer. | `start_review` returns when the review ends. `start_on_server` in `cli/commands/review.jac` treats the timeout as "still running", follows the review on the live stream, and reads its outcome with `pr_detail`. |
| A type a crossing's signature names must be wired into the calling module (E1182), and the module must then name it (E1146), even where it only passes the value on. | The `wire ++> [...]` block of `archwire.jac`, and annotations such as `detail: PRDetail = pr_detail(pr_id, "")` in `cli/commands/review.jac`. |
| An endpoint whose result class has a field of a type the caller is not wired is E1308 ("not sendable") where E1182 would name the type and its wire. | Seen while the views were declared in `core/api.jac`. Every type that crosses is in `core/wire.jac`, so nothing waits on it. |
| A class wired from a placed module other than the endpoint's own gets E1182 asking for a wire the archwire already has. | As above: the types that cross are in `core/wire.jac`, a module no space holds. |

### Pages

| Defect or gap | Where it shows in diffwalker |
| --- | --- |
| An effect that makes a lambda is E1225 for the state the lambda reads, though the lambda runs later and reads the state as last shown. Listing the state restarts the effect on every change. | The timer of `AgentWalkthrough` in `core/site/built/Built.jac` calls the component's `def advance`, and `ReviewWorkspace.jac`'s live handler is its `def on_review_event`, where each was a lambda inside the effect. |
| `import from "@jac/runtime" { NoSuchThing }` checks clean; the import fails when the space is bundled. An npm package's missing name is E1145. | Nothing reported that jac's `SignupResult` is not in `@jac/runtime`. The port removed the import from `core/site/auth/SignIn.jac` and `core/native/DiffwalkerMobile.jac`. |
| A JavaScript method read as an item and called (`re[Symbol.replace](s, r)`) is called with no `this`. | Not used. `core/site/markdown.jac` calls `String.prototype.replace.call(s, ...)`. |
| An element written as a statement of an `if` block in JSX is emitted as an item of an array with no key, so React's development build warns. The page renders correctly. | Every `{ if ... { <el /> } }` of the site, for example the tick labels of `BarChart` in `core/site/charts/basic.jac`. |
| The statics of `Number` (`Number.isNaN`, `Number.isFinite`, `Number.MAX_VALUE`) are E1030. | `ago_iso` in `core/site/fmt.jac` uses the global `isNaN`, which means the same for a number. |
| `neojac fmt` lays a JSX element out on one long line when one of its attributes holds a lambda of two or more statements. | The "Previous step" and "Next step" buttons of `AgentWalkthrough` in `core/site/built/Built.jac`, left as the formatter makes them. |

### The language and the library

| Defect or gap | Where it shows in diffwalker |
| --- | --- |
| An enum cannot name its values' type (`enum Severity: str` is E5090). | `Severity`, `Category` and `VerdictKind` in `core/review/agents.jac` are plain enums, and the engine reads `.value` where it needs the string. |
| `sem` cannot describe an enum's member (`sem Severity.CRITICAL = ...` is E2018). | What each severity and verdict means is written in the `sem` of the field that holds it: `DraftFinding.severity`, `Verdict.severity`, `ReviewSummary.verdict`. |
| `os.fdopen` is missing. | `run_login` in `cli/commands/common.jac` opens the token file with `os.open` and passes the descriptor to `open`. |
