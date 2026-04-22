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

        await viewModel.forceRefresh()

        XCTAssertEqual(viewModel.selectedProvider, .codex)
        XCTAssertEqual(usageService.fetchInvocations, [.forced])
        XCTAssertTrue(claudeRepository.requestedPeriods.isEmpty)
        XCTAssertEqual(codexRepository.requestedPeriods, [.day])
        XCTAssertEqual(codexStatusRepository.snapshotCalls, 1)
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

private final class MockCodexStatusRepository: CodexStatusRepositoryProtocol {
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
