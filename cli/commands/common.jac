import os;
import sys;
import json;
import urllib.request;
import urllib.error;
import getpass;
import stat;

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     COLOR: bool = sys.stdout.isatty() and not os.environ.get("NO_COLOR"),
     DEFAULT_SERVER: str = os.environ.get("DIFFWALKER_URL", "http://localhost:8000");

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
    for candidate in [
        path,
        os.environ.get("DIFFWALKER_REPO", ""),
        os.getcwd(),
        PROJECT_DIR
    ] {
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

def _headers(server: str, sse: bool = False) -> dict[str, str] {
    h = {"Content-Type": "application/json"};
    if sse {
        h["Accept"] = "text/event-stream";
    }
    tok = saved_token(server);
    if tok {
        h["Authorization"] = "Bearer " + tok;
    }
    return h;
}

def _post(server: str, path: str, body: dict[str, any], auth: bool = True, timeout: int = 120) -> dict[str, any] {
    req = urllib.request.Request(
        server.rstrip("/") + path,
        data=json.dumps(body).encode("utf-8"),
        headers=_headers(server) if auth else {"Content-Type": "application/json"},
        method="POST"
    );
    try {
        with urllib.request.urlopen(req, timeout=timeout) as resp {
            return json.loads(resp.read().decode("utf-8"));
        }
    } except urllib.error.HTTPError as e {
        try {
            return json.loads(e.read().decode("utf-8"));
        } except Exception {
            return {"ok": False, "error": {"code": str(e.code), "message": str(e)}};
        }
    }
}

"""Sign in (or register with --register) and keep the token for later --live calls."""
def run_login(server: str, username: str, register: bool) -> int {
    name = username or input("username: ").strip();
    secret = os.environ.get("DIFFWALKER_PASSWORD", "") or getpass.getpass("password: ");
    try {
        if register {
            made = _post(server, "/user/register", {"identities": [{"type": "username", "value": name}], "credential": {"type": "password", "password": secret}}, False);
            if not made.get("ok") {
                warn(red("diffwalker: registration failed: ") + str((made.get("error") or {}).get("message", made)));
                return EXIT_FAILURE;
            }
        }
        got = _post(server, "/user/login", {"identity": {"type": "username", "value": name}, "credential": {"type": "password", "password": secret}}, False);
    } except Exception as e {
        return unreachable(server, e);
    }
    token = str(((got.get("data") or {}).get("token")) or "");
    if not got.get("ok") or not token {
        warn(red("diffwalker: sign-in failed: ") + str((got.get("error") or {}).get("message", "wrong username or password")));
        return EXIT_FAILURE;
    }
    path = _token_file(server);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, stat.S_IRUSR | stat.S_IWUSR);
    with os.fdopen(fd, "w") as fh {
        fh.write(token);
    }
    print(green("signed in as " + name) + dim("  token saved to " + path));
    return EXIT_OK;
}

def post_sse(
    server: str,
    fn: str,
    body: dict[str, any],
    on_frame: Callable[[dict[str, any]], bool]
) -> bool {
    req = urllib.request.Request(
        server.rstrip("/") + "/function/" + fn,
        data=json.dumps(body).encode("utf-8"),
        headers=_headers(server, True),
        method="POST"
    );
    with urllib.request.urlopen(req, timeout=900) as resp {
        event = "";
        for raw in resp {
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n");
            if line.startswith("event:") {
                event = line[6:].strip();
                continue;
            }
            if not line.startswith("data: ") {
                if line == "" {
                    event = "";
                }
                continue;
            }
            if event in ("end", "error") {
                return event == "end";
            }
            try {
                frame = json.loads(line[6:]);
            } except Exception {
                continue;
            }
            if isinstance(frame, dict) and not on_frame(frame) {
                return True;
            }
        }
    }
    return True;
}

"""Call a function endpoint; every argument is passed explicitly (omitted ones would arrive as strings, jaseci-labs/jac#10234)."""
def post_json(server: str, fn: str, body: dict[str, any], timeout: int = 120) -> any {
    payload = _post(server, "/function/" + fn, body, True, timeout);
    if not payload.get("ok") {
        err = payload.get("error") or {};
        raise RuntimeError(str(err.get("code", "")) + ": " + str(err.get("message", "request failed")));
    }
    return (payload.get("data") or {}).get("result");
}

def unreachable(server: str, e: Exception) -> int {
    warn(red("diffwalker: cannot reach " + server) + dim(" (" + str(e)[:120] + ")"));
    if "401" in str(e) or "UNAUTHORIZED" in str(e) {
        warn(dim("hint: sign in first with `jac run cli -- login`"));
    } else {
        warn(dim("hint: start the server with `jac run web`, or set DIFFWALKER_URL / --server"));
    }
    return EXIT_UNAVAILABLE;
}
