import from "mermaid" { default as mermaid }
import type from "mermaid" { Mermaid }

glob _mm: Mermaid = mermaid as Mermaid,
     _mm_ready: list[bool] = [False],
     _mm_seq: list[int] = [0];

def:pub MermaidDiagram(code: str) -> JsxElement {
    has svg_html: str = "",
        failed: bool = False;

    async can with [code] entry {
        if not _mm_ready[0] {
            dark = document.documentElement.classList.contains("dark");
            _mm.initialize(
                {
                    "startOnLoad": False,
                    "securityLevel": "strict",
                    "theme": "base",
                    "themeVariables": {
                        "darkMode": dark,
                        "background": "transparent",
                        "primaryColor": "#2a2540" if dark else "#efeafe",
                        "primaryTextColor": "#ece9f7" if dark else "#1d1830",
                        "primaryBorderColor": "#7c5cff",
                        "secondaryColor": "#1d2433" if dark else "#e8f1fd",
                        "tertiaryColor": "#1c1c21" if dark else "#f6f5f2",
                        "lineColor": "#9a96ad",
                        "textColor": "#ece9f7" if dark else "#1d1830",
                        "fontFamily": "Geist Variable, ui-sans-serif, system-ui",
                        "fontSize": "13px"
                    }
                }
            );
            _mm_ready[0] = True;
        }
        _mm_seq[0] = _mm_seq[0] + 1;
        try {
            r = await _mm.render("mmd" + str(_mm_seq[0]), code);
            svg_html = r.svg;
            failed = False;
        } except Exception {
            failed = True;
        }
    }

    if failed {
        return
            <pre
                className="overflow-x-auto rounded-lg border border-border bg-muted/40 p-3 font-mono text-[11px]"
            >
                {code}
            </pre>;
    }
    if not svg_html {
        return <div className="shimmer h-40 rounded-lg"></div>;
    }
    <div
        className="flex justify-center overflow-x-auto [&_svg]:h-auto [&_svg]:max-w-full"
    >
        {unsafe_html(svg_html)}
    </div>
}
