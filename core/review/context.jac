import re;

glob SYMBOL_PATTERNS: list[str] = [
         "^\\s*(?:async\\s+)?def(?::\\w+)?\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:async\\s+)?function\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:abstract\\s+)?class\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:obj|node|edge|walker|enum)(?::\\w+)?\\s+([A-Za-z_]\\w{2,})",
         "^\\s*(?:export\\s+)?(?:const|let)\\s+([A-Za-z_]\\w{2,})\\s*=\\s*(?:async\\s*)?\\(",
         "^\\s*(?:pub\\s+)?fn\\s+([A-Za-z_]\\w{2,})",
         "^\\s*func\\s+(?:\\([^)]*\\)\\s*)?([A-Za-z_]\\w{2,})",
         "^\\s*impl\\s+(?:[A-Za-z_]\\w*\\.)*([A-Za-z_]\\w{2,})",
     ],
     COMMON_NAMES: list[str] = [
         "main",
         "init",
         "run",
         "get",
         "set",
         "test",
         "setup",
         "self",
         "new",
         "start",
         "stop",
         "update",
         "render",
         "handle",
         "postinit",
     ],
     MAX_SYMBOLS: int = 4,
     MAX_CALLERS: int = 3,
     MAX_TESTS: int = 2,
     MAX_COUPLED: int = 3;
def changed_symbols(f: FileDiff) -> list[str];

obj Caller {
    has path: str,
        line: int,
        symbol: str,
        text: str;
}

def _callers(repo: str, ref: str, f: FileDiff) -> list[Caller];

def _tests_for(repo: str, ref: str, f: FileDiff) -> list[str];
def co_changes(repo: str, path: str, limit: int = 3) -> list[tuple[str, int]];
def build_context(repo: str, ref: str, fc: FileChange, f: FileDiff) -> int;
def ref_excerpt(repo: str, ref: str, cr: CodeRef, span: int = 18) -> str;
