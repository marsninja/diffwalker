import "./eco/web/global.css";
import "./core/site/styles/site.css";

"""Every page, behind the desktop app's choice of where diffwalker runs and whose profile
is open; a browser tab's app has neither, and shows the pages."""
def:pub app(children: any) -> JsxElement {
    return <BackendGate>{children}</BackendGate>;
}
