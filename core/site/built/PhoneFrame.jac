def:pub PhoneFrame(children: any = None) -> JsxElement {
    <div className="mx-auto w-[360px] max-w-full">
        <div
            className="relative rounded-[3rem] border-[10px] border-neutral-950 bg-neutral-950 shadow-[0_30px_80px_-20px_rgba(76,52,200,0.55)] ring-1 ring-white/10"
        >
            <div
                className="pointer-events-none absolute left-1/2 top-2.5 z-20 h-6 w-24 -translate-x-1/2 rounded-full bg-black"
            ></div>
            <div
                className="pointer-events-none absolute -left-[13px] top-24 h-8 w-[3px] rounded-l bg-neutral-800"
            ></div>
            <div
                className="pointer-events-none absolute -left-[13px] top-36 h-14 w-[3px] rounded-l bg-neutral-800"
            ></div>
            <div
                className="pointer-events-none absolute -right-[13px] top-32 h-20 w-[3px] rounded-r bg-neutral-800"
            ></div>
            <div
                className="relative h-[720px] overflow-hidden rounded-[2.4rem] bg-[#0d0c12]"
            >
                {children}
            </div>
        </div>
    </div>
}
