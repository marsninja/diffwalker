import argparse;
import sys;

glob PROG: str = "diffwalker";

obj Invocation {
    has command: str = "",
        target: str = "",
        repo: str = "",
        server: str = DEFAULT_SERVER,
        focus: str = "",
        live: bool = False,
        as_json: bool = False,
        limit: int = 15,
        username: str = "",
        register: bool = False;
}

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Agentic code review for local git repositories. Runs the same engine as the web app, in-process; --live drives a running server instead."
    );
    parser.add_argument(
        "--repo",
        `default="",
        help="repository path (default: the git repo around the current directory)"
    );
    parser.add_argument(
        "--server",
        `default=DEFAULT_SERVER,
        help="server for --live (default $DIFFWALKER_URL or http://localhost:8000)"
    );
    parser.add_argument(
        "--json", dest="as_json", action="store_true", help="machine-readable output"
    );
    commands = parser.add_subparsers(
        dest="command", metavar="<command>", required=True
    );
    login = commands.add_parser("login", help="sign in to a server (for --live); --register creates the account");
    login.add_argument("--user", dest="username", `default="", help="username (prompted when omitted)");
    login.add_argument("--register", action="store_true", help="create the account first");
    commands.add_parser("repo", help="headline facts and 90-day statistics");
    commands.add_parser(
        "prs", help="reviewable pull requests: branches, GitHub PRs, worktree"
    );
    hot = commands.add_parser(
        "hotspots", help="files that change most, weighted by size and recency"
    );
    hot.add_argument(
        "-n", dest="limit", `type=int, `default=15, help="how many to show"
    );
    commands.add_parser("people", help="most active contributors");
    rev = commands.add_parser(
        "review", help="run the eight-stage agentic review on a pull request"
    );
    rev.add_argument(
        "target",
        help="pull request id from `prs` (e.g. b-1a2b3c4d5e, gh-123, worktree)"
    );
    rev.add_argument("--focus", `default="", help="extra focus for the reviewers");
    rev.add_argument(
        "--live",
        action="store_true",
        help="run on the server so the web UI shows it live"
    );
    ask = commands.add_parser(
        "ask", help="ask Copilot; with --live your open browser follows its actions"
    );
    ask.add_argument("target", help="the question");
    ask.add_argument(
        "--live", action="store_true", help="run on the server and drive the web UI"
    );
    return parser;
}

def parse_args(argv: list[str]) -> Invocation {
    ns = build_parser().parse_args(argv);
    return Invocation(
        command=str(getattr(ns, "command", "") or ""),
        target=str(getattr(ns, "target", "") or ""),
        repo=str(getattr(ns, "repo", "") or ""),
        server=str(getattr(ns, "server", DEFAULT_SERVER) or DEFAULT_SERVER),
        focus=str(getattr(ns, "focus", "") or ""),
        live=bool(getattr(ns, "live", False)),
        as_json=bool(getattr(ns, "as_json", False)),
        limit=int(getattr(ns, "limit", 15) or 15),
        username=str(getattr(ns, "username", "") or ""),
        register=bool(getattr(ns, "register", False))
    );
}

def dispatch(inv: Invocation) -> int {
    if inv.command == "login" {
        return run_login(inv.server, inv.username, inv.register);
    }
    if inv.live and inv.command == "review" {
        return run_review_live(inv.server, inv.target, inv.focus);
    }
    if inv.live and inv.command == "ask" {
        return run_ask_live(inv.server, inv.target);
    }
    repo = pick_repo(inv.repo);
    if not repo {
        warn(red("diffwalker: no git repository here") + dim("  (pass --repo PATH)"));
        return EXIT_USAGE;
    }
    if inv.command == "repo" {
        return run_repo(repo, inv.as_json);
    }
    if inv.command == "prs" {
        return run_prs(repo, inv.as_json);
    }
    if inv.command == "hotspots" {
        return run_hotspots(repo, inv.limit, inv.as_json);
    }
    if inv.command == "people" {
        return run_people(repo, inv.as_json);
    }
    if inv.command == "review" {
        return run_review_offline(repo, inv.target, inv.focus, inv.as_json);
    }
    if inv.command == "ask" {
        return run_ask_offline(repo, inv.target);
    }
    warn("diffwalker: unknown command " + inv.command);
    return EXIT_USAGE;
}

def main(argv: list[str]) -> int {
    return dispatch(parse_args(argv));
}

with entry:__main__ {
    sys.`exit(main(sys.argv[1:]));
}
