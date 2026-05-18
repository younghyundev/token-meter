import XCTest
@testable import TokenMeter

@MainActor
final class UsageViewModelTests: XCTestCase {
    func test_providerProjectPeriodsRemainIndependent() {
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: MockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex, entries: [])]),
            codexStatusRepository: MockCodexStatusRepository(snapshots: [.loginRequired])
        )

        viewModel.setProjectPeriod(.week, for: .claude)
        viewModel.setProjectPeriod(.all, for: .codex)

        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .week)
        XCTAssertEqual(viewModel.currentProjectPeriod(for: .codex), .all)
        XCTAssertEqual(viewModel.claudeProjectPeriod, .week)
        XCTAssertEqual(viewModel.codexProjectPeriod, .all)
    }

    func test_forceRefreshFetchesClaudeUsageAndClaudeProjectsWhenClaudeIsSelected() async {
        let usageService = MockUsageService()
        let claudeRepository = MockProjectUsageRepository(
            provider: .claude,
            snapshots: [makeSnapshot(provider: .claude, entries: [makeEntry(projectPath: "/tmp/workspaces/claude", totalTokens: 34)])]
        )
        let codexRepository = MockProjectUsageRepository(
            provider: .codex,
            snapshots: [makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/workspaces/codex", totalTokens: 13)])]
        )
        let viewModel = UsageViewModel(
            usageService: usageService,
            claudeProjectRepository: claudeRepository,
            codexProjectRepository: codexRepository,
            codexStatusRepository: MockCodexStatusRepository(snapshots: [.loginRequired])
        )

        await viewModel.forceRefresh()

        XCTAssertEqual(viewModel.selectedProvider, .claude)
        XCTAssertEqual(usageService.fetchInvocations, [.forced])
        XCTAssertEqual(claudeRepository.requestedPeriods, [.day])
        XCTAssertTrue(codexRepository.requestedPeriods.isEmpty)
        XCTAssertEqual(viewModel.displayProjects(for: .claude).map(\.displayName), ["claude"])
    }

    func test_refreshUpdatesCodexStatusEvenWhenClaudeIsSelected() async {
        let codexStatusRepository = MockCodexStatusRepository(
            snapshots: [
                .usageMetric(
                    primaryPercentage: 17,
                    secondaryPercentage: 23,
                    subtitle: "5h window • 7d window 23%"
                )
            ]
        )
        let codexRepository = MockProjectUsageRepository(
            provider: .codex,
            snapshots: [makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/workspaces/codex", totalTokens: 13)])]
        )
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: codexRepository,
            codexStatusRepository: codexStatusRepository
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.selectedProvider, .claude)
        XCTAssertEqual(codexStatusRepository.snapshotCalls, 1)
        XCTAssertTrue(codexRepository.requestedPeriods.isEmpty)
        XCTAssertEqual(viewModel.codexSessionPercentage, 17)
        XCTAssertEqual(viewModel.codexWeeklyPercentage, 23)
    }

    func test_forceRefreshPreservesSelectedProviderAndOnlyRefreshesVisibleProvider() async {
        let usageService = MockUsageService()
        let claudeRepository = MockProjectUsageRepository(
            provider: .claude,
            snapshots: [makeSnapshot(provider: .claude, entries: [makeEntry(projectPath: "/tmp/workspaces/claude", totalTokens: 8)])]
        )
        let codexRepository = MockProjectUsageRepository(
            provider: .codex,
            snapshots: [makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/workspaces/codex", totalTokens: 13)])]
        )
        let codexStatusRepository = MockCodexStatusRepository(
            snapshots: [.availabilityOnly(title: "Codex available", subtitle: "Authenticated")]
        )
        let viewModel = UsageViewModel(
            usageService: usageService,
            claudeProjectRepository: claudeRepository,
            codexProjectRepository: codexRepository,
            codexStatusRepository: codexStatusRepository
        )

        viewModel.selectedProvider = .codex
        await Task.yield()

        await viewModel.forceRefresh()

        XCTAssertEqual(viewModel.selectedProvider, .codex)
        XCTAssertTrue(usageService.fetchInvocations.isEmpty)
        XCTAssertTrue(claudeRepository.requestedPeriods.isEmpty)
        XCTAssertEqual(codexRepository.requestedPeriods.last, .day)
        XCTAssertGreaterThanOrEqual(codexRepository.requestedPeriods.count, 1)
        XCTAssertGreaterThanOrEqual(codexStatusRepository.snapshotCalls, 1)
        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["codex"])
        XCTAssertEqual(viewModel.codexStatusSnapshot, .availabilityOnly(title: "Codex available", subtitle: "Authenticated"))
    }

    func test_codexEmptySnapshotPublishesAvailableEmptyState() async {
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: MockProjectUsageRepository(
                provider: .codex,
                snapshots: [
                    ProviderProjectSnapshot(
                        provider: .codex,
                        entries: [],
                        availability: .available
                    )
                ]
            ),
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [.availabilityOnly(title: "Codex available", subtitle: "Authenticated")]
            )
        )

        viewModel.selectedProvider = .codex
        await viewModel.refresh()

        XCTAssertEqual(viewModel.codexProjectAvailability, .available)
        XCTAssertTrue(viewModel.codexProjects.isEmpty)
        XCTAssertTrue(viewModel.displayProjects(for: .codex).isEmpty)
        XCTAssertEqual(viewModel.projectAvailability(for: .codex), .available)
        XCTAssertEqual(viewModel.codexStatusSnapshot, .availabilityOnly(title: "Codex available", subtitle: "Authenticated"))
    }

    func test_codexUsageMetricSnapshotIsPublished() async {
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: MockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex, entries: [])]),
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [.usageMetric(primaryPercentage: 39, secondaryPercentage: 9, subtitle: "5h window • resets in 1h 12m • 7d window 9% • prolite")]
            )
        )

        viewModel.selectedProvider = .codex
        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.codexStatusSnapshot,
            .usageMetric(primaryPercentage: 39, secondaryPercentage: 9, subtitle: "5h window • resets in 1h 12m • 7d window 9% • prolite")
        )
        XCTAssertEqual(viewModel.codexSessionPercentage, 39)
        XCTAssertEqual(viewModel.codexWeeklyPercentage, 9)
        XCTAssertEqual(viewModel.menuBarPercentage, 39)
    }

    func test_menuBarPercentageUsesCodexMetricWhenCodexSelected() async {
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: MockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex, entries: [])]),
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [.usageMetric(primaryPercentage: 82, secondaryPercentage: 13, subtitle: "5h window • resets in 43m • 7d window 13% • plus")]
            )
        )

        viewModel.selectedProvider = .codex
        await viewModel.refresh()

        XCTAssertEqual(viewModel.menuBarPercentage, 82)
    }

    func test_claudePeriodIsPreservedAfterSwitchingAwayAndBack() async {
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: MockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex, entries: [])]),
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [
                    .availabilityOnly(title: "Codex available", subtitle: "Authenticated")
                ]
            )
        )

        viewModel.setProjectPeriod(.week, for: .claude)
        viewModel.selectedProvider = .codex
        await Task.yield()
        viewModel.selectedProvider = .claude
        await Task.yield()

        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .week)
        XCTAssertEqual(viewModel.projectPeriod, .week)
    }

    func test_settingClaudePeriodReloadsClaudeProjectsForSelectedPeriod() async {
        let claudeRepository = PeriodAwareMockProjectUsageRepository(
            provider: .claude,
            snapshotsByPeriod: [
                .day: makeSnapshot(provider: .claude, entries: [makeEntry(projectPath: "/tmp/day", totalTokens: 10)]),
                .week: makeSnapshot(provider: .claude, entries: [makeEntry(projectPath: "/tmp/week", totalTokens: 20)]),
                .all: makeSnapshot(provider: .claude, entries: [makeEntry(projectPath: "/tmp/all", totalTokens: 30)])
            ]
        )
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: claudeRepository,
            codexProjectRepository: MockProjectUsageRepository(provider: .codex, snapshots: [makeSnapshot(provider: .codex, entries: [])]),
            codexStatusRepository: MockCodexStatusRepository(snapshots: [.loginRequired])
        )

        viewModel.setProjectPeriod(.week, for: .claude)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .week)
        XCTAssertEqual(viewModel.displayProjects(for: .claude).map(\.displayName), ["week"])
        XCTAssertEqual(claudeRepository.requestedPeriods.last, .week)
    }

    func test_settingCodexPeriodReloadsCodexProjectsForSelectedPeriod() async {
        let codexRepository = PeriodAwareMockProjectUsageRepository(
            provider: .codex,
            snapshotsByPeriod: [
                .day: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/day", totalTokens: 10)]),
                .week: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/week", totalTokens: 20)]),
                .all: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/all", totalTokens: 30)])
            ]
        )
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: codexRepository,
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [.availabilityOnly(title: "Codex available", subtitle: "Authenticated")]
            )
        )

        viewModel.selectedProvider = .codex
        await Task.yield()
        viewModel.setProjectPeriod(.all, for: .codex)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.currentProjectPeriod(for: .codex), .all)
        XCTAssertEqual(viewModel.projectPeriod, .all)
        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["all"])
        XCTAssertEqual(codexRepository.requestedPeriods.last, .all)
    }

    func test_settingCodexPeriodDoesNotRefreshCodexSessionStatus() async {
        let codexStatusRepository = MockCodexStatusRepository(
            snapshots: [
                .usageMetric(
                    primaryPercentage: 42,
                    secondaryPercentage: 11,
                    subtitle: "5h window • resets in 1h"
                )
            ]
        )
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: PeriodAwareMockProjectUsageRepository(
                provider: .codex,
                snapshotsByPeriod: [
                    .day: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/day", totalTokens: 10)]),
                    .all: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/all", totalTokens: 30)])
                ]
            ),
            codexStatusRepository: codexStatusRepository
        )

        viewModel.selectedProvider = .codex
        try? await Task.sleep(for: .milliseconds(50))
        let statusCallsAfterSelectingCodex = codexStatusRepository.snapshotCalls

        viewModel.setProjectPeriod(.all, for: .codex)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(statusCallsAfterSelectingCodex, 1)
        XCTAssertEqual(codexStatusRepository.snapshotCalls, statusCallsAfterSelectingCodex)
        XCTAssertEqual(viewModel.codexSessionPercentage, 42)
        XCTAssertEqual(viewModel.codexWeeklyPercentage, 11)
    }

    func test_settingPreviouslyLoadedCodexPeriodShowsCachedProjectsImmediately() async {
        let codexRepository = PeriodAwareMockProjectUsageRepository(
            provider: .codex,
            snapshotsByPeriod: [
                .day: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/day", totalTokens: 10)]),
                .all: makeSnapshot(provider: .codex, entries: [makeEntry(projectPath: "/tmp/all", totalTokens: 30)])
            ],
            delay: .milliseconds(100)
        )
        let viewModel = UsageViewModel(
            usageService: MockUsageService(),
            claudeProjectRepository: MockProjectUsageRepository(provider: .claude, snapshots: [makeSnapshot(provider: .claude, entries: [])]),
            codexProjectRepository: codexRepository,
            codexStatusRepository: MockCodexStatusRepository(
                snapshots: [.availabilityOnly(title: "Codex available", subtitle: "Authenticated")]
            )
        )

        viewModel.selectedProvider = .codex
        viewModel.setProjectPeriod(.all, for: .codex)
        XCTAssertTrue(viewModel.projectLoading(for: .codex))
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(viewModel.projectLoading(for: .codex))
        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["all"])

        viewModel.setProjectPeriod(.day, for: .codex)
        XCTAssertTrue(viewModel.projectLoading(for: .codex))
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(viewModel.projectLoading(for: .codex))
        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["day"])

        viewModel.setProjectPeriod(.all, for: .codex)

        XCTAssertFalse(viewModel.projectLoading(for: .codex))
        XCTAssertEqual(viewModel.displayProjects(for: .codex).map(\.displayName), ["all"])
    }

    private func makeSnapshot(provider: UsageProvider, entries: [TokenUsageEntry]) -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(
            provider: provider,
            entries: entries,
            availability: .available
        )
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

private enum FetchInvocation: Equatable {
    case nonForced
    case forced
}

@MainActor
private final class MockUsageService: UsageServiceProtocol {
    var sessionPercentage: Double = 0
    var weeklyPercentage: Double = 0
    var resetTimeRemaining: String?
    var fetchState: UsageFetchState = .idle
    var hasCredentials: Bool = true
    var minFetchInterval: TimeInterval = 55
    private(set) var fetchInvocations: [FetchInvocation] = []

    func loadCredentials() {}

    func fetchUsage(force: Bool) async {
        fetchInvocations.append(force ? .forced : .nonForced)
    }
}

private final class MockProjectUsageRepository: ProjectUsageRepository {
    private let provider: UsageProvider
    private var snapshots: [ProviderProjectSnapshot]
    private(set) var requestedPeriods: [ProjectPeriod] = []

    init(provider: UsageProvider, snapshots: [ProviderProjectSnapshot]) {
        self.provider = provider
        self.snapshots = snapshots
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        requestedPeriods.append(period)
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots.first ?? ProviderProjectSnapshot(
            provider: provider,
            entries: [],
            availability: .available
        )
    }
}

private final class MockCodexStatusRepository: CodexStatusRepositoryProtocol, @unchecked Sendable {
    private var snapshots: [CodexStatusSnapshot]
    private(set) var snapshotCalls = 0

    init(snapshots: [CodexStatusSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot() -> CodexStatusSnapshot {
        snapshotCalls += 1
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots[0]
    }
}

private final class PeriodAwareMockProjectUsageRepository: ProjectUsageRepository {
    private let provider: UsageProvider
    private let snapshotsByPeriod: [ProjectPeriod: ProviderProjectSnapshot]
    private let delay: Duration?
    private(set) var requestedPeriods: [ProjectPeriod] = []

    init(
        provider: UsageProvider,
        snapshotsByPeriod: [ProjectPeriod: ProviderProjectSnapshot],
        delay: Duration? = nil
    ) {
        self.provider = provider
        self.snapshotsByPeriod = snapshotsByPeriod
        self.delay = delay
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        requestedPeriods.append(period)
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return snapshotsByPeriod[period] ?? ProviderProjectSnapshot(
            provider: provider,
            entries: [],
            availability: .available
        )
    }
}
