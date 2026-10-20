<div align="center">

<img src="docs/media/logo.svg" width="84" alt="diffwalker logo"/>

# diffwalker

**An agentic code reviewer for your local git repositories, with a Copilot that drives the UI in front of you.**

Point it at a repo. It finds the pull requests (local branches, open GitHub PRs, uncommitted work), reviews each one through an eight-stage pipeline of deterministic analysis and typed LLM calls, anchors every finding to a line of the diff, and lets an agent do anything you can do in the app while you watch.

[![License: MIT](https://img.shields.io/badge/license-MIT-7c5cff.svg)](LICENSE)
[![Built with Jac](https://img.shields.io/badge/built%20with-Jac-ff6b35.svg)](https://jaclang.org)
[![LLM: any LiteLLM model](https://img.shields.io/badge/LLM-any%20LiteLLM%20model-d97757.svg)](#configuration)
[![Apps](https://img.shields.io/badge/apps-web%20·%20mobile%20·%20cli-3987e5.svg)](#three-apps-one-codebase)

<img src="docs/media/diffwalker-demo.gif" alt="Copilot touring the jaseci repository, then switching to a demo repo, running a live review and jumping to the most serious finding" width="100%"/>

<sub>One continuous take, sped up: Copilot tours the <a href="https://github.com/jaseci-labs/jaseci">jaseci</a> repository, pins a hotspot chart, then switches to a demo repo, runs a full review live and lands on the critical finding. <a href="docs/media/diffwalker-demo.mp4">MP4 version</a>.</sub>

</div>

---

## Contents

- [Highlights](#highlights)
- [Quick start](#quick-start)
- [Tour](#tour)
  - [Reviews that stream as they happen](#reviews-that-stream-as-they-happen)
  - [Findings anchored to the diff](#findings-anchored-to-the-diff)
  - [A Copilot that shares your screen](#a-copilot-that-shares-your-screen)
  - [Repository insights](#repository-insights)
  - [Insight board](#insight-board)
  - [Mobile app](#mobile-app)
  - [Command line](#command-line)
  - ["How it's built" page](#how-its-built-page)
- [How a review works](#how-a-review-works)
- [How the Copilot works](#how-the-copilot-works)
- [Three apps, one codebase](#three-apps-one-codebase)
- [Configuration](#configuration)
- [Project layout](#project-layout)
- [Notes on the Jac toolchain](#notes-on-the-jac-toolchain)
- [License](#license)

## Highlights

- **Reviews any local repo.** Local branches ahead of base, open GitHub PRs via `gh`, and your uncommitted worktree all show up as reviewable pull requests.
- **Eight-stage agentic pipeline.** Ingest, deterministic risk triage, planning, parallel specialist reviewers with code-search tools, cross-file analysis, context investigation, adversarial verification, and synthesis. The verifier throws out false positives before you see them.
- **Every finding lands on a line.** Severity, category, confidence, the verifier's reasoning, a suggested change, and Resolve / Dismiss / Reply / Ask Copilot actions, inline in the diff.
- **A Copilot that drives the UI.** 29 tools: it navigates, opens pull requests, scrolls to code, runs reviews, posts and resolves comments, renders charts and Mermaid diagrams, and pins them to a board, all live on your screen. Publishing to GitHub always waits for your click.
- **Repository analytics.** Commit heatmap, weekly volume and churn, commit-type mix, hotspot scatter, contributors and ownership (with knowledge-silo warnings), a treemap of the codebase, and a temporal-coupling network.
- **Spend you can see.** Every review and Copilot turn is metered per stage from model telemetry, shown in the UI and the CLI, and capped by a budget.
- **Web, mobile, and CLI.** One codebase, three apps. The mobile app is real React Native, and the same component is embedded live in the web app. The CLI can drive your open browser.
- **Private per account.** Every endpoint is authenticated, and each user's reviews, Copilot threads, board, and active repository live in their own graph.

## Quick start

You need [Jac](https://jaclang.org) 0.38 (see jaclang.org for the installer), `git`, and a model API key. [`gh`](https://cli.github.com) is optional; with it, open GitHub PRs appear in the queue.

```bash
git clone https://github.com/marsninja/diffwalker
cd diffwalker
echo 'ANTHROPIC_API_KEY=sk-ant-...' > .env     # gitignored; read at startup
jac install                                     # npm + Python dependencies
DIFFWALKER_REPO=/path/to/any/git/repo jac run web
```

Open the printed App URL (usually <http://localhost:8000>), create an account, and you are looking at your repository. Switch repositories any time from the top bar, or ask Copilot to.

### Try the demo repository

The screenshots below use a small payments service whose `feat/refunds` branch contains real bugs. Build it yourself:

```bash
docs/demo/make-demo-repo.sh ~/payments-demo
DIFFWALKER_REPO=~/payments-demo jac run web      # then review the refunds branch
```

## Tour

### Reviews that stream as they happen

Start a review from the queue, the pull request page, the phone, the CLI, or by asking Copilot. Each of the eight stages lights up as it finishes, with what it did; reviewer activity streams in below (drafts as they are found, files as they are reviewed, and the verifier's rejections with its reasons).

<img src="docs/screenshots/review-live.png" alt="A review of jaseci PR #10248 running live: five of eight stages complete, reviewer activity streaming" width="100%"/>

When it completes you get a verdict, a merge-risk gauge, the review's intent and summary, concerns, what was done well, suggested tests, and a per-file walkthrough, plus exactly what the review cost.

<img src="docs/screenshots/review-verdict.png" alt="Completed review: changes requested, risk 95, 14 model calls costing $0.15, one draft rejected by the verifier" width="100%"/>

### Findings anchored to the diff

Findings sit under the line they are about, in a GitHub-style diff with old and new line numbers. Hover any line and press **+** to add your own comment.

<img src="docs/screenshots/review-diff.png" alt="Diff of refunds.py with a critical SQL-injection finding inline, including the verifier's confirmation and a suggested parameterized query" width="100%"/>

The Findings tab gathers them with severity, category, and status filters. Copilot can set those filters too.

<img src="docs/screenshots/review-findings.png" alt="Findings tab: three critical, two high, two medium findings, each with suggested change and verifier note" width="100%"/>

### A Copilot that shares your screen

Ask in plain language. Copilot works through the same actions the buttons use, and every action is visible: chips for each tool call, the screen moving as it navigates, cards for anything it renders.

<img src="docs/screenshots/hero.png" alt="Copilot has switched repositories, reviewed the refunds branch, and opened the critical hard-coded-token finding in the diff while explaining it in the pane" width="100%"/>

<table>
<tr>
<td width="50%"><img src="docs/screenshots/copilot-runs-review.png" alt="Copilot running a full review on request, with critical drafts streaming into the activity feed"/></td>
<td width="50%"><img src="docs/screenshots/copilot-tour.png" alt="Copilot touring the jaseci repository and pinning a hotspot chart"/></td>
</tr>
<tr>
<td><sub>"Review the refunds branch": Copilot starts the pipeline and the drafts stream in.</sub></td>
<td><sub>"Give me a quick tour": Copilot opens the analytics and renders a chart from real numbers.</sub></td>
</tr>
</table>

A turn can be stopped at any moment, long conversations are compacted rather than cut, and each turn has its own spending cap.

### Repository insights

Everything is mined from git history and cached per `HEAD`. Copilot reads the same numbers through its tools, so its answers match the charts.

<img src="docs/screenshots/dashboard.png" alt="Dashboard for the jaseci repository: stat tiles, a year-long commit heatmap, language mix, review queue, and hotspots" width="100%"/>

<table>
<tr>
<td width="50%"><img src="docs/screenshots/insights-activity.png" alt="Activity: commit calendar, commits per week, churn per week"/><br/><sub><b>Activity</b>: a year of commits, weekly volume, churn, and commit types by month.</sub></td>
<td width="50%"><img src="docs/screenshots/insights-hotspots.png" alt="Hotspots: change frequency versus churn scatter"/><br/><sub><b>Hotspots</b>: change frequency against churn; bubble size is the number of authors.</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/insights-people.png" alt="People: contributors and directory ownership with silo warnings"/><br/><sub><b>People</b>: who works where, and which directories are knowledge silos.</sub></td>
<td><img src="docs/screenshots/insights-structure.png" alt="Structure: treemap of directories colored by language"/><br/><sub><b>Structure</b>: the codebase as a treemap, by language or by churn.</sub></td>
</tr>
<tr>
<td colspan="2"><img src="docs/screenshots/insights-coupling.png" alt="Coupling: network of files that change together"/><br/><sub><b>Coupling</b>: files that keep changing in the same commits, a map of hidden dependencies.</sub></td>
</tr>
</table>

### Insight board

Charts, tables, and Mermaid diagrams that Copilot renders can be pinned. They persist next to the repository and survive restarts.

<img src="docs/screenshots/board.png" alt="Insight board with a Mermaid sequence diagram of the SQL injection path, a findings-by-category bar chart, and a severity donut" width="100%"/>

### Mobile app

`mobile/` is a real React Native app written with Jac's mobUI (`View`, `Text`, `Pressable`): sign in, inbox, review with the live pipeline and findings, insights, and its own Copilot, whose navigation moves the phone's tabs. It talks to the same server and the same graph, so resolving a finding on the phone updates the web review.

<p align="center"><img src="docs/screenshots/mobile.png" alt="Three mobile screens: the pull request inbox, a review with findings, and the Copilot tab" width="100%"/></p>

### Command line

The CLI runs the same engine in-process against any repository, with live stage progress, per-stage spend, and an exit code of 1 when changes are requested (useful in hooks and CI). With `--live` it runs on a server instead, and any browser you have open on that server follows along.

<img src="docs/screenshots/cli.png" alt="Terminal: diffwalker review of the refunds branch with stage progress, drafts, verifier results, per-stage spend, and findings" width="100%"/>

```bash
jac run cli -- repo                          # headline facts and 90-day stats
jac run cli -- prs                           # reviewable pull requests
jac run cli -- hotspots -n 10                # churn hotspots
jac run cli -- people                        # most active contributors
jac run cli -- review b-1a2b3c4d5e           # full review, in-process
jac run cli -- ask "which files churn most, and why?"

jac run cli -- --server http://localhost:8001 login --user you --register
jac run cli -- --server http://localhost:8001 review --live b-1a2b3c4d5e
jac run cli -- --server http://localhost:8001 ask --live "open the riskiest PR"
```

### "How it's built" page

The app documents itself: animated diagrams of the architecture, the persistent graph and the walker that traverses it, the review pipeline, and one Copilot turn step by step, each paired with the real source that implements it, pulled live from the running server. The mobile app is embedded in a phone frame on the same page.

<table>
<tr>
<td width="50%"><img src="docs/screenshots/built-architecture.png" alt="Architecture diagram: three client apps, the Jac server modules, the model provider, the graph store, and git"/></td>
<td width="50%"><img src="docs/screenshots/built-agent.png" alt="Sequence diagram of one Copilot turn with the matching source code"/></td>
</tr>
<tr>
<td><img src="docs/screenshots/built-pipeline.png" alt="Interactive review-pipeline diagram with the source of the selected stage"/></td>
<td><img src="docs/screenshots/built-phone.png" alt="The live mobile app embedded in a phone frame"/></td>
</tr>
</table>

## How a review works

A review is a `Review` node with the pipeline's own graph under it:

```mermaid
flowchart LR
    R[Review] -->|Covers| F1[FileChange]
    R -->|Covers| F2[FileChange]
    F1 -->|Raised| X1[Finding]
    F1 -->|CalledFrom / TestedBy / ChangesWith| C1[CodeRef]
    F2 -->|Raised| X2[Finding]
```

`core/review/engine.jac` spawns the `ReviewRun` walker on a fresh `Review`. Its `Review` entry ability ingests, triages, and plans; its `FileChange` entry ability fans each file out to a `flow` worker; its `Review` exit ability, which fires after every file has been visited, does the rest. Each stage is committed as it finishes, so every open screen follows along.

```mermaid
flowchart TB
    subgraph S1[" "]
        direction LR
        A["1 · Ingest<br/>git diff → typed objects"] --> B["2 · Triage<br/>deterministic risk"] --> C["3 · Plan<br/>by llm"] --> D["4 · Specialist lenses<br/>parallel, with tools"]
    end
    subgraph S2[" "]
        direction LR
        E["5 · Cross-file<br/>by llm + grep"] --> F["6 · Investigate<br/>walker picks related code"] --> G["7 · Verify<br/>adversarial by llm"] --> H["8 · Synthesize<br/>verdict"]
    end
    D --> E
```

1. **Ingest.** `git diff base...head` (or the worktree, or `gh pr diff`) is parsed into `FileDiff` / `Hunk` / `DiffLine` objects, including quoted and space-containing paths. GitHub PRs are fetched into `refs/diffwalker/pr/<n>` so reviewers read the PR's actual code.
2. **Triage.** A deterministic 0–100 risk per file from size, the repository's history hotspots, sensitive paths, new branching, missing tests, and word-bounded patterns for secrets, `eval`, `shell=True` and friends, plus `CodeRef` nodes for each file's callers, tests, and co-changing files.
3. **Plan.** `plan_review(...) -> ReviewPlan by llm()` infers the change's intent and assigns lenses and priority per file.
4. **Specialist lenses.** Every reviewable file is reviewed: priority-1 files on their own, the rest batched, each in a `flow` worker. A reviewer is an `obj` whose fields are the prompt context and whose bound methods (`read_file`, `search_code`, `file_history`) are its tools.
5. **Cross-file.** One agent hunts for broken callers and API drift across the whole change.
6. **Investigate.** For each flagged file an `Investigate` walker is spawned on its `FileChange`, and `visit [here-->][?:CodeRef] by llm(select=(1, 3))` lets the model choose which related code to read. Those excerpts become the verifier's evidence and are shown on each finding.
7. **Verify.** Drafts are anchored to commentable diff lines and deduplicated in code, then verified per file, in parallel, keyed by draft id.
8. **Synthesize.** A typed `ReviewSummary` writes the prose. The verdict is recomputed from what survived: any high or critical finding means `request_changes`.

Typed outputs re-ask the model on a malformed reply. Telemetry is billed per review and per stage (`core/review/meter.jac`) and capped by `DIFFWALKER_REVIEW_BUDGET`. Without model credentials the deterministic stages still run and produce a verdict.

## How the Copilot works

`core/agent/copilot.jac` is a single `by llm()` function with 29 tools in four groups:

| Group | Tools |
|---|---|
| Drive the UI | `navigate`, `open_pull_request`, `focus_file`, `filter_findings`, `show_insights`, `notify`, `switch_repository` |
| Read the repository | `list_pull_requests`, `pull_request_details`, `file_diff`, `read_file`, `search_code`, `blame`, `repo_overview`, `hotspot_report`, `contributor_report`, `ownership_report`, `coupling_report`, `activity_report` |
| Change review state | `review_pull_request`, `post_comment`, `update_finding`, `reply_to_finding`, `list_findings`, `export_review`, `publish_to_github` |
| Render insights | `render_chart`, `render_table`, `render_diagram` (cards that pin to the board) |

```mermaid
sequenceDiagram
    participant Pane as Copilot pane
    participant API as copilot_stream
    participant Agent as by llm() ReAct loop
    participant Tools
    participant Bus as live bus
    participant Shell as App shell
    Pane->>API: message + what you are looking at (SSE)
    API->>Agent: run the turn
    Agent->>Tools: tool call (e.g. focus_file)
    Tools->>Bus: ui event, tagged with your session
    Bus-->>Shell: SSE event
    Shell->>Shell: navigate / scroll / filter / toast
    Agent-->>Pane: tool calls, cards, streamed answer
```

- Writes go through `core/actions.jac`, the same functions the buttons call, so Copilot can do anything you can.
- Independent lookups run in parallel; tools that write are serialized.
- A turn stops when you press Stop or when it passes `DIFFWALKER_TURN_BUDGET`.
- UI events are tagged with the user and the browser or CLI session. Each user's live stream carries only their own events, which is how the terminal can drive the same user's browser.
- Publishing to GitHub asks for confirmation in the UI, and the `gh` call is deferred to commit so it can never run twice.

## Three apps, one codebase

```mermaid
flowchart TB
    subgraph clients[Client apps]
        web[web/<br/>React SPA from Jac JSX]
        mobile[mobile/<br/>mobUI → React Native]
        cli[cli/<br/>in-process or --live]
    end
    subgraph core[core/ · one Jac codebase, placement inferred]
        api[api.jac<br/>authenticated endpoints + SSE]
        actions[actions.jac]
        copilot[agent/copilot.jac]
        engine[review/engine.jac]
        graph[graph.jac<br/>nodes · edges · walkers]
        analytics[analytics.jac]
        git[git/]
    end
    web -- typed RPC --> api
    mobile -- typed RPC --> api
    cli -- HTTP --> api
    cli -. in-process .-> engine
    api --> copilot & engine & actions
    copilot & engine --> llm[(LLM via byLLM)]
    actions & engine --> graph --> store[(graph store)]
    engine & analytics --> git --> repo[(local repo + gh)]
```

`jac.toml` declares three apps over a shared `core/`. There are no client and server folders: JSX lands in the browser bundle, subprocess and graph code stays on the server, and a client call such as `await pr_detail(id)` compiles to a typed RPC stub. Imports between modules are declared once in [`archwire.jac`](archwire.jac).

## Configuration

Put secrets in `.env` (gitignored) or the environment.

| Variable | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | | Credentials for the default model provider |
| `BYLLM_DEFAULT_MODEL` | set in `jac.toml` (`[byllm.model]`) | Any [LiteLLM](https://docs.litellm.ai/docs/providers) model id. Use the matching key (`OPENAI_API_KEY`, `GEMINI_API_KEY`, ...), or a local `ollama/...` model with no key |
| `DIFFWALKER_REPO` | the repo containing diffwalker | Default repository for new accounts |
| `DIFFWALKER_REVIEW_BUDGET` | `2.0` | Dollar cap per review |
| `DIFFWALKER_REVIEW_DEADLINE` | `900` | Seconds before a review is cut off |
| `DIFFWALKER_TURN_BUDGET` | `0.75` | Dollar cap per Copilot turn |
| `DIFFWALKER_URL` | `http://localhost:8000` | Server for CLI `--live` commands |
| `DIFFWALKER_TOKEN` / `DIFFWALKER_PASSWORD` | | Non-interactive CLI auth |

The server binds `127.0.0.1` and runs a single worker (the live event bus is in-process). diffwalker runs `git` and `gh` against paths you give it; it is meant for local use, not for exposure on a network.

## Project layout

| Path | Contents |
|---|---|
| `core/api.jac` | Every endpoint (authenticated, plus a public `server_info`), including the SSE streams |
| `core/actions.jac` | Graph mutations shared by endpoints and Copilot tools |
| `core/graph.jac` | Nodes, typed edges with `sem` strings, per-user lookups, and the `CollectFindings` walker |
| `core/review/` | Risk triage, related-code context, reviewer agents, the walker pipeline, and the spend meter |
| `core/agent/copilot.jac` | The Copilot and its tools |
| `core/analytics.jac` | History mining: activity, hotspots, contributors, ownership, structure, coupling |
| `core/git/` | `git` / `gh` access and the unified-diff parser |
| `core/live.jac` | Per-user event bus |
| `core/site/` | Web UI: sign-in, shell, Copilot pane, pages, review workspace, hand-built SVG charts, diagrams |
| `core/native/` | The mobUI phone app, shared by `mobile/` and the web page that embeds it |
| `cli/` | The command-line app |
| `docs/demo/make-demo-repo.sh` | Builds the demo repository used in the screenshots |

Type-check every app with `jac check` (or `jac check --app web`, `--app mobile`, `--app cli`).

## Notes on the Jac toolchain

diffwalker targets Jac 0.38. Building it surfaced several issues, tracked in [jaseci-labs/jac#10234](https://github.com/jaseci-labs/jac/issues/10234); the workarounds in the code cite it:

- `core/env.jac` sets `JAC_DB_RO_UNITS=0`, because the optimistic read-only unit tier would turn a post-`commit()` write in a long review into a replay of the whole endpoint.
- `core/env.jac` also guards a byLLM lookup that can return a function record without its parameters (which would crash every `by llm` call that takes arguments) by falling back to the signature.
- `flow` evaluates its call lazily in the worker, so the engine parks each job under a fresh key and passes only the key.
- The live bus is in-process (one worker) because a streaming request cannot yet observe other requests' commits.

## License

[MIT](LICENSE) © 2026 Jason Mars
