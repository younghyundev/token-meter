import XCTest
@testable import TokenMeter

@MainActor
final class PopoverContentViewTests: XCTestCase {
    func test_usageViewModelDefaultsToClaudeProvider() {
        let viewModel = UsageViewModel(
            usageService: PopoverMockUsageService(),
            claudeProjectRepository: PopoverMockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude)]),
            codexProjectRepository: PopoverMockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex)]),
            codexStatusRepository: PopoverMockCodexStatusRepository(snapshots: [.loginRequired])
        )

        XCTAssertEqual(viewModel.selectedProvider, .claude)
        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .day)
    }

    func test_codexPopoverStringsResolveInEnglish() {
        LocalizationManager.shared.language = .english

        XCTAssertEqual(L("provider.codex"), "Codex")
        XCTAssertEqual(L("codex.session.title"), "Codex Session")
        XCTAssertEqual(L("footer.refresh.codex"), "Refresh Codex")
        XCTAssertEqual(L("codex.login.title"), "Codex login required")
        XCTAssertEqual(L("codex.unavailable.title"), "Codex unavailable")
        XCTAssertEqual(L("codex.session.window.5h"), "5h window")
        XCTAssertEqual(L("codex.session.window.7d"), "7d window")
        XCTAssertEqual(L("codex.session.resetsIn"), "resets in")
        XCTAssertEqual(L("period.day"), "1 day")
        XCTAssertEqual(L("period.week"), "7 days")
        XCTAssertEqual(L("period.all"), "all")
    }

    func test_claudePopoverStringsStillResolveInEnglish() {
        LocalizationManager.shared.language = .english

        XCTAssertEqual(L("provider.claude"), "Claude")
        XCTAssertEqual(L("session.title"), "Session (5h)")
        XCTAssertEqual(L("weekly.title"), "Weekly (7d)")
        XCTAssertEqual(L("projects.empty"), "No usage data")
        XCTAssertEqual(L("login.title"), "Not logged in")
        XCTAssertEqual(L("login.description"), "Log in to Claude Code first,\nthen relaunch Token Meter.")
    }

    func test_switchingProviderLoadsProviderScopedState() async {
        let claudeRepository = PopoverMockProjectUsageRepository(
            provider: .claude,
            snapshots: [
                ProviderProjectSnapshot(provider: .claude, entries: [], availability: .available)
            ]
        )
        let codexRepository = PopoverMockProjectUsageRepository(
            provider: .codex,
            snapshots: [
                ProviderProjectSnapshot(
                    provider: .codex,
                    entries: [makeEntry(projectPath: "/tmp/workspaces/codex", totalTokens: 21)],
                    availability: .available
                )
            ]
        )
        let viewModel = UsageViewModel(
            usageService: PopoverMockUsageService(),
            claudeProjectRepository: claudeRepository,
            codexProjectRepository: codexRepository,
            codexStatusRepository: PopoverMockCodexStatusRepository(
                snapshots: [.availabilityOnly(title: "Codex available", subtitle: "Authenticated")]
            )
        )

        viewModel.selectedProvider = .codex
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["codex"])
        XCTAssertEqual(viewModel.projectAvailability(for: .codex), .available)
        XCTAssertEqual(viewModel.codexStatusSnapshot, .availabilityOnly(title: "Codex available", subtitle: "Authenticated"))
    }

    func test_usageMetricSnapshotCanFlowToCodexTabState() async {
        let viewModel = UsageViewModel(
            usageService: PopoverMockUsageService(),
            claudeProjectRepository: PopoverMockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude)]),
            codexProjectRepository: PopoverMockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex)]),
            codexStatusRepository: PopoverMockCodexStatusRepository(
                snapshots: [.usageMetric(primaryPercentage: 82, secondaryPercentage: 13, subtitle: "5h window • resets in 43m • 7d window 13% • plus")]
            )
        )

        viewModel.selectedProvider = .codex
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(
            viewModel.codexStatusSnapshot,
            .usageMetric(primaryPercentage: 82, secondaryPercentage: 13, subtitle: "5h window • resets in 43m • 7d window 13% • plus")
        )
        XCTAssertEqual(viewModel.codexWeeklyPercentage, 13)
    }

    func test_switchingBackToClaudeKeepsClaudeStateAvailable() async {
        let claudeRepository = PopoverMockProjectUsageRepository(
            provider: .claude,
            snapshots: [
                ProviderProjectSnapshot(
                    provider: .claude,
                    entries: [makeEntry(projectPath: "/tmp/workspaces/claude", totalTokens: 55)],
                    availability: .available
                )
            ]
        )
        let codexRepository = PopoverMockProjectUsageRepository(
            provider: .codex,
            snapshots: [ProviderProjectSnapshot(provider: .codex, entries: [], availability: .available)]
        )
        let viewModel = UsageViewModel(
            usageService: PopoverMockUsageService(),
            claudeProjectRepository: claudeRepository,
            codexProjectRepository: codexRepository,
            codexStatusRepository: PopoverMockCodexStatusRepository(snapshots: [.loginRequired])
        )

        await viewModel.forceRefresh()
        viewModel.setProjectPeriod(.week, for: .claude)
        viewModel.selectedProvider = .codex
        try? await Task.sleep(for: .milliseconds(20))
        viewModel.selectedProvider = .claude

        XCTAssertEqual(viewModel.selectedProvider, .claude)
        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .week)
        XCTAssertEqual(viewModel.displayProjects(for: .claude).map(\.displayName), ["claude"])
    }

    private func makeSnapshot(provider: UsageProvider) -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(provider: provider, entries: [], availability: .available)
    }

    private func makeEntry(projectPath: String, totalTokens: Int) -> TokenUsageEntry {
        TokenUsageEntry(
            timestamp: .now,
            sessionId: UUID().uuidString,
            projectPath: projectPath,
            model: "test-model",
            inputTokens: totalTokens,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0
        )
    }
}

@MainActor
private final class PopoverMockUsageService: UsageServiceProtocol {
    var sessionPercentage: Double = 0
    var weeklyPercentage: Double = 0
    var resetTimeRemaining: String?
    var fetchState: UsageFetchState = .idle
    var hasCredentials: Bool = true
    var minFetchInterval: TimeInterval = 55

    func loadCredentials() {}
    func fetchUsage(force: Bool) async {}
}

private final class PopoverMockProjectUsageRepository: ProjectUsageRepository {
    private let provider: UsageProvider
    private var snapshots: [ProviderProjectSnapshot]

    init(provider: UsageProvider, snapshots: [ProviderProjectSnapshot]) {
        self.provider = provider
        self.snapshots = snapshots
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        _ = provider
        _ = period
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? ProviderProjectSnapshot(provider: provider, entries: [], availability: .available)
    }
}

private final class PopoverMockCodexStatusRepository: CodexStatusRepositoryProtocol {
    private var snapshots: [CodexStatusSnapshot]

    init(snapshots: [CodexStatusSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot() -> CodexStatusSnapshot {
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? .loginRequired
    }
}
