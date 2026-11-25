import json;
import from stdjac { encode }

def bar(value: float, peak: float, width: int = 24) -> str;

def run_repo(repo: str, as_json: bool) -> int;

def run_prs(repo: str, as_json: bool) -> int;

def run_hotspots(repo: str, limit: int, as_json: bool) -> int;

def run_people(repo: str, as_json: bool) -> int;
