def:pub BrandMark(size: int = 28) -> JsxElement {
    <svg width={size} height={size} viewBox="0 0 32 32" fill="none" aria-hidden="true">
        <rect x="1" y="1" width="30" height="30" rx="9" fill="url(#dwg)"/>
        <path
            d="M10 8v16"
            stroke="white"
            strokeOpacity="0.9"
            strokeWidth="2.2"
            strokeLinecap="round"
        />
        <path
            d="M10 13c0 4 12 2 12 7v4"
            stroke="white"
            strokeOpacity="0.9"
            strokeWidth="2.2"
            strokeLinecap="round"
            fill="none"
        />
        <circle cx="22" cy="10" r="3.2" fill="white"/>
        <circle cx="22" cy="10" r="1.3" fill="#7c5cff"/>
        <defs>
            <linearGradient id="dwg" x1="0" y1="0" x2="32" y2="32">
                <stop offset="0" stopColor="#8b6cff"/>
                <stop offset="1" stopColor="#4f3bd6"/>
            </linearGradient>
        </defs>
    </svg>
}

def:pub Wordmark -> JsxElement {
    <span className="flex items-center gap-2">
        <BrandMark size={26}/>
        <span className="text-[15px] font-semibold tracking-tight">diffwalker</span>
    </span>
}
