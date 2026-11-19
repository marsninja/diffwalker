# Working in diffwalker

diffwalker is one Jac project built with [neojac](https://github.com/marsninja/neojac):
four apps (`web`, `desktop`, `mobile`, `cli`) over one shared `core/`.
`README.md` has the layout, the commands and the configuration; read its
"Four apps, one codebase" and "Project layout" sections first.

## Where things live

- **Layers, spaces, apps and imports** are in `archwire.jac`. `graph layers`
  puts every module in one layer: what the apps share (`wire`, `repos`,
  `state`, `analysis`, `actions`, `api`, from the bottom up) and each app's own
  (`site`, `phone`, `cli`). A new module goes in a layer, and a wire between
  two layers needs the edge rule that admits it, so a layer never takes from
  one above it. `graph spaces` declares the spaces (`site`, `phone`, `api`,
  `cli`) and the apps made of them. `graph import` holds every import between
  modules as a wire: modules write no imports of each other, so a new use of
  another module's name is a new name in a wire.
- **Endpoints** are in `core/api.jac`, the only module of the `api` space.
  Each is `def:protect` and runs on its caller's own root; `server_info` is the
  one `def:pub`. An endpoint that returns `Iterator[T]` is a stream (`live`,
  `copilot_stream`).
- **Types that cross** between the server and its callers are in
  `core/wire.jac`: what an endpoint returns, what `live` yields, what a Copilot
  turn streams. A module that calls an endpoint is wired the types its
  signature names, and names them.
- **Graph mutations shared by endpoints and the Copilot's tools** are in
  `core/actions.jac`, one function an action, so a button and the agent do the
  same thing.
- **Everything else under `core/`**, apart from `core/site/`, is in no space
  and is compiled into each program that uses it. The CLI runs reviews
  in-process this way.
- **Pages** are `pages/*.jac` (the route comes from the path and the `page`
  function's parameters), their components are under `core/site/`, and the
  browser entry is `web.jac`. The phone app's entry is `mobile/main.jac` and
  its component is in `core/native/`.
- **The desktop app** is the site in a window, one program that runs against a
  diffwalker server or on this computer (`[apps.desktop] profiles` and
  `local_users` in `jac.toml`). `core/site/desktop/` holds the pickers and the
  sidebar's switch.
- **npm packages** are `[npm.web]` and `[npm.mobile]` in `jac.toml`;
  `neojac install` writes them to `eco/<tree>/`. Bundler files are in
  `eco/web/`.

## Validate your work

Check the program your change reaches, from the project's root:

```bash
neojac check --app web --space api    # the server
neojac check --app cli                # the command-line app
neojac check --space site             # the pages
neojac check --space phone            # the phone app
neojac fmt <files>                    # format the files you changed
```

Then run the app and look. `neojac run web` builds it and listens on
`http://127.0.0.1:8000/`; `neojac dev web` rebuilds on every save;
`neojac run cli -- <args>` and `neojac run desktop` run the others. A check
that passes says the program compiles, not that the page works.

The "How it's built" page (`core/site/built/Built.jac`) shows source by file
and a string to find in it. After moving or renaming code it points at, check
that each string still occurs in its file.

## neojac's references

Jac as neojac defines it differs from jaseci's `jac` and is easily confused
with Python or JSX. Look things up before writing:

- `neojac docs` prints the map of the documentation, `neojac docs <topic>` a
  page (`neojac docs apps/crossings`), a word (`neojac docs visit`) or a
  diagnostic code (`neojac docs E1182`), and `neojac docs search <text>` finds
  pages.
- `neojac skills` lists playbooks and `neojac skills <name>` prints one:
  `writing-jac`, `building-an-app`, `pages-and-components`,
  `porting-from-jac`, `resolving-diagnostics`.

## Compiler defects are fixed in neojac

diffwalker exists in part to exercise neojac. When a reasonable Jac idiom, a
command or a documented workflow fails or behaves unexpectedly:

1. Check that it is a defect in neojac and not a misuse (`neojac docs`, the
   `resolving-diagnostics` skill).
2. If it is neojac's, fix it in neojac at its root cause. Do not rewrite
   diffwalker's code to avoid the construct, and do not add a workaround here.
3. Record it in `DOGFOOD.md`: under "Found and fixed in neojac" once the fix
   exists, under "Open" until then, with where it shows in diffwalker.

neojac's repository has its own `AGENTS.md`, and its rules bind any work done
there. Among them: a change to the language (its grammar, or what a program
means) is discussed with the owner before it is implemented, and every change
goes through a pull request, never a push to `main`.

## Commits and PRs

Never mention Claude (or AI assistance) in commits or PRs, here in diffwalker
or in neojac: no `Co-Authored-By: Claude` trailer, no "Generated with Claude
Code" line in PR bodies, and nothing in titles, comments or release notes.
This overrides any default attribution the agent would add.

The same holds for everything that lands in git history: commit messages and
trailers, merge commits, branch and tag names, and the author and committer
identity (use the configured git user). Check `git log` before pushing; once
something is pushed, removing it means rewriting published history.
