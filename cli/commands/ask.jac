import sys;
import json;
import random;
import from jaclang.byllm.lib { StreamEvent }

def short_args(args: any) -> str {
    try {
        text = json.dumps(
            args,
            `default=lambda (o: object) -> object { return o?.__dict__ or str(o); }
        );
    } except Exception {
        text = str(args);
    }
    return text[:110];
}

def run_ask_offline(repo: str, question: str) -> int {
    if not llm_ready() {
        warn(
            red(
                "diffwalker: Copilot needs ANTHROPIC_API_KEY (environment or the project's .env)"
            )
        );
        return EXIT_USAGE;
    }
    cards: list[dict[str, any]] = [];
    set_agent(AgentCtx(repo=repo, session="cli-offline", thread="cli-offline", user=current_user()), cards);
    tap(
        lambda (evt: dict[str, any]) { if evt.get("kind") == "ui" {
            d = evt.get("data") or {};
            if d.get("action") != "card" {
                print(
                    dim(
                        "    ui ← "
                            + str(d.get("action"))
                            + " "
                            + short_args(d.get("args"))
                    )
                );
            }
        }}
    );
    history: list[dict[str, any]] = [];
    stream: any = copilot(question, "terminal (diffwalker cli), no screen", history);
    answering = False;
    for ev in stream {
        if not isinstance(ev, StreamEvent) {
            continue;
        }
        k = ev.event_type;
        d = ev.data;
        if k == "tool_call" {
            print(
                violet("  → " + str(d.get("tool")))
                    + dim("(" + short_args(d.get("args")) + ")")
            );
        } elif k == "chunk" {
            if not answering {
                print("");
                answering = True;
            }
            sys.stdout.write(str(d.get("content", "")));
            sys.stdout.flush();
        } elif k == "usage" {
            total = d.get("total", {}) or {};
            print(
                "\n"
                    + dim(
                        f"\n{d.get('requests', 0)} model calls · {total.get(
                            'total_tokens', 0
                        )} tokens · ${round(total.get('cost', 0.0), 4)}"
                    )
            );
        }
    }
    for card in cards {
        print(
            dim("  card: ")
                + bold(card.get("title", ""))
                + dim(
                    " ("
                        + card.get("kind", "")
                        + ") · open the web board to see it rendered"
                )
        );
    }
    return EXIT_OK;
}

def run_ask_live(server: str, question: str) -> int {
    session = "cli-" + str(random.randint(100000, 999999));
    answering: list[bool] = [False];
    def on_frame(f: dict[str, any]) -> bool {
        t = f.get("t");
        if t == "tool_call" {
            print(
                violet("  → " + str(f.get("tool")))
                    + dim("(" + short_args(f.get("args")) + ")")
            );
        } elif t == "card" {
            print(dim("  card: ") + bold(str((f.get("card") or {}).get("title", ""))));
        } elif t == "chunk" {
            if not answering[0] {
                print("");
                answering[0] = True;
            }
            sys.stdout.write(str(f.get("text", "")));
            sys.stdout.flush();
        } elif t == "usage" {
            print(
                "\n"
                    + dim(
                        f"\n{f.get('requests', 0)} model calls · {f.get(
                            'tokens', 0
                        )} tokens"
                    )
            );
        } elif t == "done" {
            return False;
        }
        return True;
    }
    print(
        dim(
            "asking Copilot on "
                + server
                + " · browsers with diffwalker open will follow its UI actions"
        )
    );
    try {
        post_sse(
            server,
            "copilot_stream",
            {
                "thread_id": "cli-" + str(random.randint(100000, 999999)),
                "message": question,
                "ui_state": "terminal; the user is watching the web app",
                "session": session
            },
            on_frame
        );
    } except Exception as e {
        return unreachable(server, e);
    }
    return EXIT_OK;
}
