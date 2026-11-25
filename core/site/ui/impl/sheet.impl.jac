impl Sheet(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Root data-slot="sheet" {...kwargs} />;
}

impl SheetTrigger(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Trigger data-slot="sheet-trigger" {...kwargs} />;
}

impl SheetClose(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Close data-slot="sheet-close" {...kwargs} />;
}

impl SheetPortal(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Portal data-slot="sheet-portal" {...kwargs} />;
}

impl SheetOverlay(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Overlay
        {...kwargs}
        data-slot="sheet-overlay"
        className={cn("bg-black/10 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 z-50 duration-100 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0", kwargs.get("className"))}
    />;
}

impl SheetContent(**kwargs: any) -> JsxElement {
    side = kwargs.get("side") or "right";
    showCloseButton = kwargs.get("showCloseButton");
    if showCloseButton is None {
        showCloseButton = True;
    }
    return <SheetPortal>
        <SheetOverlay />
        <SheetPrimitive.Content
            {...kwargs}
            data-slot="sheet-content"
            data-side={side}
            className={cn("bg-popover text-popover-foreground fixed z-50 flex flex-col gap-4 bg-clip-padding text-sm shadow-lg transition duration-200 ease-in-out data-[side=bottom]:inset-x-0 data-[side=bottom]:bottom-0 data-[side=bottom]:h-auto data-[side=bottom]:border-t data-[side=left]:inset-y-0 data-[side=left]:left-0 data-[side=left]:h-full data-[side=left]:w-3/4 data-[side=left]:border-r data-[side=right]:inset-y-0 data-[side=right]:right-0 data-[side=right]:h-full data-[side=right]:w-3/4 data-[side=right]:border-l data-[side=top]:inset-x-0 data-[side=top]:top-0 data-[side=top]:h-auto data-[side=top]:border-b data-[side=left]:sm:max-w-sm data-[side=right]:sm:max-w-sm data-open:animate-in data-open:fade-in-0 data-[side=bottom]:data-open:slide-in-from-bottom-10 data-[side=left]:data-open:slide-in-from-left-10 data-[side=right]:data-open:slide-in-from-right-10 data-[side=top]:data-open:slide-in-from-top-10 data-closed:animate-out data-closed:fade-out-0 data-[side=bottom]:data-closed:slide-out-to-bottom-10 data-[side=left]:data-closed:slide-out-to-left-10 data-[side=right]:data-closed:slide-out-to-right-10 data-[side=top]:data-closed:slide-out-to-top-10", kwargs.get("className"))}
        >
            {kwargs.get("children")}
            {showCloseButton
                and <SheetPrimitive.Close data-slot="sheet-close" asChild={True}>
                    <Button variant="ghost" className="absolute top-3 right-3" size="icon-sm">
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
                        <span className="sr-only">Close</span>
                    </Button>
                </SheetPrimitive.Close>}
        </SheetPrimitive.Content>
    </SheetPortal>;
}

impl SheetHeader(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="sheet-header"
        className={cn("gap-0.5 p-4 flex flex-col", kwargs.get("className"))}
    />;
}

impl SheetFooter(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="sheet-footer"
        className={cn("gap-2 p-4 mt-auto flex flex-col", kwargs.get("className"))}
    />;
}

impl SheetTitle(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Title
        {...kwargs}
        data-slot="sheet-title"
        className={cn("text-foreground text-base font-medium", kwargs.get("className"))}
    />;
}

impl SheetDescription(**kwargs: any) -> JsxElement {
    return <SheetPrimitive.Description
        {...kwargs}
        data-slot="sheet-description"
        className={cn("text-muted-foreground text-sm", kwargs.get("className"))}
    />;
}
