import from "lucide-react" { Sparkles, LayoutGrid }

glob PROMPTS: list[str] = [
    "Chart commit types over the last six months and pin it",
    "Render a table of the ten largest files that changed this quarter and pin it",
    "Draw a Mermaid diagram of how the review pipeline's stages hand data to each other and pin it",
    "Compare the open branches by lines changed in a bar chart and pin it",
];

def:pub Board -> JsxElement;
