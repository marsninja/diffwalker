"""What the commands share: exit codes, colors, the repository to work on, and the server
a `--live` command calls and the account it calls as."""
import os;
import sys;
import json;
import urllib.request;
import urllib.error;
import getpass;
import stat;
import from stdjac.plan { remote_url }
import from stdjac.remote { RemoteRejected }

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     COLOR: bool = sys.stdout.isatty() and not os.environ.get("NO_COLOR"),
     DEFAULT_SERVER: str = os.environ.get("DIFFWALKER_URL", "") or remote_url("api");

def paint(text: str, code: str) -> str {
    return f"\033[{code}m{text}\033[0m" if COLOR else text;
}

def bold(t: str) -> str {
    return paint(t, "1");
}

def dim(t: str) -> str {
    return paint(t, "2");
}

def violet(t: str) -> str {
    return paint(t, "38;5;141");
}

def green(t: str) -> str {
    return paint(t, "32");
}

def red(t: str) -> str {
    return paint(t, "31");
}

def yellow(t: str) -> str {
    return paint(t, "33");
}

def sev_paint(sev: str, text: str) -> str {
    if sev == "critical" {
        return paint(text, "1;31");
    }
    if sev == "high" {
        return paint(text, "38;5;209");
    }
    if sev == "medium" {
        return yellow(text);
    }
    if sev == "low" {
        return paint(text, "34");
    }
    return dim(text);
}

def warn(text: str) {
    print(text, file=sys.stderr);
}

def pick_repo(path: str) -> str {
    for candidate in [path, os.environ.get("DIFFWALKER_REPO", ""), os.getcwd(), PROJECT_DIR] {
        if candidate {
            top = resolve_repo(candidate);
            if top {
                return top;
            }
        }
    }
    return "";
}

def _token_file(server: str) -> str {
    host = server.split("://")[-1].strip("/").replace(":", "_").replace("/", "_");
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config");
    return os.path.join(base, "diffwalker", host + ".token");
}

"""The session token `diffwalker login` saved for this server ($DIFFWALKER_TOKEN wins)."""
def saved_token(server: str) -> str {
    env = os.environ.get("DIFFWALKER_TOKEN", "");
    if env {
        return env;
    }
    try {
        with open(_token_file(server), "r") as fh {
            return fh.read().strip();
        }
    } except Exception {
        return "";
    }
}

"""Send this program's calls of the server to `server`, as the account `login` signed in
there: a crossing goes where `JAC_REMOTE_API` says, with the session in `JAC_REMOTE_TOKEN`."""
def use_server(server: str) {
    os.environ["JAC_REMOTE_API"] = server;
    token = saved_token(server);
    if token {
        os.environ["JAC_REMOTE_TOKEN"] = token;
    }
}

"""Ask the server's accounts to `register` or `login`: its reply, whatever its status."""
def _auth(server: str, what: str, username: str, password: str) -> dict[str, any] {
    req = urllib.request.Request(
        server.rstrip("/") + "/__jac/auth/" + what,
        data=json.dumps({"username": username, "password": password}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    );
    try {
        with urllib.request.urlopen(req, timeout=120) as resp {
            return json.loads(resp.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        try {
            return json.loads(e.read().decode("utf-8"));
        } except ValueError {
            return {"ok": False, "detail": str(e)};
        }
    }
}

"""Sign in (or register with --register) and keep the token for later --live calls."""
def run_login(server: str, username: str, register: bool) -> int {
    name = username or input("username: ").strip();
    secret = os.environ.get("DIFFWALKER_PASSWORD", "") or getpass.getpass("password: ");
    try {
        got = _auth(server, "register" if register else "login", name, secret);
    } except OSError as e {
        return unreachable(server, e);
    }
    data: dict[str, any] = got.get("data") or {};
    token = str(data.get("token") or "");
    if not got.get("ok") or not token {
        warn(
            red("diffwalker: registration failed: " if register else "diffwalker: sign-in failed: ")
                + str(got.get("detail") or "wrong username or password"),
        );
        return EXIT_FAILURE;
    }
    path = _token_file(server);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, stat.S_IRUSR | stat.S_IWUSR);
    with open(fd, "w") as fh {
        fh.write(token);
    }
    print(green("signed in as " + name) + dim("  token saved to " + path));
    return EXIT_OK;
}

"""Say that a call of `server` failed, and what would make it work."""
def unreachable(server: str, e: Exception) -> int {
    warn(red("diffwalker: cannot reach " + server) + dim(" (" + str(e)[:120] + ")"));
    if isinstance(e, RemoteRejected) {
        warn(dim("hint: sign in first with `neojac run cli -- login`"));
    } else {
        warn(dim("hint: start the server with `neojac run web`, or set DIFFWALKER_URL / --server"));
    }
    return EXIT_UNAVAILABLE;
}
