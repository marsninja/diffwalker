impl Board -> JsxElement {
    has cards: list[Insight] = [],
        loaded: bool = False;
    async def load {
        cards = await board();
        loaded = True;
    }
    async can with entry {
        await load();
    }
    useLiveReload(["data"], load);
    async def unpin(card: Insight) {
        await unpin_card(card.id);
        toast("Removed from the board", "info");
        await load();
    }
    return <div className="mx-auto max-w-7xl space-y-5 p-4 sm:p-6">
        <PageHeader
            eyebrow="Copilot output"
            title="Insight board"
            subtitle="Charts, tables, and diagrams Copilot rendered from real repository data and pinned here. They persist in the graph next to the repository node."
        >
            <button
                type="button"
                onClick={lambda { ask_copilot(PROMPTS[len(cards) % len(PROMPTS)]) }}
                className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground"
            ><Sparkles className="size-4" />
                Ask for an insight
            </button>
        </PageHeader>
        {
            if not loaded {
                <div className="grid gap-4 md:grid-cols-2">
                    <Skeleton className="h-64" />
                    <Skeleton className="h-64" />
                </div>
            } elif len(cards) == 0 {
                <Empty
                    title="The board is empty"
                    hint="Ask Copilot for a chart and tell it to pin the result."
                >
                    <div className="flex max-w-xl flex-col gap-1.5">
                        {
                            for p in PROMPTS {
                                <button
                                    key={p}
                                    type="button"
                                    onClick={lambda { ask_copilot(p) }}
                                    className="rounded-lg border border-border px-3 py-1.5 text-left text-xs text-muted-foreground hover:border-primary/40 hover:text-foreground"
                                >{p}</button>
                            }
                        }
                    </div>
                </Empty>
            } else {
                <div className="columns-[380px] gap-4 [&>*]:mb-4 [&>*]:break-inside-avoid">
                    {
                        for c in cards {
                            <ChartCard
                                key={c.id}
                                title={c.title}
                                kind={c.kind}
                                spec={c.spec}
                                caption={c.caption}
                                pinned={c.pinned}
                                created={c.created}
                                onUnpin={lambda { unpin(c) }}
                            />
                        }
                    }
                </div>
            }
        }
    </div>;
}
