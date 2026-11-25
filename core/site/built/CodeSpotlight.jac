import from "lucide-react" { FileCode2 }
import from "@jac/runtime" { unsafe_html }

glob KEYWORDS: list[str] = [
         "def",
         "can",
         "walker",
         "node",
         "edge",
         "obj",
         "has",
         "by",
         "sem",
         "glob",
         "import",
         "from",
         "return",
         "if",
         "elif",
         "else",
         "for",
         "in",
         "with",
         "entry",
         "exit",
         "visit",
         "report",
         "spawn",
         "async",
         "await",
         "lambda",
         "impl",
         "enum",
         "try",
         "except",
         "finally",
         "while",
         "not",
         "and",
         "or",
         "is",
         "here",
         "self",
         "root",
         "flow",
         "wait",
         "yield",
         "True",
         "False",
         "None",
     ],
     BUILTIN_TYPES: list[str] = [
         "str",
         "int",
         "float",
         "bool",
         "list",
         "dict",
         "any",
         "JsxElement",
         "JsxPage",
         "Generator",
     ];

def is_word(ch: str) -> bool;

def esc(s: str) -> str;

def:pub highlight(line: str) -> str;

def:pub CodeSpotlight(
    path: str, needle: str = "", before: int = 2, after: int = 14, title: str = ""
) -> JsxElement;
