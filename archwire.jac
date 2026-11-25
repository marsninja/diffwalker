graph layers {
    """What every app shares: the types that cross, git, the graph, the review, the Copilot, the endpoints."""
    layer shared {
        """The types that cross between the server and its callers."""
        layer wire { core.wire; }

        """The project's own settings, and the repositories git and gh read."""
        layer repos { core.env | core.git.*; }

        """Each user's graph, and the live events that tell their screens it changed."""
        layer state { core.graph | core.live; }

        """What diffwalker works out: a repository's history, the review pipeline, a review's export."""
        layer analysis { core.analytics | core.export | core.review.*; }

        """What changes a user's graph: the actions a button and the Copilot share, and the Copilot."""
        layer actions { core.actions | core.agent.*; }

        """Every endpoint the server answers."""
        layer api { core.api; }
    }

    """Each app's own modules."""
    layer apps {
        """The site: its pages, their components, and the browser entry."""
        layer site { web | pages.* | core.site.* | core.utils; }

        """The phone app: its entry and its component."""
        layer phone { mobile.* | core.native.*; }

        """The command-line app."""
        layer cli { cli.*; }
    }
}

graph spaces {
    space site: browser { entry web; pages.* | core.site.*; }
    space phone: hermes { entry mobile.main; }
    space api: native { core.api; }
    space cli: native { entry cli.main; }

    app web { run api; serve site; }
    app desktop { run site; }
    app mobile { run phone; }
    app cli { run cli; }
}

graph spaces local {
    app desktop { run site, api; }
}

graph import {
    """The apps are made from what they share."""
    edge Shared: shared --> apps;
    """Everything names the types that cross."""
    edge Wire: wire --> repos | state | analysis | actions | api | site | phone | cli;
    """Git and the project's settings feed the analysis, the actions, the server and the command line."""
    edge Repos: repos --> analysis | actions | api | cli;
    """The graph and its live events are read and written above them."""
    edge State: state --> analysis | actions | api | cli;
    """The analysis is what the actions, the server and the command line report."""
    edge Analysis: analysis --> actions | api | cli;
    """The server and the command line act through the actions and the Copilot."""
    edge Actions: actions --> api | cli;
    """Each app calls the server's endpoints."""
    edge Endpoints: api --> site | phone | cli;
    """The site's "How it's built" page embeds the phone app."""
    edge Embedded: phone --> site;

    core.agent.copilot ++> cli.commands.ask { AgentCtx, copilot, set_agent }
    core.analytics ++> cli.commands.browse { contributors, hotspots, languages, stats }
    core.api ++> [
        cli.commands.ask { copilot_stream },
        cli.commands.review { live, start_review },
    ]
    core.env ++> cli.commands.common { PROJECT_DIR }
    core.git.repo ++> [
        cli.commands.browse { discover_prs, repo_info },
        cli.commands.common { resolve_repo },
        cli.commands.review { find_pr },
    ]
    core.graph ++> cli.commands.review { find_review, review_findings }
    core.live ++> [
        cli.commands.ask { current_user, tap },
        cli.commands.review { tap },
    ]
    core.native.DiffwalkerMobile ++> mobile.main { DiffwalkerMobile }
    core.review.engine ++> [
        cli.commands.ask { llm_ready },
        cli.commands.review { llm_ready, run_review },
    ]
    core.review.meter ++> cli.commands.ask { tokens_of }
    core.site.auth.SignIn ++> pages.login { SignIn }
    core.site.built.Built ++> pages.built { Built }
    core.site.pages.Board ++> pages.board { Board }
    core.site.pages.Dashboard ++> pages.index { Dashboard }
    core.site.pages.Insights ++> pages.insights { Insights }
    core.site.pages.Reviews ++> pages.reviews.index { Reviews }
    core.site.review.ReviewWorkspace ++> pages.reviews { ReviewWorkspace }
    core.site.desktop.BackendGate ++> web { BackendGate }
    core.site.shell.AppShell ++> pages.layout { RootLayout }
    core.wire ++> [
        cli.commands.ask { Card, CopilotFrame, LiveEvent, UiArgs },
        cli.commands.review { LiveEvent, ReviewBrief },
    ]
}

graph import cli {
    commands.ask ++> main { run_ask_live, run_ask_offline }
    commands.browse ++> main { run_hotspots, run_people, run_prs, run_repo }
    commands.common ++> main { DEFAULT_SERVER, EXIT_USAGE, dim, pick_repo, red, run_login, warn }
    commands.review ++> main { run_review_live, run_review_offline }
}

graph import cli.commands {
    common ++> [
        ask { EXIT_OK, EXIT_USAGE, bold, dim, red, unreachable, use_server, violet, warn },
        browse { EXIT_OK, EXIT_USAGE, bold, dim, green, red, violet, warn },
        review {
            EXIT_FAILURE,
            EXIT_OK,
            EXIT_UNAVAILABLE,
            EXIT_USAGE,
            bold,
            dim,
            green,
            red,
            sev_paint,
            unreachable,
            use_server,
            violet,
            warn,
            yellow,
        },
    ]
}

graph import core {
    actions ++> [
        agent.copilot { add_finding, add_reply, choose_repo, pin_insight, set_status },
        api { add_finding, add_reply, choose_repo, pin_insight, set_status, unpin_insight },
    ]
    agent.copilot ++> api {
        AgentCtx,
        HISTORY_CHARS,
        TOOLS,
        clear_stop,
        copilot,
        request_stop,
        set_agent,
    }
    analytics ++> [
        agent.copilot {
            contributors,
            coupling,
            hotspots,
            kinds_by_month,
            languages,
            ownership,
            stats,
            weekly,
        },
        api {
            activity,
            contributors,
            coupling,
            hotspots,
            kinds_by_month,
            languages,
            ownership,
            stats,
            structure,
            warm,
            weekly,
        },
        review.context { history },
        review.engine { hotspots },
    ]
    api ++> [
        native.DiffwalkerMobile {
            copilot_ask,
            dashboard,
            list_reviews,
            pr_detail,
            set_finding_status,
            start_review,
        },
        site.auth.SignIn { server_info },
        site.live { live },
        site.built.Built { build_stats },
        site.built.CodeSpotlight { source_snippet },
        site.copilot.CopilotPane { chat_history, clear_chat, copilot_stream, pin_card, stop_turn },
        site.pages.Board { board, unpin_card },
        site.pages.Dashboard { dashboard },
        site.pages.Insights {
            activity_view,
            coupling_view,
            hotspots_view,
            people_view,
            structure_view,
        },
        site.pages.Reviews { list_reviews },
        site.review.DiffView { add_comment },
        site.review.FindingCard { reply_finding, set_finding_status },
        site.review.ReviewWorkspace { export_markdown, pr_detail },
        site.runner { start_review },
        site.shell.AppShell { publish_review, set_repository },
        site.state { get_workspace },
    ]
    env ++> api { PROJECT_DIR, load_env }
    export ++> agent.copilot | api { review_markdown }
    git.diffparse ++> [
        actions { parse_unified_diff },
        agent.copilot { parse_unified_diff, render_file_patch },
        analytics { language_of },
        api { parse_unified_diff },
        review.context { language_of },
        review.engine { commentable_lines, parse_unified_diff, render_file_patch },
    ]
    git.repo ++> [
        actions { pr_diff_text, repo_info, resolve_repo },
        agent.copilot {
            blame_summary,
            discover_prs,
            find_pr,
            grep,
            pr_commits,
            pr_diff_text,
            read_text,
            repo_info,
        },
        analytics { git_out, head_sha, memo, repo_info },
        api {
            discover_prs,
            find_pr,
            forget,
            gh_available,
            pr_commits,
            pr_diff_text,
            repo_info,
            resolve_repo,
        },
        review.agents { file_log, grep, read_text },
        review.context { git_out, grep, read_text, safe_ref },
        review.engine { pr_commits, pr_diff_text, pr_head_ref, read_text, repo_info },
    ]
    graph ++> [
        actions {
            CATEGORIES,
            Covers,
            FileChange,
            HasReview,
            Pinned,
            PullRequest,
            Raised,
            Review,
            SEVERITIES,
            ensure_pr,
            ensure_repo,
            file_change,
            find_finding,
            new_id,
            now,
            refresh_pr_rollup,
            repo_node,
            review_of,
            touch_rollup,
            workspace,
        },
        agent.copilot { Review, new_id, now, pr_node, repo_node, review_findings, review_of },
        api {
            CodeRef,
            HasPR,
            HasReview,
            Review,
            chat_thread,
            find_review,
            now,
            pr_node,
            pr_reviews,
            repo_findings,
            repo_insights,
            repo_node,
            review_files,
            review_findings,
            review_of,
            workspace,
        },
        export { Review, review_files },
        review.context { CalledFrom, ChangesWith, CodeRef, FileChange, TestedBy },
        review.engine {
            CodeRef,
            Covers,
            FileChange,
            HasReview,
            Raised,
            Review,
            ensure_pr,
            ensure_repo,
            new_id,
            now,
            refresh_pr_rollup,
            review_findings,
            review_pr,
        },
    ]
    live ++> [
        actions { changed },
        agent.copilot { current_user, ui },
        api { changed, current_user, emit, events_after, latest_seq, set_session, wait_events },
        review.engine { current_user, emit },
    ]
    native.DiffwalkerMobile ++> site.built.Built { DiffwalkerMobile }
    review.engine ++> [
        actions { Draft, anchor },
        agent.copilot { pr_running, run_review },
        api { is_active, llm_ready, model_label, model_name, pr_running, run_review },
    ]
    review.meter ++> [
        agent.copilot { over_budget },
        api { tokens_of },
    ]
    review.risk ++> [
        agent.copilot { triage },
        api { triage },
    ]
    utils ++> site.ui.badge | site.ui.button | site.ui.card | site.ui.dialog | site.ui.dropdown_menu | site.ui.input | site.ui.progress | site.ui.scroll_area | site.ui.select | site.ui.separator | site.ui.sheet | site.ui.skeleton | site.ui.switch | site.ui.tabs | site.ui.textarea | site.ui.tooltip {
        cn,
    }
    wire ++> [
        actions { Finding, Insight, PullRequestRef, Reply },
        agent.copilot { Card, PullRequestRef, UiArgs },
        analytics {
            Contributor,
            CouplingEdge,
            CouplingGraph,
            CouplingNode,
            DayCount,
            Hotspot,
            KindMonth,
            LangSlice,
            Ownership,
            RepoStats,
            TreeCell,
            WeekBucket,
        },
        api {
            ActivityView,
            AppSize,
            BuildStats,
            Card,
            ChatMsg,
            ChatReply,
            CodeSnippet,
            CopilotFrame,
            CouplingGraph,
            DashboardView,
            FileNote,
            Finding,
            Hotspot,
            Insight,
            LiveData,
            LiveEvent,
            PRDetail,
            PRRow,
            PeopleView,
            ReviewBrief,
            ReviewView,
            ServerInfo,
            StructureView,
            ToolTrace,
            UiArgs,
            UiCommand,
            WorkspaceView,
        },
        export { Finding },
        git.diffparse { DiffLine, FileDiff, Hunk },
        git.repo { CommitInfo, PullRequestRef, RepoInfo },
        graph { ChatMsg, FeedItem, Finding, Insight, StageCost, StageState },
        live { LiveData, LiveEvent, UiArgs },
        native.DiffwalkerMobile { DashboardView, Finding, PRDetail, PRRow, StageState },
        review.context { FileDiff },
        review.engine {
            CommitInfo,
            DraftNote,
            FeedItem,
            FileDiff,
            FileRisk,
            Finding,
            LiveData,
            PullRequestRef,
            StageState,
        },
        review.meter { StageCost },
        review.risk { FileDiff, FileRisk },
        site.auth.SignIn { ServerInfo },
        site.built.Built { BuildStats },
        site.built.CodeSpotlight { CodeSnippet },
        site.charts.advanced { CouplingEdge, CouplingNode, DayCount, TreeCell },
        site.components { PRRow },
        site.copilot.CopilotPane { Card, ChatMsg, CopilotFrame, LiveEvent },
        site.live { LiveEvent },
        site.pages.Board { Insight },
        site.pages.Dashboard { DashboardView, DayCount },
        site.pages.Insights {
            ActivityView,
            CouplingGraph,
            Hotspot,
            PeopleView,
            StructureView,
            TreeCell,
        },
        site.pages.Reviews { PRRow },
        site.review.DiffView { FileDiff, FileRisk, Finding },
        site.review.FindingCard { Finding },
        site.review.Pipeline { StageState },
        site.review.ReviewWorkspace {
            FeedItem,
            FileRisk,
            Finding,
            LiveEvent,
            PRDetail,
            ReviewView,
            StageState,
            UiArgs,
        },
        site.runner { ReviewBrief },
        site.shell.AppShell { LiveEvent, UiArgs, WorkspaceView },
        site.state { LiveEvent, WorkspaceView },
    ]
}

graph import core.native {
    icon ++> DiffwalkerMobile { Icon }
    insets ++> DiffwalkerMobile { bottom_inset, top_inset }
    theme ++> DiffwalkerMobile { C, R, S, risk_tone, sev_tone, styles, verdict_tone }
}

graph import core.review {
    agents ++> engine {
        BatchReview,
        DraftCheck,
        DraftFinding,
        FileBrief,
        FilePlan,
        FileReview,
        FileSummary,
        ReviewPlan,
        ReviewSummary,
        Reviewer,
        Verdict,
        VerdictKind,
        plan_review,
        synthesize,
        verify_file,
    }
    context ++> engine { build_context, ref_excerpt }
    meter ++> [
        agents { budget_guard },
        engine { Meter, REVIEW_BUDGET, UNPRICED, answered_by, bill_to, metered, unbill },
    ]
    risk ++> [
        context { file_kind },
        engine { overall_risk, static_hits, triage },
    ]
}

graph import core.site {
    charts.ChartCard ++> copilot.CopilotPane | pages.Board { ChartCard }
    charts.advanced ++> [
        pages.Dashboard { CalendarHeatmap },
        pages.Insights { CalendarHeatmap, Network, Scatter, ScatterPoint, Treemap },
    ]
    charts.basic ++> [
        built.Built { HBars },
        pages.Dashboard { Donut, HBars, Sparkline },
        pages.Insights { BarChart, Donut, HBars, LineChart, Series, StackedBars, TipLine },
        pages.Reviews { Donut },
        review.ReviewWorkspace { Donut, Gauge, HBars },
    ]
    components ++> [
        built.Built { Panel, StatTile },
        pages.Board { Empty, PageHeader, Skeleton },
        pages.Dashboard { Empty, PRLine, PageHeader, Panel, SevBadge, Skeleton, StatTile },
        pages.Insights { Empty, PageHeader, Panel, Skeleton, StatTile },
        pages.Reviews { Empty, PRLine, PageHeader, Panel, Skeleton },
        review.FindingCard { SevBadge },
        review.ReviewWorkspace { Empty, KindBadge, Panel, RiskMeter, Skeleton, VerdictPill },
    ]
    copilot.CopilotPane ++> shell.AppShell { CopilotPane }
    desktop.BackendGate ++> auth.SignIn | shell.AppShell { ModeSwitch }
    desktop.desk ++> [
        desktop.BackendGate { Desk, choose_mode, desk, leave_profile, load_desk, open_profile },
        live { leave_profile, profiles_on },
        shell.AppShell { profiles_on },
    ]
    fmt ++> [
        built.Built { fmt_num, series_color },
        charts.ChartCard { ago, series_color, sev_color },
        charts.advanced { base_name, fmt_bytes, fmt_num, series_color },
        charts.basic { fmt_num, risk_color, risk_label, series_color },
        copilot.CopilotPane { num_text },
        components {
            SEV_LABEL,
            ago_iso,
            fmt_num,
            risk_color,
            risk_label,
            sev_color,
            verdict_color,
            verdict_label,
        },
        pages.Dashboard { ago, base_name, dir_name, fmt_bytes, fmt_num, num_text },
        pages.Insights {
            ago,
            base_name,
            dir_name,
            fmt_bytes,
            fmt_num,
            pct,
            series_color,
            short_path,
        },
        pages.Reviews { risk_color },
        review.DiffView { base_name, dir_name, risk_color, sev_order },
        review.FindingCard { ago, sev_color },
        review.ReviewWorkspace {
            ago,
            base_name,
            dir_name,
            fmt_num,
            num_text,
            risk_color,
            sev_color,
            sev_order,
            verdict_label,
        },
        runner { num_text },
    ]
    live ++> [
        copilot.CopilotPane {
            new_thread,
            on_channel,
            on_live,
            session_id,
            signed_out,
            thread_id,
            toast,
        },
        pages.Board | review.DiffView { toast },
        review.ReviewWorkspace { on_channel, on_live, publish, toast },
        runner { publish, session_id, signed_out, toast },
        shell.AppShell {
            Toast,
            live_status,
            on_channel,
            on_live,
            publish,
            rand_id,
            session_id,
            signed_out,
            start_live,
            toast,
        },
        state { on_channel, on_live, publish, signed_out },
    ]
    markdown ++> copilot.CopilotPane | review.FindingCard | review.ReviewWorkspace | shell.AppShell {
        Markdown,
    }
    runner ++> [
        pages.Dashboard | pages.Reviews { launch_review },
        review.ReviewWorkspace { is_running, launch_review },
    ]
    shell.Brand ++> auth.SignIn | desktop.BackendGate { Wordmark }
    state ++> [
        built.Built | review.FindingCard | review.ReviewWorkspace { ask_copilot },
        copilot.CopilotPane { set_pane, take_pending_ask, useWorkspace },
        pages.Board | pages.Insights { ask_copilot, useLiveReload },
        pages.Dashboard | pages.Reviews { useLiveReload },
        shell.AppShell {
            apply_theme,
            init_theme,
            refresh_workspace,
            set_pane,
            useDark,
            usePane,
            useWorkspace,
        },
    ]
}

graph import core.site.built {
    CodeSpotlight ++> Built { CodeSpotlight }
    PhoneFrame ++> Built { PhoneFrame }
    diagrams ++> Built {
        AgentLoopDiagram,
        ArchitectureDiagram,
        GraphDiagram,
        PipelineDiagram,
        WalkerDiagram,
    }
}

graph import core.site.charts {
    MermaidDiagram ++> ChartCard { MermaidDiagram }
    basic ++> [
        ChartCard { BarChart, Donut, HBars, LineChart, Series, StackedBars },
        advanced { Legend, LegendItem, Tip, TipLine, Tooltip, vmax },
    ]
}

graph import core.site.review {
    DiffView ++> ReviewWorkspace { FileDiffView, FileList }
    FindingCard ++> DiffView | ReviewWorkspace { FindingCard }
    Pipeline ++> ReviewWorkspace { Pipeline, default_stages }
}

graph import core.site.shell {
    Brand ++> AppShell { BrandMark, Wordmark }
}

graph import core.site.ui {
    button ++> [
        dialog { buttonVariants },
        sheet { Button },
    ]
}
