import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    ScrollView,
    TextInput,
    ActivityIndicator,
    useWindowDimensions
}
import from "@jac/runtime" { jacLogin, jacSignup, jacIsLoggedIn, jacLogout, SignupResult }

glob TABS: list[any] = [
         {"key": "inbox", "label": "Inbox", "icon": "inbox"},
         {"key": "review", "label": "Review", "icon": "review"},
         {"key": "insights", "label": "Insights", "icon": "insights"},
         {"key": "copilot", "label": "Copilot", "icon": "copilot"}
     ],
     VERDICT_TEXT: dict[str, str] = {
         "approve": "Approve",
         "comment": "Comment",
         "request_changes": "Changes requested"
     },
     STAGE_ORDER: list[str] = [
         "ingest",
         "triage",
         "plan",
         "review",
         "cross",
         "investigate",
         "verify",
         "synthesize"
     ],
     QUICK: list[str] = [
         "Which pull request is riskiest right now?",
         "Summarize the open findings for me",
         "What are this repo's hotspots?"
     ];

def short(n: int) -> str {
    if n >= 10000 {
        return str(round(n / 1000)) + "k";
    }
    if n >= 1000 {
        return str(round(n / 100) / 10) + "k";
    }
    return str(n);
}

def mobile_session -> str {
    return "m-" + str(int(Math.random() * 1000000000));
}

def plain(md: str) -> str {
    out = md.replace("**", "").replace("`", "").replace("### ", "").replace(
        "## ", ""
    ).replace(
        "# ", ""
    );
    return out;
}

def Pill(label: str, tone: str, icon: str = "") -> JsxElement {
    <View style={[styles.pill, {"backgroundColor": tone + "26"}]}>
        {if icon {
            <Icon name={icon} size={11} color={tone}/>
        }}
        <Text style={[styles.pillText, {"color": tone}]}>{label}</Text>
    </View>
}

def RiskBar(score: int) -> JsxElement {
    if score < 0 {
        return <Text style={styles.small}>not reviewed</Text>;
    }
    <View style={[styles.row, {"width": 92}]}>
        <View style={styles.track}>
            <View
                style={{
                    "height": 6,
                    "width": str(max(4, score)) + "%",
                    "backgroundColor": risk_tone(score),
                    "borderRadius": 3
                }}
            ></View>
        </View>
        <Text style={[styles.small, {"color": C.text, "fontWeight": "700"}]}>
            {str(score)}
        </Text>
    </View>
}

def KindIcon(kind: str) -> JsxElement {
    if kind == "github" {
        return <Icon name="github" size={14} color={C.muted}/>;
    }
    if kind == "worktree" {
        return <Icon name="worktree" size={14} color={C.warning}/>;
    }
    return <Icon name="branch" size={14} color={C.muted}/>;
}

def PRCard(row: any, onOpen: any) -> JsxElement {
    p = row.pr;
    <Pressable
        onPress={lambda { onOpen(p.id); }}
        style={styles.card}
        accessibilityRole="button"
    >
        <View style={styles.row}>
            <KindIcon kind={p.kind}/>
            <Text style={[styles.h2, {"flex": 1}]} numberOfLines={2}>{p.title}</Text>
        </View>
        <Text style={styles.mono} numberOfLines={1}>{p.head + " · " + p.author}</Text>
        <View style={styles.between}>
            <Text style={styles.small}>
                <Text style={{"color": C.add}}>{"+" + short(p.additions)}</Text>{" "}
                <Text style={{"color": C.rem}}>{"−" + short(p.deletions)}</Text>
                {"  ·  " + str(p.files_changed) + " files"}
            </Text>
            {if row.reviewing {
                <Pill label="Reviewing" tone={C.accent} icon="running"/>
            } elif row.verdict {
                <Pill
                    label={VERDICT_TEXT[row.verdict] or row.verdict}
                    tone={verdict_tone(row.verdict)}
                    icon={row.verdict}
                />
            } else {
                <Pill label="New" tone={C.muted}/>
            }  }
        </View>
        <RiskBar score={row.risk}/>
    </Pressable>
}

def InboxScreen(
    rows: list[any], loading: bool, onOpen: any, onRefresh: any
) -> JsxElement {
    reviewed = [
        r
        for r in rows
        if r.verdict
    ];
    open_findings = sum([r.open_findings for r in reviewed]);
    <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.statRow}>
            <View style={styles.stat}>
                <Text style={styles.tiny}>QUEUE</Text>
                <Text style={styles.statValue}>{str(len(rows))}</Text>
            </View>
            <View style={styles.stat}>
                <Text style={styles.tiny}>REVIEWED</Text>
                <Text style={styles.statValue}>{str(len(reviewed))}</Text>
            </View>
            <View style={styles.stat}>
                <Text style={styles.tiny}>OPEN ISSUES</Text>
                <Text
                    style={[
                        styles.statValue,
                        {"color": C.serious if open_findings else C.text}
                    ]}
                >
                    {str(open_findings)}
                </Text>
            </View>
        </View>
        <View style={styles.between}>
            <Text style={styles.h2}>Pull requests</Text>
            <Pressable onPress={onRefresh} style={styles.ghostBtn}>
                <Icon name="reopen" size={12} color={C.text}/>
                <Text style={styles.ghostLabel}>Refresh</Text>
            </Pressable>
        </View>
        {if loading and len(rows) == 0 {
            <ActivityIndicator color={C.accent}/>
        }}
        {for row in rows {
            <PRCard key={row.pr.id} row={row} onOpen={onOpen}/>
        }}
    </ScrollView>
}

def StageRow(stage: any) -> JsxElement {
    st = stage.status;
    tone = C.good
        if st == "done"
        else (
            C.accent if st == "running" else (C.critical if st == "failed" else C.muted)
        );
    <View style={[styles.row, {"alignItems": "flex-start"}]}>
        <View
            style={{
                "width": 22,
                "height": 22,
                "borderRadius": 11,
                "backgroundColor": tone + "22",
                "alignItems": "center",
                "justifyContent": "center"
            }}
        >
            {if st == "running" {
                <ActivityIndicator size="small" color={C.accent}/>
            } else {
                <Icon
                    name={st if st in ("done", "failed", "skipped") else "pending"}
                    size={12}
                    color={tone}
                />
            } }
        </View>
        <View style={{"flex": 1}}>
            <Text style={[styles.text, {"fontWeight": "600"}]}>{stage.label}</Text>
            {if stage.detail {
                <Text style={styles.small} numberOfLines={2}>{stage.detail}</Text>
            }}
        </View>
    </View>
}

def FindingRow(f: any, onStatus: any) -> JsxElement {
    has open: bool = False;
    tone = sev_tone(f.severity);
    <Pressable
        onPress={lambda { open = not open; }}
        style={[
            styles.card,
            {"borderColor": tone + "55", "opacity": 1 if f.status == "open" else 0.55}
        ]}
    >
        <View style={styles.row}>
            <Pill label={f.severity.upper()} tone={tone}/>
            <Text style={styles.small}>{f.category}</Text>
            <Text style={[styles.mono, {"marginLeft": "auto"}]}>{f.id}</Text>
        </View>
        <Text style={[styles.text, {"fontWeight": "600"}]}>{f.title}</Text>
        <Text style={styles.mono} numberOfLines={1}>{f.path + ":" + str(f.line)}</Text>
        {if open {
            <View style={{"gap": 8}}>
                <Text style={styles.small}>{plain(f.body)}</Text>
                {if f.suggestion {
                    <View
                        style={{
                            "backgroundColor": C.raised,
                            "borderRadius": R.sm,
                            "padding": S.sm
                        }}
                    >
                        <Text style={styles.mono}>{f.suggestion}</Text>
                    </View>
                }}
                <View style={styles.row}>
                    {if f.status == "open" {
                        <Pressable
                            onPress={lambda { onStatus(f.id, "resolved"); }}
                            style={styles.ghostBtn}
                        >
                            <Icon name="check" size={12} color={C.good}/>
                            <Text style={styles.ghostLabel}>Resolve</Text>
                        </Pressable>
                    }}
                    {if f.status == "open" {
                        <Pressable
                            onPress={lambda { onStatus(f.id, "dismissed"); }}
                            style={styles.ghostBtn}
                        >
                            <Icon name="close" size={12} color={C.muted}/>
                            <Text style={styles.ghostLabel}>Dismiss</Text>
                        </Pressable>
                    } else {
                        <Pressable
                            onPress={lambda { onStatus(f.id, "open"); }}
                            style={styles.ghostBtn}
                        >
                            <Icon name="reopen" size={12} color={C.text}/>
                            <Text style={styles.ghostLabel}>Reopen</Text>
                        </Pressable>
                    } }
                </View>
            </View>
        }}
    </Pressable>
}

def ReviewScreen(
    detail: any, loading: bool, busy: bool, onRun: any, onStatus: any, onBack: any
) -> JsxElement {
    if loading and not detail {
        return
            <View
                style={{"flex": 1, "alignItems": "center", "justifyContent": "center"}}
            >
                <ActivityIndicator color={C.accent}/>
            </View>;
    }
    if not detail {
        return
            <View
                style={{
                    "flex": 1,
                    "alignItems": "center",
                    "justifyContent": "center",
                    "padding": 32,
                    "gap": 8
                }}
            >
                <Icon name="review" size={30} color={C.muted}/>
                <Text style={[styles.h2, {"textAlign": "center"}]}>
                    Pick a pull request
                </Text>
                <Text style={[styles.small, {"textAlign": "center"}]}>
                    Open one from the inbox, or ask Copilot which one is riskiest.
                </Text>
            </View>;
    }
    p = detail.pr;
    rv = detail.review;
    running = busy or (rv and rv.status == "running");
    findings = sorted(
        detail.findings,
        key=lambda (f: any) -> int { return (0 if f.status == "open" else 10)
            + ["critical", "high", "medium", "low", "info"].index(f.severity)
            if f.severity in ["critical", "high", "medium", "low", "info"]
            else 99; }
    );
    <ScrollView contentContainerStyle={styles.scroll}>
        <Pressable onPress={onBack} style={styles.row}>
            <Icon name="back" size={14} color={C.muted}/>
            <Text style={styles.small}>Inbox</Text>
        </Pressable>
        <Text style={styles.h1}>{p.title}</Text>
        <Text style={styles.mono}>{p.head + " → " + p.base}</Text>
        <View style={styles.card}>
            <View style={styles.between}>
                <View style={{"gap": 4}}>
                    <Text style={styles.tiny}>VERDICT</Text>
                    {if rv and rv.status == "done" {
                        <Pill
                            label={VERDICT_TEXT[rv.verdict] or rv.verdict}
                            tone={verdict_tone(rv.verdict)}
                            icon={rv.verdict}
                        />
                    } else {
                        <Text style={styles.small}>
                            {"Reviewing…" if running else "Not reviewed"}
                        </Text>
                    } }
                </View>
                <View style={{"alignItems": "flex-end"}}>
                    <Text style={styles.tiny}>RISK</Text>
                    <Text
                        style={[
                            styles.statValue,
                            {
                                "color": risk_tone(rv.risk)
                                    if rv and rv.status == "done"
                                    else C.muted
                            }
                        ]}
                    >
                        {str(rv.risk) if rv and rv.status == "done" else "–"}
                    </Text>
                </View>
            </View>
            {if rv and rv.status == "done" and rv.summary {
                <Text style={styles.small}>{plain(rv.summary)}</Text>
            }}
            {if rv and rv.cost {
                <Text style={styles.tiny}>
                    {str(rv.llm_calls) + " MODEL CALLS · $" + str(round(rv.cost * 1000) / 1000)}
                </Text>
            }}
            <Pressable
                onPress={onRun}
                disabled={running}
                accessibilityRole="button"
                style={[styles.primaryBtn, {"opacity": 0.6 if running else 1}]}
            >
                {if running {
                    <ActivityIndicator size="small" color={C.accentText}/>
                } else {
                    <Icon name="play" size={14} color={C.accentText}/>
                } }
                <Text style={styles.primaryLabel}>
                    {"Reviewing…"
                        if running
                        else ("Re-run review" if rv else "Run agentic review")}
                </Text>
            </Pressable>
        </View>
        {if rv {
            <View style={styles.card}>
                <Text style={styles.h2}>Pipeline</Text>
                {for s in rv.stages {
                    <StageRow key={s.key} stage={s}/>
                }}
            </View>
        }}
        {if len(findings) > 0 {
            <Text style={styles.h2}>
                {"Findings · "
                    + str(
                        len(
                            [
                                f
                                for f in findings
                                if f.status == "open"
                            ]
                        )
                    )
                    + " open"}
            </Text>
        }}
        {for f in findings {
            <FindingRow key={f.id} f={f} onStatus={onStatus}/>
        }}
    </ScrollView>
}

def MiniBars(values: list[float], tone: str) -> JsxElement {
    peak = 1.0;
    for v in values {
        peak = max(peak, v);
    }
    <View
        style={{
            "flexDirection": "row",
            "alignItems": "flex-end",
            "height": 70,
            "gap": 3
        }}
    >
        {for (i, v) in enumerate(values) {
            <View
                key={str(i)}
                style={{
                    "flex": 1,
                    "height": str(max(3.0, 100 * v / peak)) + "%",
                    "backgroundColor": tone,
                    "borderTopLeftRadius": 3,
                    "borderTopRightRadius": 3,
                    "opacity": 0.55 + 0.45 * (i / max(1, len(values)))
                }}
            ></View>
        }}
    </View>
}

def InsightsScreen(data: any) -> JsxElement {
    if not data {
        return
            <View
                style={{"flex": 1, "alignItems": "center", "justifyContent": "center"}}
            >
                <ActivityIndicator color={C.accent}/>
            </View>;
    }
    weekly: list[float] = [];
    acc = 0;
    for (i, d) in enumerate(data.activity) {
        acc += d.count;
        if (i + 1) % 7 == 0 {
            weekly.append(float(acc));
            acc = 0;
        }
    }
    total = sum([l.bytes for l in data.languages]) or 1;
    top = data.hotspots[0].score if len(data.hotspots) > 0 else 1;
    <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.h1}>{data.repo.name}</Text>
        <Text style={styles.mono}>{data.repo.branch + " @ " + data.repo.head}</Text>
        <View style={styles.statRow}>
            <View style={styles.stat}>
                <Text style={styles.tiny}>COMMITS</Text>
                <Text style={styles.statValue}>{short(data.repo.commits)}</Text>
            </View>
            <View style={styles.stat}>
                <Text style={styles.tiny}>90 DAYS</Text>
                <Text style={styles.statValue}>{short(data.stats.commits_90d)}</Text>
            </View>
            <View style={styles.stat}>
                <Text style={styles.tiny}>AUTHORS</Text>
                <Text style={styles.statValue}>{str(data.repo.contributors)}</Text>
            </View>
        </View>
        <View style={styles.card}>
            <Text style={styles.h2}>Commits per week</Text>
            <MiniBars values={weekly} tone={C.low}/>
        </View>
        <View style={styles.card}>
            <View style={styles.row}>
                <Icon name="flame" size={14} color={C.serious}/>
                <Text style={styles.h2}>Hotspots</Text>
            </View>
            {for h in data.hotspots[:6] {
                <View key={h.path} style={{"gap": 4}}>
                    <View style={styles.between}>
                        <Text
                            style={[styles.mono, {"color": C.text, "flex": 1}]}
                            numberOfLines={1}
                        >
                            {h.path.split("/")[len(h.path.split("/")) - 1]}
                        </Text>
                        <Text style={styles.small}>{str(h.changes) + " changes"}</Text>
                    </View>
                    <View style={styles.track}>
                        <View
                            style={{
                                "height": 6,
                                "width": str(100 * h.score / top) + "%",
                                "backgroundColor": C.serious,
                                "borderRadius": 3
                            }}
                        ></View>
                    </View>
                </View>
            }}
        </View>
        <View style={styles.card}>
            <Text style={styles.h2}>Languages</Text>
            {for l in data.languages[:6] {
                <View key={l.language} style={styles.between}>
                    <Text style={styles.text}>{l.language}</Text>
                    <Text style={styles.small}>
                        {str(round(100 * l.bytes / total)) + "%"}
                    </Text>
                </View>
            }}
        </View>
    </ScrollView>
}

def CopilotScreen(
    msgs: list[any], draft: str, busy: bool, onDraft: any, onSend: any
) -> JsxElement {
    <View style={{"flex": 1}}>
        <ScrollView contentContainerStyle={[styles.scroll, {"gap": 10}]}>
            {if len(msgs) == 0 {
                <View style={[styles.card, {"gap": 10}]}>
                    <View style={styles.row}>
                        <Icon name="copilot" size={16} color={C.accent}/>
                        <Text style={styles.h2}>Copilot in your pocket</Text>
                    </View>
                    <Text style={styles.small}>
                        The same agent as the web app, with the same tools. It can open pull requests here, run reviews, and resolve findings.
                    </Text>
                    {for q in QUICK {
                        <Pressable
                            key={q}
                            onPress={lambda { onSend(q); }}
                            style={styles.chip}
                        >
                            <Text style={styles.small}>{q}</Text>
                        </Pressable>
                    }}
                </View>
            }}
            {for (i, m) in enumerate(msgs) {
                if m["role"] == "user" {
                    <View key={str(i)} style={styles.bubbleMe}>
                        <Text style={{"color": C.accentText, "fontSize": 14}}>
                            {m["text"]}
                        </Text>
                    </View>
                } else {
                    <View key={str(i)} style={styles.bubbleBot}>
                        {for (ti, t) in enumerate(m["tools"]) {
                            <View key={str(ti)} style={styles.row}>
                                <Icon name="tool" size={11} color={C.accent}/>
                                <Text style={styles.mono} numberOfLines={1}>{t}</Text>
                            </View>
                        }}
                        <Text style={styles.text}>{plain(m["text"])}</Text>
                    </View>
                }
            }}
            {if busy {
                <View style={[styles.bubbleBot, styles.row]}>
                    <ActivityIndicator size="small" color={C.accent}/>
                    <Text style={styles.small}>Copilot is working…</Text>
                </View>
            }}
        </ScrollView>
        <View
            style={[
                styles.row,
                {"padding": S.md, "borderTopWidth": 1, "borderTopColor": C.border}
            ]}
        >
            <TextInput
                value={draft}
                onChangeText={onDraft}
                placeholder="Ask Copilot…"
                placeholderTextColor={C.muted}
                style={styles.input}
                onSubmitEditing={lambda { onSend(draft); }}
            />
            <Pressable
                onPress={lambda { onSend(draft); }}
                style={[styles.sendBtn, {"opacity": 0.5 if busy else 1}]}
                accessibilityLabel="Send"
            >
                <Icon name="send" size={16} color={C.accentText}/>
            </Pressable>
        </View>
    </View>
}

def TabBar(active: str, onPick: any) -> JsxElement {
    <View style={styles.tabBar}>
        {for t in TABS {
            <Pressable
                key={t["key"]}
                onPress={lambda { onPick(t["key"]); }}
                style={styles.tab}
                accessibilityRole="tab"
            >
                <Icon
                    name={t["icon"]}
                    size={20}
                    color={C.accent if active == t["key"] else C.muted}
                />
                <Text
                    style={[
                        styles.tabLabel,
                        {"color": C.accent if active == t["key"] else C.muted}
                    ]}
                >
                    {t["label"]}
                </Text>
            </Pressable>
        }}
    </View>
}

"""Sign in on the phone; the session is stored by the runtime (secure storage on device)."""
def SignInScreen(onDone: any) -> JsxElement {
    has name: str = "",
        password: str = "",
        busy: bool = False,
        mode: str = "signin",
        error: str = "";
    async def go {
        ok: bool = False;
        made: SignupResult | None = None;
        busy = True;
        error = "";
        try {
            if mode == "signup" {
                made = await jacSignup(name.strip(), password);
                if not made.success {
                    error = made.error or "Could not create the account";
                    busy = False;
                    return;
                }
            }
            ok = await jacLogin(name.strip(), password);
        } except Exception as e {
            error = "Server unreachable";
        }
        busy = False;
        if ok {
            onDone();
        } elif not error {
            error = "Wrong username or password";
        }
    }
    <View style={[styles.scroll, {"flex": 1, "justifyContent": "center"}]}>
        <View style={[styles.card, {"gap": 10}]}>
            <Text style={styles.h1}>{"Create account" if mode == "signup" else "Sign in"}</Text>
            <Text style={styles.small}>Your reviews and Copilot threads are private to your account.</Text>
            <TextInput
                value={name}
                onChangeText={lambda (t: str) { name = t; }}
                placeholder="Username"
                placeholderTextColor={C.muted}
                autoCapitalize="none"
                style={styles.input}
            />
            <TextInput
                value={password}
                onChangeText={lambda (t: str) { password = t; }}
                placeholder="Password"
                placeholderTextColor={C.muted}
                secureTextEntry={True}
                style={styles.input}
                onSubmitEditing={lambda { go(); }}
            />
            {if error {
                <Text style={[styles.small, {"color": C.critical}]}>{error}</Text>
            }}
            <Pressable onPress={lambda { go(); }} disabled={busy} accessibilityRole="button" style={[styles.primaryBtn, {"opacity": 0.6 if busy else 1}]}>
                {if busy {
                    <ActivityIndicator size="small" color={C.accentText}/>
                }}
                <Text style={styles.primaryLabel}>{"Create account" if mode == "signup" else "Sign in"}</Text>
            </Pressable>
            <Pressable onPress={lambda { mode = "signin" if mode == "signup" else "signup"; }} accessibilityRole="button">
                <Text style={[styles.small, {"textAlign": "center"}]}>
                    {"Have an account? Sign in" if mode == "signup" else "New here? Create an account"}
                </Text>
            </Pressable>
        </View>
    </View>
}

def:pub DiffwalkerMobile(embedded: bool = False) -> JsxElement {
    has tab: str = "inbox",
        rows: list[any] = [],
        loadingRows: bool = False,
        prId: str = "",
        detail: any = None,
        loadingDetail: bool = False,
        reviewing: bool = False,
        dash: any = None,
        msgs: list[any] = [],
        draft: str = "",
        asking: bool = False,
        session: str = "",
        signed: bool = jacIsLoggedIn(),
        error: str = "";
    viewport = useWindowDimensions();
    async def loadRows {
        loadingRows = True;
        try {
            rows = await list_reviews(False);
            error = "";
        } except Exception as e {
            error = "Cannot reach the diffwalker server";
        }
        loadingRows = False;
    }
    async def openPR(pr_id: str) {
        prId = pr_id;
        tab = "review";
        loadingDetail = True;
        detail = None;
        try {
            detail = await pr_detail(pr_id, "");
        } except Exception {
            error = "Could not load " + pr_id;
        }
        loadingDetail = False;
    }
    async def reloadDetail(pr_id: str) {
        try {
            detail = await pr_detail(pr_id, "");
        } except Exception {
            error = "Could not refresh";
        }
    }
    async def runReview {
        if not prId {
            return;
        }
        target = prId;
        reviewing = True;
        poll = setInterval(lambda { reloadDetail(target); }, 3000);
        try {
            await start_review(target, "", session);
        } except Exception {
            error = "Review failed";
        }
        clearInterval(poll);
        reviewing = False;
        await reloadDetail(target);
        await loadRows();
    }
    async def setStatus(fid: str, status: str) {
        await set_finding_status(fid, status, "");
        if prId {
            await reloadDetail(prId);
        }
    }
    async def pick(name: str) {
        tab = name;
        if name == "insights" and not dash {
            dash = await dashboard();
        }
    }
    async def ask(text: str) {
        body = text.strip();
        if not body or asking {
            return;
        }
        draft = "";
        base = msgs + [{"role": "user", "text": body}];
        msgs = base;
        asking = True;
        sid = session or mobile_session();
        session = sid;
        try {
            reply = await copilot_ask(
                "mobile-" + sid,
                body,
                "mobile app, tab=" + tab + (", pull request " + prId if prId else ""),
                sid
            );
            tools = [t.tool + "  " + t.args[:60] for t in reply.tools];
            if reply.cost {
                tools = tools + ["$" + str(round(reply.cost * 1000) / 1000) + " · " + str(reply.tokens) + " tokens"];
            }
            msgs = base + [{"role": "assistant", "text": reply.text, "tools": tools}];
            for a in reply.actions {
                if a["action"] == "navigate" {
                    to = a["args"]["to"] or "";
                    if to.startswith("/reviews/") {
                        await openPR(to[9:]);
                    } elif to.startswith("/insights") {
                        await pick("insights");
                    } elif to == "/reviews" or to == "/" {
                        tab = "inbox";
                    }
                }
            }
            if len(reply.tools) > 0 {
                await loadRows();
            }
        } except Exception as e {
            msgs = base
                + [
                    {
                        "role": "assistant",
                        "text": "Copilot is unreachable: " + str(e),
                        "tools": []
                    }
                ];
        }
        asking = False;
    }
    async can with [signed] entry {
        session = mobile_session();
        if signed {
            await loadRows();
        }
    }
    title = (TABS[[t["key"] for t in TABS].index(tab)]["label"])
        if tab in [t["key"] for t in TABS]
        else "";
    <View
        testID="diffwalker-mobile"
        style={[
            styles.root,
            {
                "height": "100%" if embedded else viewport.height,
                "paddingTop": 26 if embedded else 0
            }
        ]}
    >
        <View style={styles.header}>
            <View style={styles.brandMark}>
                <Icon name="branch" size={16} color={C.accentText}/>
            </View>
            <View style={{"flex": 1}}>
                <Text style={styles.title}>diffwalker</Text>
                <Text style={styles.subtitle}>
                    {title
                        + (" · " + str(len(rows)) + " PRs" if tab == "inbox" else "")}
                </Text>
            </View>
            {if reviewing or asking {
                <ActivityIndicator size="small" color={C.accent}/>
            }}
        </View>
        {if not signed {
            <SignInScreen onDone={lambda { signed = True; }}/>
        }}
        {if signed and error {
            <Pressable
                onPress={lambda {
                    error = "";
                    loadRows();
                }}
                style={{
                    "backgroundColor": C.critical + "22",
                    "padding": S.sm,
                    "paddingHorizontal": S.lg
                }}
            >
                <Text style={[styles.small, {"color": C.critical}]}>
                    {error + " · tap to retry"}
                </Text>
            </Pressable>
        }}
        <View style={[styles.body, {"display": "flex" if signed else "none"}]}>
            {if tab == "inbox" {
                <InboxScreen
                    rows={rows}
                    loading={loadingRows}
                    onOpen={openPR}
                    onRefresh={loadRows}
                />
            } elif tab == "review" {
                <ReviewScreen
                    detail={detail}
                    loading={loadingDetail}
                    busy={reviewing}
                    onRun={runReview}
                    onStatus={lambda (fid: str, st: str) { setStatus(fid, st); }}
                    onBack={lambda { tab = "inbox"; }}
                />
            } elif tab == "insights" {
                <InsightsScreen data={dash}/>
            } else {
                <CopilotScreen
                    msgs={msgs}
                    draft={draft}
                    busy={asking}
                    onDraft={lambda (t: str) { draft = t; }}
                    onSend={ask}
                />
            }   }
        </View>
        {if signed {
            <TabBar active={tab} onPick={pick}/>
        }}
    </View>
}
