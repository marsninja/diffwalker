impl top_inset -> float {
    at = initialWindowMetrics;
    return float(at.insets.top) if at is not None else 0.0;
}

impl bottom_inset -> float {
    at = initialWindowMetrics;
    return float(at.insets.bottom) if at is not None else 0.0;
}
