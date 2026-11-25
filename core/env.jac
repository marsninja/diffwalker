import os;

glob PROJECT_DIR: str = os.path.abspath(os.environ.get("DIFFWALKER_HOME", "") or os.getcwd());

def load_env -> int;

with entry {
    load_env();
}
