obj Stage {
    has num: str,
        name: str,
        note: str,
        llm: bool;
}

obj Message {
    has src: int,
        dst: int,
        label: str,
        y: int;
}

def:pub Arrowheads(id: str) -> JsxElement;

def:pub Box(
    x: float,
    y: float,
    w: float,
    h: float,
    title: str,
    sub: str = "",
    accent: bool = False,
    tone: str = "",
    mono: bool = False,
) -> JsxElement;

def:pub Edge(
    d: str,
    label: str = "",
    lx: float = 0,
    ly: float = 0,
    marker: str = "",
    hot: bool = False,
    dashed: bool = False,
    anchor: str = "middle",
) -> JsxElement;

def:pub Lane(x: float, y: float, w: float, h: float, label: str) -> JsxElement;

def:pub ArchitectureDiagram -> JsxElement;

def:pub GraphDiagram -> JsxElement;

def:pub PipelineDiagram(active: int = -1) -> JsxElement;

def:pub AgentLoopDiagram(active: int = -1) -> JsxElement;

def:pub WalkerDiagram -> JsxElement;
