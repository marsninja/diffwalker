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

def build_parser -> argparse.ArgumentParser;

def parse_args(argv: list[str]) -> Invocation;

def dispatch(inv: Invocation) -> int;

def main(argv: list[str]) -> int;

with entry:__main__ {
    sys.exit(main(sys.argv[1:]));
}
