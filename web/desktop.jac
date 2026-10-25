import "../core/site/styles/global.css";
import "../core/site/styles/site.css";

"""The desktop app: the web app's pages, behind a choice of where diffwalker runs."""
def:pub app(children: any) -> JsxElement {
    return <BackendGate>{children}</BackendGate>;
}
