import os;
import inspect;

glob PROJECT_DIR: str = os.path.dirname(
         os.path.dirname(os.path.abspath(__file__))
     );

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

def install_byllm_compat -> bool {
    try {
        import from jaclang.runtime.runtime { JacLLM }
    } except Exception {
        return False;
    }
    original: any = JacLLM.fetch_mtir;
    if getattr(original, "_diffwalker_compat", False) {
        return True;
    }
    def fetch_mtir(func: any) -> any {
        info: any = original(func);
        params: any = getattr(info, "params", None);
        if params is None {
            return info;
        }
        try {
            wanted = len(inspect.signature(func).parameters);
        } except Exception {
            return info;
        }
        return None if len(params) < wanted else info;
    }
    setattr(fetch_mtir, "_diffwalker_compat", True);
    JacLLM.fetch_mtir = fetch_mtir;
    return True;
}

with entry {
    load_env();
    # jac 0.38.0 can hand byLLM a function record with an empty parameter list,
    # which crashes every by-llm call that takes arguments (IndexError in
    # MTIR.factory). Falling back to the signature path avoids it.
    install_byllm_compat();
    # Reviews and Copilot turns are long-running writers that commit stage by stage.
    # Jac's optimistic read-only unit tier would turn each post-commit write into a
    # whole-endpoint replay (every model call again), so diffwalker opts out.
    # See jaseci-labs/jac#10234.
    os.environ.setdefault("JAC_DB_RO_UNITS", "0");
}
