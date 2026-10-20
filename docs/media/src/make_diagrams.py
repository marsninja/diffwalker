"""Generate the README diagrams as self-contained SVGs.

Run: python3 docs/media/src/make_diagrams.py
Writes docs/media/diagram-*.svg. Each SVG draws its own dark panel so it
reads the same on GitHub's light and dark themes.
"""
import os
from html import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

BG = "#0f0e15"
CARD = "#17161f"
LINE = "#2c2a38"
INK = "#ecebf3"
INK2 = "#b9b6c9"
MUTED = "#8a879c"
VIOLET = "#7c5cff"
VIOLET_SOFT = "#2a2347"
GREEN = "#1baf7a"
GREEN_SOFT = "#11302a"
BLUE = "#3987e5"
BLUE_SOFT = "#132a45"
RED = "#e66767"
AMBER = "#eda100"
AMBER_SOFT = "#3a2c0c"

FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif"
MONO = "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"

STYLE = f"""
<style>
  .t{{font-family:{FONT};fill:{INK}}}
  .m{{font-family:{MONO};fill:{INK2}}}
  .s{{font-family:{FONT};fill:{MUTED}}}
  .flow{{stroke-dasharray:6 6;animation:flow 1.1s linear infinite}}
  @keyframes flow{{to{{stroke-dashoffset:-24}}}}
  .pulse{{animation:pulse 2.4s ease-in-out infinite}}
  @keyframes pulse{{0%,100%{{opacity:.35}}50%{{opacity:1}}}}
  @media (prefers-reduced-motion:reduce){{.flow,.pulse{{animation:none}}}}
</style>"""


def svg(w, h, body, label):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
        f'role="img" aria-label="{escape(label)}">{STYLE}'
        f'<defs>'
        f'<marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0L10,5L0,10z" fill="{MUTED}"/></marker>'
        f'<marker id="av" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0L10,5L0,10z" fill="{VIOLET}"/></marker>'
        f'<marker id="ag" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0L10,5L0,10z" fill="{GREEN}"/></marker>'
        f'<marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0L10,5L0,10z" fill="{RED}"/></marker>'
        f'<radialGradient id="glow" cx="50%" cy="0%" r="80%"><stop offset="0" stop-color="{VIOLET}" stop-opacity=".22"/><stop offset="1" stop-color="{VIOLET}" stop-opacity="0"/></radialGradient>'
        f'</defs>'
        f'<rect width="{w}" height="{h}" rx="18" fill="{BG}"/>'
        f'<rect width="{w}" height="{h}" rx="18" fill="url(#glow)"/>'
        f'<rect x=".5" y=".5" width="{w-1}" height="{h-1}" rx="18" fill="none" stroke="{LINE}"/>'
        f"{body}</svg>"
    )


BUMP = {10: 12.5, 10.5: 13, 11: 13.5, 11.5: 14, 12: 14.5, 12.5: 14.5, 13: 15, 13.5: 15.5, 14: 16.5, 15: 17, 22: 26}


def text(x, y, s, cls="t", size=14, weight=400, anchor="start", fill=None, extra=""):
    size = BUMP.get(size, size)
    f = f' fill="{fill}"' if fill else ""
    return (
        f'<text x="{x}" y="{y}" class="{cls}" font-size="{size}" font-weight="{weight}" '
        f'text-anchor="{anchor}"{f} {extra}>{escape(s)}</text>'
    )


def box(x, y, w, h, fill=CARD, stroke=LINE, r=12, sw=1.2, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>'


def line(d, color=MUTED, marker="a", width=1.6, cls="", dash=""):
    da = f' stroke-dasharray="{dash}"' if dash else ""
    c = f' class="{cls}"' if cls else ""
    m = f' marker-end="url(#{marker})"' if marker else ""
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}"{da}{c}{m}/>'


def chip(x, y, label, color, soft):
    w = 18 + len(label) * 8.2
    return box(x, y - 2, w, 24, fill=soft, stroke=color, r=12, sw=1) + text(x + w / 2, y + 15, label, "m", 11, 500, "middle", fill=color)


# ---------------------------------------------------------------- pipeline
def pipeline():
    W, H = 1180, 452
    stages = [
        ("Ingest", "git diff → FileDiff", "det"),
        ("Triage", "risk + CodeRefs", "det"),
        ("Plan", "intent · lenses", "llm"),
        ("Lenses", "file reviewers", "llm"),
        ("Cross-file", "API drift", "llm"),
        ("Investigate", "picks evidence", "llm"),
        ("Verify", "adversarial pass", "llm"),
        ("Synthesize", "verdict", "llm"),
    ]
    x0, y0, bw, bh, gap = 34, 168, 134, 86, 8
    b = []
    b.append(text(34, 50, "The review pipeline", "t", 22, 700))
    b.append(text(34, 76, "Eight stages, each committed to the graph as it finishes, so every open screen follows along.", "s", 14))
    # legend
    b.append(box(W - 440, 38, 14, 14, GREEN_SOFT, GREEN, 4) + text(W - 418, 50, "deterministic Jac", "s", 12.5))
    b.append(box(W - 292, 38, 14, 14, VIOLET_SOFT, VIOLET, 4) + text(W - 270, 50, "typed by llm() call", "s", 12.5))
    b.append(box(W - 132, 38, 14, 14, "#3a1717", RED, 4) + text(W - 110, 50, "rejections", "s", 12.5))
    centers = []
    for i, (name, sub, kind) in enumerate(stages):
        x = x0 + i * (bw + gap)
        color, soft = (GREEN, GREEN_SOFT) if kind == "det" else (VIOLET, VIOLET_SOFT)
        b.append(box(x, y0, bw, bh, soft, color, 14, 1.4))
        b.append(f'<circle cx="{x+20}" cy="{y0+22}" r="11" fill="{BG}" stroke="{color}"/>')
        b.append(text(x + 20, y0 + 26.5, str(i + 1), "t", 12, 700, "middle", fill=color))
        b.append(text(x + 37, y0 + 27, name, "t", 15, 650))
        b.append(text(x + 14, y0 + 56, sub, "s", 11.5))
        b.append(text(x + 14, y0 + 73, "flow worker" if name in ("Lenses", "Verify") else "", "m", 10.5, fill=MUTED))
        centers.append(x + bw / 2)
        if i < len(stages) - 1:
            hot = i >= 2
            b.append(line(f"M{x+bw+2},{y0+bh/2} L{x+bw+gap-2},{y0+bh/2}", VIOLET if hot else GREEN, "av" if hot else "ag", 1.8))
    # triage static hits -> drafts
    tx = centers[1]
    b.append(line(f"M{tx},{y0} L{tx},{y0-26}", AMBER, "", 1.4, dash="3 3"))
    b.append(chip(tx - 98, y0 - 48, "static hits → drafts", AMBER, AMBER_SOFT))
    # lenses fan-out
    lx = centers[3]
    fy = y0 + bh + 56
    lenses = [("correctness", -112), ("security", 0), ("reliability", 112)]
    for (lab, dx) in lenses:
        cx = lx + dx
        b.append(line(f"M{lx},{y0+bh} C{lx},{fy-30} {cx},{fy-34} {cx},{fy-2}", VIOLET, "av", 1.3, "flow"))
        b.append(box(cx - 52, fy, 104, 28, CARD, VIOLET, 14, 1.1) + text(cx, fy + 19, lab, "m", 11, 500, "middle", fill=INK2))
    b.append(text(lx, fy + 52, "each reviewer is an obj whose bound methods", "s", 11.5, anchor="middle"))
    b.append(text(lx, fy + 68, "read_file · search_code · file_history are its tools", "s", 11.5, anchor="middle"))
    # investigate: walker picks coderefs
    ix = centers[5]
    b.append(line(f"M{ix},{y0+bh} L{ix},{fy-2}", VIOLET, "av", 1.3, dash="3 3"))
    b.append(box(ix - 106, fy, 226, 50, CARD, LINE, 10))
    b.append(text(ix + 7, fy + 21, "visit [here-->][?:CodeRef]", "m", 11, 500, "middle", fill=INK2))
    b.append(text(ix + 7, fy + 40, "by llm(select=(1, 3))", "m", 11, 500, "middle", fill=VIOLET))
    # verify drops
    vx = centers[6]
    b.append(line(f"M{vx},{y0} L{vx},{y0-26}", RED, "", 1.4, dash="3 3"))
    b.append(box(vx - 104, y0 - 50, 208, 24, "#3a1717", RED, 12, 1) + text(vx, y0 - 33, "✕ drops false positives", "m", 11, 500, "middle", fill=RED))
    # synthesize verdict
    sx = centers[7]
    b.append(line(f"M{sx},{y0+bh} L{sx},{fy-2}", VIOLET, "av", 1.3))
    b.append(box(sx - 84, fy, 152, 50, VIOLET_SOFT, VIOLET, 10))
    b.append(text(sx - 8, fy + 21, "request_changes", "m", 11.5, 600, "middle", fill=INK))
    b.append(text(sx - 8, fy + 40, "risk 95 · $0.13", "m", 11, 500, "middle", fill=INK2))
    b.append(text(34, H - 22, "Budget-capped per review (DIFFWALKER_REVIEW_BUDGET); typed outputs re-ask the model on a malformed reply.", "s", 12))
    return svg(W, H, "".join(b), "Eight-stage review pipeline: ingest and triage are deterministic; plan, parallel lenses, cross-file, investigate, verify and synthesize are typed LLM calls. The verifier drops false positives.")


# ---------------------------------------------------------------- graph
def node(x, y, w, h, kind, title, fields, color, soft):
    out = box(x, y, w, h, soft, color, 12, 1.4)
    out += text(x + 14, y + 22, kind, "m", 10.5, 600, fill=color)
    out += text(x + 14, y + 44, title, "t", 15, 650)
    for i, f in enumerate(fields):
        out += text(x + 14, y + 64 + i * 15, f, "m", 10.5, fill=MUTED)
    return out


def elabel(x, y, s, color=INK2):
    w = 16 + len(s) * 7.9
    return box(x - w / 2, y - 13, w, 24, BG, LINE, 7, 1) + text(x, y + 4, s, "m", 10.5, 500, "middle", fill=color)


def graph():
    W, H = 1180, 470
    b = [text(34, 50, "A review is a graph", "t", 22, 700),
         text(34, 76, "Nodes and typed edges persist under each user's root. Walkers carry the computation to the data.", "s", 14)]
    R = (40, 200, 170, 100)
    F1 = (330, 120, 190, 100)
    F2 = (330, 290, 190, 100)
    X1 = (660, 110, 180, 92)
    C1 = (660, 236, 180, 92)
    X2 = (660, 340, 180, 92)
    b.append(node(*R, "node", "Review", ["verdict · risk · stages", "spend per stage"], VIOLET, VIOLET_SOFT))
    b.append(node(*F1, "node", "FileChange", ["path · risk · lenses", "state · summary"], BLUE, BLUE_SOFT))
    b.append(node(*F2, "node", "FileChange", ["path · risk · lenses", "state · summary"], BLUE, BLUE_SOFT))
    b.append(node(*X1, "node", "Finding", ["severity · line", "suggestion · replies"], RED, "#341a1d"))
    b.append(node(*C1, "node", "CodeRef", ["caller · test ·", "co-changing file"], GREEN, GREEN_SOFT))
    b.append(node(*X2, "node", "Finding", ["severity · line", "suggestion · replies"], RED, "#341a1d"))
    b.append(line(f"M210,235 C270,235 270,170 328,170", MUTED, "a"))
    b.append(line(f"M210,265 C270,265 270,340 328,340", MUTED, "a"))
    b.append(elabel(268, 200, "Covers"))
    b.append(elabel(268, 304, "Covers"))
    b.append(line(f"M520,160 L658,156", MUTED, "a"))
    b.append(elabel(590, 158, "Raised"))
    b.append(line(f"M520,190 C590,190 590,282 658,282", GREEN, "ag", 1.6))
    b.append(elabel(588, 236, "CalledFrom / TestedBy", GREEN))
    b.append(line(f"M520,340 C590,340 590,386 658,386", MUTED, "a"))
    b.append(elabel(590, 372, "Raised"))
    # walker path + dot
    wp = "M210,235 C270,235 270,170 328,170 L520,170 L520,190 C590,190 590,282 658,282"
    b.append(f'<circle r="11" fill="{VIOLET}" opacity=".25"><animateMotion dur="4.2s" repeatCount="indefinite" path="{wp}" keyPoints="0;1;1" keyTimes="0;.85;1" calcMode="linear"/></circle>')
    b.append(f'<circle r="6" fill="{VIOLET}" stroke="#fff" stroke-width="1.5"><animateMotion dur="4.2s" repeatCount="indefinite" path="{wp}" keyPoints="0;1;1" keyTimes="0;.85;1" calcMode="linear"/></circle>')
    # walker card
    cx = 890
    b.append(box(cx, 120, 256, 236, CARD, VIOLET, 14, 1.4))
    b.append(text(cx + 18, 148, "walker Investigate", "m", 13, 650, fill=VIOLET))
    rows = [
        ("FileChange", "visit [here-->][?:CodeRef]"),
        ("", "by llm(select=(1, 3))"),
        ("CodeRef", "read the excerpt,"),
        ("", "attach it as evidence"),
    ]
    y = 178
    for (k, v) in rows:
        if k:
            b.append(text(cx + 18, y, k + " entry", "m", 11, 600, fill=INK))
            y += 18
        b.append(text(cx + 30, y, v, "m", 11, fill=INK2))
        y += 20
    b.append(f'<line x1="{cx+18}" y1="{y-4}" x2="{cx+238}" y2="{y-4}" stroke="{LINE}"/>')
    b.append(text(cx + 18, y + 18, "The model chooses which related", "s", 12))
    b.append(text(cx + 18, y + 35, "code to read; the verifier sees it.", "s", 12))
    b.append(text(34, H - 22, "Other walkers: ReviewRun drives the pipeline (Review entry → FileChange entry → Review exit); CollectFindings feeds the dashboard.", "s", 12))
    return svg(W, H, "".join(b), "Review node covers FileChange nodes, which raise Findings and link to CodeRefs; the Investigate walker visits CodeRefs chosen by the model.")


# ---------------------------------------------------------------- copilot turn
def copilot():
    W, H = 1180, 560
    lanes = ["Copilot pane", "copilot_stream", "by llm() loop", "Tools", "Live bus", "App shell"]
    hi = {2, 3}
    x0, gap = 110, 192
    xs = [x0 + i * gap for i in range(len(lanes))]
    b = [text(34, 50, "One Copilot turn", "t", 22, 700),
         text(34, 76, "Every tool that changes the screen becomes an event the UI applies, so you watch the agent work.", "s", 14)]
    for i, (lab, x) in enumerate(zip(lanes, xs)):
        c, s = (VIOLET, VIOLET_SOFT) if i in hi else (LINE, CARD)
        b.append(box(x - 74, 100, 148, 38, s, c, 10, 1.3))
        b.append(text(x, 124, lab, "t", 13, 600, "middle"))
        b.append(f'<line x1="{x}" y1="140" x2="{x}" y2="{H-50}" stroke="{LINE}" stroke-dasharray="3 5"/>')
    # loop region
    b.append(box(xs[2] - 96, 222, xs[3] - xs[2] + 192 + gap * 2 - 40, 214, "none", VIOLET, 12, 1.2, 'stroke-dasharray="5 4" opacity=".7"'))
    b.append(box(xs[2] - 96, 220, 196, 26, VIOLET_SOFT, VIOLET, 12, 1))
    b.append(text(xs[2] + 2, 238, "loop until it answers", "m", 10.5, 600, "middle", fill=VIOLET))
    msgs = [
        (0, 1, 176, "message + screen context", False, False),
        (1, 2, 204, "run the turn in a worker", False, False),
        (2, 3, 268, "tool call: focus_file(path, line)", True, False),
        (3, 4, 300, "ui event, tagged with your session", True, False),
        (4, 5, 332, "SSE → the UI moves", True, False),
        (3, 1, 370, "writes go through pump.call() → commit()", False, True),
        (2, 0, 410, "tool chips · chart cards (streamed frames)", False, True),
        (2, 0, 476, "final answer, token by token", False, True),
    ]
    for (a, c, y, lab, hot, back) in msgs:
        xa, xc = xs[a], xs[c]
        d = 1 if xc > xa else -1
        col = VIOLET if hot else (MUTED if not back else INK2)
        b.append(line(f"M{xa + 6*d},{y} L{xc - 6*d},{y}", col, "av" if hot else "a", 1.8 if hot else 1.4, "flow" if hot else "", "" if not back or hot else "5 4"))
        mid = (xa + xc) / 2
        b.append(text(mid, y - 8, lab, "m", 11.5, 500, "middle", fill=INK if hot else INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(f'<circle cx="{xs[5]}" cy="332" r="9" fill="none" stroke="{VIOLET}" stroke-width="2" class="pulse"/>')
    b.append(text(34, H - 20, "Parallel lookups, serialized writes, a Stop button and a per-turn budget (DIFFWALKER_TURN_BUDGET). Publishing to GitHub always waits for your click.", "s", 12))
    return svg(W, H, "".join(b), "Sequence of one Copilot turn: the pane streams a message, a worker runs the by llm tool loop, UI tools emit session-tagged events the app shell applies, writes are committed through the request context, and the answer streams back.")


# ---------------------------------------------------------------- architecture
def arch():
    W, H = 1180, 560
    b = [text(34, 50, "Three apps, one Jac codebase", "t", 22, 700),
         text(34, 76, "No client or server folders: where each declaration runs is inferred, and client calls compile to typed RPC stubs.", "s", 14)]
    # columns
    cols = [(34, "CLIENT APPS", 220), (300, "core/  ·  JAC SERVER", 560), (906, "OUTSIDE", 240)]
    for (x, lab, w) in cols:
        b.append(box(x, 100, w, 410, "none", LINE, 16, 1, 'stroke-dasharray="4 5"'))
        b.append(text(x + 16, 124, lab, "s", 11, 700, extra='letter-spacing="1.5"'))
    clients = [("web/", "React SPA (Jac JSX)", 150), ("mobile/", "mobUI → React Native", 270), ("cli/", "in-process or --live", 390)]
    for (t, s, y) in clients:
        b.append(box(52, y, 184, 74, BLUE_SOFT, BLUE, 12, 1.3))
        b.append(text(70, y + 30, t, "m", 15, 650, fill=INK))
        b.append(text(70, y + 52, s, "s", 12))
    mods = [
        ("api.jac", "authenticated endpoints + SSE", 320, 146, True),
        ("live.jac", "per-user event bus", 600, 146, False),
        ("agent/copilot.jac", "by llm(), 29 tools", 320, 236, True),
        ("review/engine.jac", "8-stage walker pipeline", 600, 236, True),
        ("actions.jac", "writes shared with buttons", 320, 326, False),
        ("graph.jac", "nodes · typed edges · walkers", 600, 326, False),
        ("analytics.jac", "history mining", 320, 416, False),
        ("git/", "git · gh · diff parser", 600, 416, False),
    ]
    for (t, s, x, y, hot) in mods:
        c, sf = (VIOLET, VIOLET_SOFT) if hot else (LINE, CARD)
        b.append(box(x, y, 244, 64, sf, c, 12, 1.3))
        b.append(text(x + 16, y + 27, t, "m", 13.5, 650, fill=INK))
        b.append(text(x + 16, y + 47, s, "s", 12))
    outs = [("LLM provider", "via byLLM → LiteLLM", 236, VIOLET, VIOLET_SOFT), ("Graph store", "per-request commit", 326, BLUE, BLUE_SOFT), ("Local repo + gh", "the code under review", 416, GREEN, GREEN_SOFT)]
    for (t, s, y, c, sf) in outs:
        b.append(box(924, y, 204, 64, sf, c, 12, 1.3))
        b.append(text(940, y + 27, t, "t", 14, 650))
        b.append(text(940, y + 47, s, "s", 12))
    # edges
    b.append(line("M236,182 L318,178", VIOLET, "av", 1.9, "flow"))
    b.append(text(277, 168, "typed RPC", "m", 10.5, anchor="middle", fill=VIOLET, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M236,300 C276,300 280,196 318,192", BLUE, "a", 1.4, dash="5 4"))
    b.append(text(250, 262, "same stubs", "m", 10.5, anchor="middle", fill=INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M236,420 C284,420 284,206 318,202", MUTED, "a", 1.3, dash="5 4"))
    b.append(text(250, 372, "--live", "m", 10.5, anchor="middle", fill=INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M236,444 L318,444", MUTED, "a", 1.3))
    b.append(text(277, 436, "import", "m", 10.5, anchor="middle", fill=INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M564,178 L598,178", MUTED, "a"))
    b.append(line("M442,210 L442,234", MUTED, "a"))
    b.append(line("M564,268 L598,268", MUTED, "a"))
    b.append(line("M720,234 L720,212", MUTED, "a"))
    b.append(text(728, 227, "events", "m", 10, fill=MUTED))
    b.append(line("M564,358 L598,358", MUTED, "a"))
    b.append(line("M442,300 L442,324", MUTED, "a"))
    b.append(line("M844,268 L922,268", VIOLET, "av", 1.9, "flow"))
    b.append(text(883, 260, "by llm()", "m", 10.5, anchor="middle", fill=VIOLET, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M844,358 L922,358", BLUE, "a", 1.5))
    b.append(text(883, 350, "commit", "m", 10.5, anchor="middle", fill=INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M844,448 L922,448", GREEN, "ag", 1.5))
    b.append(text(883, 440, "git", "m", 10.5, anchor="middle", fill=INK2, extra=f'stroke="{BG}" stroke-width="6" paint-order="stroke"'))
    b.append(line("M564,448 L598,448", MUTED, "a"))
    b.append(line("M720,300 L720,324", MUTED, "a"))
    b.append(text(34, H - 22, "Imports between modules are declared once in archwire.jac; every endpoint is def:protect, so each account works in its own graph.", "s", 12))
    return svg(W, H, "".join(b), "Architecture: web, mobile and CLI clients call core/api.jac through typed RPC; the server's copilot and review engine call the LLM provider, commit to the graph store, and read the local repo via git and gh.")


if __name__ == "__main__":
    for name, fn in [("pipeline", pipeline), ("graph", graph), ("copilot", copilot), ("architecture", arch)]:
        path = os.path.join(OUT, f"diagram-{name}.svg")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(fn())
        print("wrote", os.path.relpath(path))
