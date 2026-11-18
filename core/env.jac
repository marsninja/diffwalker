"""Where diffwalker's project is, and the settings its `.env` gives.

A built program is started from the project's root (`neojac run web`), so the project is
the current directory unless `DIFFWALKER_HOME` names it.
"""
import os;

glob PROJECT_DIR: str = os.path.abspath(os.environ.get("DIFFWALKER_HOME", "") or os.getcwd());

def load_env -> int {
    path = os.path.join(PROJECT_DIR, ".env");
    loaded = 0;
    if not os.path.isfile(path) {
        return loaded;
    }
    with open(path, "r") as fh {
        for raw in fh.read().split("\n") {
            line = raw.strip();
            if not line or line.startswith("#") or "=" not in line {
                continue;
            }
            (key, value) = line.split("=", 1);
            if key.strip() and not os.environ.get(key.strip()) {
                os.environ[key.strip()] = value.strip().strip("\"'");
                loaded += 1;
            }
        }
    }
    return loaded;
}

with entry {
    load_env();
}
