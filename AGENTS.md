# Working in this Jac project

diffwalker is a four-app Jac workspace (`web`, `desktop`, `mobile`, `cli`) over
one shared `core/`. Read `README.md` for the layout:

- Endpoints live in `core/api.jac`; graph mutations shared with the Copilot's
  tools live in `core/actions.jac`; imports between modules are declared once
  in `archwire.jac`.
- `desktop` is the web app's pages (`web/desktop.jac` sits beside
  `web/main.jac`, so both route from `web/pages`) in a native window, with a
  run-time choice of backend (`[apps.desktop.desktop.backends]`): the embedded
  server or a diffwalker server. Local mode has no sign-in: `profiles = true`
  gives named profiles, each its own root. `core/site/desktop/BackendGate.jac`
  holds the mode and profile pickers and the sidebar's switch.
- Validate with `jac check` (whole workspace, or `--app web|desktop|mobile|cli`),
  then `jac run web` and `jac browse open localhost:8000`; for the desktop app,
  `jac run desktop`.
- Fix jac bugs, and wrong or missing jac guidance, upstream instead of
  working around them (next section), and record each one in `DOGFOOD.md`.

## Commits and PRs

Never mention Claude (or AI assistance) in commits or PRs, here in diffwalker
or upstream in jac: no `Co-Authored-By: Claude` trailer, no "Generated with
Claude Code" line in PR bodies, and nothing in titles, comments or release
notes. This overrides any default attribution the agent would add.

The same holds for everything that lands in git history, in this repo and in
the `jaseci` submodule: commit messages and trailers, merge commits, branch
and tag names, and the author and committer identity (use the configured git
user). Check `git log` before pushing; once something is pushed, removing it
means rewriting published history.

## Don't work around jac bugs -- fix them upstream

A core goal of diffwalker is to exercise and improve jac itself. The `jaseci`
submodule pins the compiler source this workspace builds with: the
`diffwalker-pin` branch of `marsninja/jac`, which is upstream `jaseci-labs/jac`
main plus the fixes found here that are still in review. `jac.toml`'s
`[dev] jaclang_source = "jaseci/jac"` makes every jac command run in this
project use that source; prepare it after cloning and after every pin move:

```bash
./scripts/stage_compiler.sh
```

It checks the submodule out at the recorded pin and fetches the typeshed stubs,
without which jac prints `ignoring the dev compiler source` and quietly uses its
bundled compiler. Every command on the pinned source prints `jac dev mode —
using compiler source at .../jaseci/jac`; if that line is missing, the pin is
not in use. (There is no `JAC_DEV_SOURCE` variable: the launcher never reads
one.)

Working around a jac bug hides the defect and defeats that goal. When a
reasonable Jac idiom, CLI command or documented workflow fails, errors, or
behaves unexpectedly:

1. First verify it is a jac defect and not a misuse (check the guides, docs,
   examples and tests in the submodule).
2. If it is jac, **pause the affected work and create a proper upstream fix**:
   isolate a minimal repro, fix the root cause on a feature branch based on
   upstream `jac` main, add regression coverage, and run the relevant checks.
   Upstream CI gates on formatting before anything else: from the submodule
   root, run `jac fmt --lintfix` on every `.jac` file the fix touches, then
   `jac check . --nowarn`. The jac repo's lint config strips comments and
   docstrings, so put the rationale in the commit message and release note.
3. Push the fix and open a PR against `jaseci-labs/jac` main with the
   `realdeal` label (`gh pr create --label realdeal ...`). This workflow is
   authorized without asking for separate permission for each defect. The PR
   body must say plainly whether the change is a **proper root-cause fix** or
   a **workaround** (a guard, special case or symptom patch that leaves the
   underlying defect in place). Proper fixes are strongly preferred; ship a
   workaround only when the root cause cannot be fixed now, and then explain
   in the PR body why, and what a proper fix would take. Report the issue,
   validation results, and PR link. Keep Claude out of it, as for diffwalker's
   own commits and PRs (see "Commits and PRs" above).
4. Add the fix to `diffwalker-pin`, bump the `jaseci` submodule here, and
   **resume the original work on the locally fixed compiler** while the PR
   awaits review. Do not wait for the upstream merge unless it is technically
   necessary.
5. Record the defect, its repro and the PR in `DOGFOOD.md`.
6. Do **not** rewrite diffwalker code to avoid the construct, and do not hand
   out a manual workaround in place of a fix. If an upstream fix or PR cannot
   be completed, explain the concrete blocker and continue any independent
   work that remains possible.

Workarounds written before this policy are listed under "Workarounds to
retire" in `DOGFOOD.md`. When the upstream fix for one is in the pin, delete
the workaround here (and its mention in `README.md`) in the same change that
bumps the submodule.

### Guides and docs are in scope

Outdated, wrong or missing information in a `jac guide` skill or in the jac
docs is a defect too, whenever it cost time or led to a wrong attempt: an
example that no longer compiles, a flag or config key that was renamed, a
required step nobody mentions, an error message whose advice is wrong. Do not
just note the correct usage here and move on. Fix the text at its source in
the submodule (`jaseci/jac/jaclang/cli/skills/*.md` for the guides,
`jaseci/jac/jaclang/cli/docs/` for the docs) and take it through the same
steps: a branch off upstream main, a PR against `jaseci-labs/jac` labeled
`realdeal`, the fix added to `diffwalker-pin`, an entry in `DOGFOOD.md`. In place of a regression
test, run every example the corrected text shows on the pinned compiler.

`scripts/stage_compiler.sh` checks the submodule out at the commit this repo
records, so `git add jaseci` after moving the pin and before staging again,
or the fix is silently checked back out. `scripts/refresh.sh` moves the
submodule to the tip of `diffwalker-pin`; commit the bump. When upstream
merges a fix, rebase `diffwalker-pin` onto upstream main so it carries only
what is still in review.

This is a [Jac](https://www.jaseci.org/) project. Jac's syntax has evolved and
is easily confused with Python or JSX -- before writing or editing `.jac`
files, consult the reference guides bundled with the compiler.

## Reference guides

The `jac` CLI ships curated reference guides ("Agent Skills") -- versioned
coding guidance for the installed compiler:

- `jac guide` -- list every available guide
- `jac guide <name>` -- print a guide (e.g. `jac guide jac-types`)
- `jac guide --search <keyword>` -- find guides by topic
- `jac guide --json` -- machine-readable output for tooling

Start with `jac guide jac-essentials`, then load the guide for your task.
Use `jac guide <name> --sections` to list headings and
`jac guide <name> --section <slug>` to retrieve a relevant section.

## Validate your work

- `jac check <file>` -- type-check and lint. Compiler diagnostics link to the
  relevant guide; follow the `-> run 'jac guide ...'` hints.
- `jac run <file>` -- execute a Jac script.
- `jac run --dev main.jac` -- serve a web-app or service in dev mode
  (hot-reload for client files; restart for server changes). Use this instead
  of `jac run` for apps.
- `jac browse <action>` -- QA a running app in a headless browser:
  `jac browse open localhost:8000`, then `snapshot` (accessibility tree with
  `@e1`-style refs), `click @e5`, `fill '#email' user@example.com`, `screenshot`, `close`.

_Generated by `jac create`._
