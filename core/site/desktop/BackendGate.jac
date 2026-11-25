import from "lucide-react" { Laptop, Server, ArrowLeftRight, LoaderCircle, UserRound, Plus }
def mode_label(mode: str) -> str;

def switch_label(mode: str) -> str;

def mode_blurb(mode: str) -> str;
def:pub BackendGate(children: any) -> JsxElement;
def ProfilePicker(d: Desk, onOpen: Callable[[Desk], None]) -> JsxElement;

def BackendPicker(d: Desk) -> JsxElement;
def:pub ModeSwitch -> JsxElement;
