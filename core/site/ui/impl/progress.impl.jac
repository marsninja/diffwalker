impl Progress(**kwargs: any) -> JsxElement {
    value = kwargs.get("value") or 0;
    translateX = 100 - value;
    return <ProgressPrimitive.Root
        {...kwargs}
        data-slot="progress"
        className={cn("bg-muted h-1 rounded-full relative flex w-full items-center overflow-x-hidden", kwargs.get("className"))}
    >
        <ProgressPrimitive.Indicator
            data-slot="progress-indicator"
            className="bg-primary size-full flex-1 transition-all"
            style={{"transform": "translateX(-" + String(translateX) + "%)"}}
        />
    </ProgressPrimitive.Root>;
}
