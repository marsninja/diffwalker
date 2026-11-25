impl Icon(name: str, size: int, color: str) -> JsxElement {
    Glyph = LUCIDE.get(name, LUCIDE["pending"]);
    return <Glyph size={size} color={color} strokeWidth={2} />;
}
