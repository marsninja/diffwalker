import sys;
import json;
import random;
import from stdjac { ByEventKind, ByUsage, Message, RemoteError, encode }
def short_args(args: UiArgs) -> str;

def run_ask_offline(repo: str, question: str) -> int;

def run_ask_live(server: str, question: str) -> int;
