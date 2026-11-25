"""`ask`: a Copilot turn in this program, or one the server runs while this terminal and the
user's browsers follow it."""
import sys;
import json;
import random;
import from stdjac { ByEventKind, ByUsage, Message, RemoteError, encode }

"""What a UI command was given, as JSON of the arguments it sets."""
def short_args(args: UiArgs) -> str {
    given: dict[str, any] = encode(args);
    return json.dumps({k: v for (k, v) in given.items() if v})[:110];
}

def run_ask_offline(repo: str, question: str) -> int {
    if not llm_ready() {
        warn(
            red("diffwalker: Copilot needs ANTHROPIC_API_KEY (environment or the project's .env)")
        );
        return EXIT_USAGE;
    }
    cards: list[Card] = [];
    set_agent(
        AgentCtx(repo=repo, session="cli-offline", thread="cli-offline", user=current_user()), cards
    );
    tap(
        lambda (evt: LiveEvent) {
            if evt.kind == "ui" {
                print(dim("    ui ← " + evt.data.action + " " + short_args(evt.data.args)));
            }
        },
    );
    history: list[Message] = [];
    answering = False;
    usage = ByUsage();
    for ev in copilot(question, "terminal (diffwalker cli), no screen", history) {
        if ev.kind == ByEventKind.TOOL_CALL {
            print(violet("  → " + ev.tool) + dim("(" + json.dumps(ev.args)[:110] + ")"));
        } elif ev.kind == ByEventKind.TEXT {
            if not answering {
                print("");
                answering = True;
            }
            sys.stdout.write(ev.text);
            sys.stdout.flush();
        } elif ev.kind == ByEventKind.USAGE {
            used = ev.usage;
            if used is not None {
                usage.add(used);
            }
        }
    }
    if usage.requests {
        print(
            "\n"
                + dim(
                    f"\n{usage.requests} model calls · {tokens_of(usage)} tokens · ${round(usage.cost or 0.0, 4)}",
                ),
        );
    }
    for card in cards {
        print(
            dim("  card: ")
                + bold(card.title)
                + dim(" (" + card.kind + ") · open the web board to see it rendered"),
        );
    }
    return EXIT_OK;
}

def run_ask_live(server: str, question: str) -> int {
    use_server(server);
    session = "cli-" + str(random.randint(100000, 999999));
    thread = "cli-" + str(random.randint(100000, 999999));
    answering = False;
    usage: CopilotFrame | None = None;
    print(
        dim(
            "asking Copilot on "
                + server
                + " · browsers with diffwalker open will follow its UI actions",
        ),
    );
    try {
        for f in copilot_stream(
            thread, question, "terminal; the user is watching the web app", session
        ) {
            card = f.card;
            if f.t == "tool_call" {
                print(violet("  → " + f.tool) + dim("(" + f.args[:110] + ")"));
            } elif f.t == "card" and card is not None {
                print(dim("  card: ") + bold(card.title));
            } elif f.t == "chunk" {
                if not answering {
                    print("");
                    answering = True;
                }
                sys.stdout.write(f.text);
                sys.stdout.flush();
            } elif f.t == "usage" {
                usage = f;
            } elif f.t == "done" {
                break;
            }
        }
    } except RemoteError as e {
        return unreachable(server, e);
    }
    if usage is not None {
        print("\n" + dim(f"\n{usage.requests} model calls · {usage.tokens} tokens"));
    }
    return EXIT_OK;
}
