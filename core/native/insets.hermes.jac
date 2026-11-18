"""How far the phone's own bars reach into the screen. Android draws an app edge to edge, under
its status bar and its navigation bar, so the app keeps its header and its tabs clear of them."""
import from "react-native-safe-area-context" { initialWindowMetrics }

def top_inset -> float {
    at = initialWindowMetrics;
    return float(at.insets.top) if at is not None else 0.0;
}

def bottom_inset -> float {
    at = initialWindowMetrics;
    return float(at.insets.bottom) if at is not None else 0.0;
}
