graph import {
    edge Core: core.* --> cli.* | mobile.* | web.*;

    core.agent.copilot ++> cli.commands.ask { AgentCtx, copilot, set_agent }
    core.analytics ++> cli.commands.browse { contributors, hotspots, languages, stats }
    core.api ++> web.desktop | web.main;
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
    core.site.desktop.BackendGate ++> web.desktop { BackendGate }
    core.site.shell.AppShell ++> web.pages.layout { RootLayout }
}

graph import cli {
    commands.ask ++> main { run_ask_live, run_ask_offline }
    commands.browse ++> main { run_hotspots, run_people, run_prs, run_repo }
    commands.common ++> main {
        DEFAULT_SERVER,
        EXIT_USAGE,
        dim,
        pick_repo,
        red,
        run_login,
        warn
    }
    commands.review ++> main { run_review_live, run_review_offline }
}

graph import cli.commands {
    common ++> [
        ask {
            EXIT_OK,
            EXIT_USAGE,
            bold,
            dim,
            post_sse,
            red,
            unreachable,
            violet,
            warn
        },
        browse { EXIT_OK, EXIT_USAGE, bold, dim, green, red, violet, warn },
        review {
            EXIT_FAILURE,
            EXIT_OK,
            EXIT_UNAVAILABLE,
            EXIT_USAGE,
            bold,
            dim,
            green,
            post_json,
            post_sse,
            red,
            sev_paint,
            unreachable,
            violet,
            warn,
            yellow
        },
    ]
}

graph import core {
    actions ++> [
        agent.copilot { add_finding, add_reply, choose_repo, pin_insight, set_status },
        api {
            add_finding,
            add_reply,
            choose_repo,
            pin_insight,
            set_status,
            unpin_insight
        },
    ]
    agent.copilot ++> api {
        AgentCtx,
        TOOLS,
        clear_stop,
        copilot,
        request_stop,
        set_agent
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
            weekly
        },
        api {
            Contributor,
            CouplingGraph,
            DayCount,
            Hotspot,
            KindMonth,
            LangSlice,
            Ownership,
            RepoStats,
            TreeCell,
            WeekBucket,
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
            weekly
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
            start_review
        },
        site.auth.SignIn { server_info },
        site.built.Built { build_stats },
        site.built.CodeSpotlight { source_snippet },
        site.copilot.CopilotPane { chat_history, clear_chat, pin_card, stop_turn },
        site.pages.Board { board, unpin_card },
        site.pages.Dashboard { dashboard },
        site.pages.Insights {
            activity_view,
            coupling_view,
            hotspots_view,
            people_view,
            structure_view
        },
        site.pages.Reviews { list_reviews },
        site.review.DiffView { add_comment },
        site.review.FindingCard { reply_finding, set_finding_status },
        site.review.ReviewWorkspace { export_markdown, pr_detail },
        site.runner { start_review },
        site.shell.AppShell { publish_review, set_repository },
        site.state { get_workspace },
    ]
    env ++> [
        api { PROJECT_DIR, load_env },
        review.engine { PROJECT_DIR },
    ]
    export ++> agent.copilot | api { review_markdown }
    git.diffparse ++> [
        actions { parse_unified_diff },
        agent.copilot { parse_unified_diff, render_file_patch },
        analytics { language_of },
        api { FileDiff, parse_unified_diff },
        review.context { FileDiff, language_of },
        review.engine {
            FileDiff,
            commentable_lines,
            parse_unified_diff,
            render_file_patch
        },
        review.risk { FileDiff },
    ]
    git.repo ++> [
        actions { PullRequestRef, pr_diff_text, repo_info, resolve_repo },
        agent.copilot {
            PullRequestRef,
            blame_summary,
            discover_prs,
            find_pr,
            grep,
            pr_commits,
            pr_diff_text,
            read_text,
            repo_info
        },
        analytics { git_out, head_sha, memo, repo_info },
        api {
            CommitInfo,
            PullRequestRef,
            RepoInfo,
            discover_prs,
            find_pr,
            forget,
            gh_available,
            pr_commits,
            pr_diff_text,
            repo_info,
            resolve_repo
        },
        review.agents { file_log, grep, read_text },
        review.context { git_out, grep, read_text, safe_ref },
        review.engine {
            CommitInfo,
            PullRequestRef,
            pr_commits,
            pr_diff_text,
            pr_head_ref,
            read_text,
            repo_info
        },
    ]
    graph ++> [
        actions {
            CATEGORIES,
            Covers,
            FileChange,
            Finding,
            HasReview,
            Insight,
            Pinned,
            PullRequest,
            Raised,
            Reply,
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
            workspace
        },
        agent.copilot {
            Review,
            new_id,
            now,
            pr_node,
            repo_node,
            review_findings,
            review_of
        },
        api {
            ChatMsg,
            ChatThread,
            CodeRef,
            FeedItem,
            Finding,
            HasPR,
            HasReview,
            Insight,
            Review,
            StageCost,
            StageState,
            ToolTrace,
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
            workspace
        },
        export { Finding, Review, review_files },
        review.context { CalledFrom, ChangesWith, CodeRef, FileChange, TestedBy },
        review.engine {
            CodeRef,
            Covers,
            FeedItem,
            FileChange,
            Finding,
            HasReview,
            Raised,
            Review,
            StageState,
            ensure_pr,
            ensure_repo,
            new_id,
            now,
            refresh_pr_rollup,
            review_findings,
            review_pr
        },
        review.meter { StageCost },
    ]
    live ++> [
        actions { changed },
        agent.copilot { current_user, ui },
        api {
            changed,
            current_user,
            emit,
            events_after,
            latest_seq,
            set_session,
            wait_events
        },
        review.engine { current_user, emit },
    ]
    native.DiffwalkerMobile ++> site.built.Built { DiffwalkerMobile }
    review.engine ++> [
        actions { Draft, anchor, finding_dict },
        agent.copilot { pr_running, run_review },
        api { is_active, llm_ready, model_label, model_name, pr_running, run_review },
    ]
    review.risk ++> [
        agent.copilot { triage },
        api { FileRisk, triage },
    ]
    utils ++> site.ui.badge
        | site.ui.button
        | site.ui.card
        | site.ui.dialog
        | site.ui.dropdown_menu
        | site.ui.input
        | site.ui.progress
        | site.ui.scroll_area
        | site.ui.select
        | site.ui.separator
        | site.ui.sheet
        | site.ui.skeleton
        | site.ui.switch
        | site.ui.tabs
        | site.ui.textarea
        | site.ui.tooltip { cn }
}

graph import core.native {
    icon ++> DiffwalkerMobile { Icon }
    theme ++> DiffwalkerMobile { C, R, S, risk_tone, sev_tone, styles, verdict_tone }
}

graph import core.review {
    agents ++> engine {
        DraftCheck,
        DraftFinding,
        FileBrief,
        FilePlan,
        ReviewPlan,
        ReviewSummary,
        Reviewer,
        Verdict,
        VerdictKind,
        plan_review,
        synthesize,
        verify_file
    }
    context ++> engine { build_context, ref_excerpt }
    meter ++> [
        agents { budget_guard },
        engine { Meter, REVIEW_BUDGET, bill_to, metered, unbill },
    ]
    risk ++> [
        context { file_kind },
        engine { FileRisk, overall_risk, static_hits, triage },
    ]
}

graph import core.site {
    charts.ChartCard ++> copilot.CopilotPane | pages.Board { ChartCard }
    charts.advanced ++> [
        pages.Dashboard { CalendarHeatmap },
        pages.Insights { CalendarHeatmap, Network, Scatter, Treemap },
    ]
    charts.basic ++> [
        built.Built { HBars },
        pages.Dashboard { Donut, HBars, Sparkline },
        pages.Insights { BarChart, Donut, HBars, LineChart, StackedBars },
        pages.Reviews { Donut },
        review.ReviewWorkspace { Donut, Gauge, HBars },
    ]
    components ++> [
        built.Built { Panel, StatTile },
        pages.Board { Empty, PageHeader, Skeleton },
        pages.Dashboard {
            Empty,
            PRLine,
            PageHeader,
            Panel,
            SevBadge,
            Skeleton,
            StatTile
        },
        pages.Insights { Empty, PageHeader, Panel, Skeleton, StatTile },
        pages.Reviews { Empty, PRLine, PageHeader, Panel, Skeleton },
        review.FindingCard { SevBadge },
        review.ReviewWorkspace {
            Empty,
            KindBadge,
            Panel,
            RiskMeter,
            Skeleton,
            VerdictPill
        },
    ]
    copilot.CopilotPane ++> shell.AppShell { CopilotPane }
    desktop.BackendGate ++> [
        auth.SignIn { ModeSwitch },
        shell.AppShell { ModeSwitch, profiles_on },
    ]
    fmt ++> [
        built.Built { fmt_num, series_color },
        charts.ChartCard { ago, series_color, sev_color },
        charts.advanced { base_name, fmt_bytes, fmt_num, series_color },
        charts.basic { fmt_num, risk_color, risk_label, series_color },
        components {
            SEV_LABEL,
            ago_iso,
            fmt_num,
            risk_color,
            risk_label,
            sev_color,
            verdict_color,
            verdict_label
        },
        pages.Dashboard { ago, base_name, dir_name, fmt_bytes, fmt_num },
        pages.Insights {
            ago,
            base_name,
            dir_name,
            fmt_bytes,
            fmt_num,
            pct,
            series_color,
            short_path
        },
        pages.Reviews { risk_color },
        review.DiffView { base_name, dir_name, risk_color, sev_order },
        review.FindingCard { ago, sev_color },
        review.ReviewWorkspace {
            ago,
            base_name,
            dir_name,
            fmt_num,
            risk_color,
            sev_color,
            sev_order,
            verdict_label
        },
    ]
    live ++> [
        copilot.CopilotPane {
            new_thread,
            on_channel,
            on_live,
            read_sse,
            session_id,
            thread_id,
            toast
        },
        pages.Board | review.DiffView { toast },
        review.ReviewWorkspace { on_channel, on_live, publish, toast },
        runner { publish, session_id, signed_out, toast },
        shell.AppShell {
            live_status,
            on_channel,
            on_live,
            publish,
            rand_id,
            session_id,
            signed_out,
            start_live,
            toast
        },
        state { on_channel, on_live, publish, signed_out },
    ]
    markdown ++> copilot.CopilotPane
        | review.FindingCard
        | review.ReviewWorkspace
        | shell.AppShell { Markdown }
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
            useWorkspace
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
        WalkerDiagram
    }
}

graph import core.site.charts {
    MermaidDiagram ++> ChartCard { MermaidDiagram }
    basic ++> [
        ChartCard { BarChart, Donut, HBars, LineChart, StackedBars },
        advanced { Legend, Tooltip, vmax },
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
