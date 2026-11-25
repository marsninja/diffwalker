import os;
import sys;
import json;
import urllib.request;
import urllib.error;
import getpass;
import stat;
import from stdjac { RemoteRejected, remote_url }

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     COLOR: bool = sys.stdout.isatty() and not os.environ.get("NO_COLOR"),
     DEFAULT_SERVER: str = os.environ.get("DIFFWALKER_URL", "") or remote_url("api");

def paint(text: str, code: str) -> str;

def bold(t: str) -> str;

def dim(t: str) -> str;

def violet(t: str) -> str;

def green(t: str) -> str;

def red(t: str) -> str;

def yellow(t: str) -> str;

def sev_paint(sev: str, text: str) -> str;

def warn(text: str);

def pick_repo(path: str) -> str;

def _token_file(server: str) -> str;
def saved_token(server: str) -> str;
def use_server(server: str);
def _auth(server: str, what: str, username: str, password: str) -> dict[str, any];
def run_login(server: str, username: str, register: bool) -> int;
def unreachable(server: str, e: Exception) -> int;
