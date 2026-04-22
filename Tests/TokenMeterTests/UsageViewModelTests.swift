import XCTest
@testable import TokenMeter

@MainActor
final class UsageViewModelTests: XCTestCase {
    func test_refreshUsesRepositoryOutput() async {
        let usageService = MockUsageService()
        let repository = MockProjectUsageRepository(
            snapshots: [
                ProviderProjectSnapshot(
                    provider: .codex,
                    entries: [
                        makeEntry(projectPath: "/tmp/workspaces/alpha", totalTokens: 12),
                        makeEntry(projectPath: "/tmp/workspaces/beta", totalTokens: 4)
                    ],
                    availability: .available
                )
            ]
        )
        let viewModel = UsageViewModel(
            usageService: usageService,
            projectUsageRepository: repository
        )

        await viewModel.refresh()

        XCTAssertEqual(usageService.fetchInvocations, [.nonForced])
        XCTAssertEqual(repository.requestedPeriods, [.day])
        XCTAssertEqual(viewModel.projects.map(\.displayName), ["alpha", "beta"])
        XCTAssertEqual(viewModel.projects.map(\.totalTokens), [12, 4])
    }

    func test_unavailableRepositoryResultDoesNotCrash() async {
        let usageService = MockUsageService()
        let repository = MockProjectUsageRepository(
            snapshots: [
                ProviderProjectSnapshot(
                    provider: .codex,
                    entries: [makeEntry(projectPath: "/tmp/workspaces/alpha", totalTokens: 10)],
                    availability: .available
                ),
                ProviderProjectSnapshot(
                    provider: .codex,
                    entries: [],
                    availability: .unavailable("Codex local data unavailable")
                )
            ]
        )
        let viewModel = UsageViewModel(
            usageService: usageService,
            projectUsageRepository: repository
        )

        await viewModel.refresh()
        await viewModel.forceRefresh()

        XCTAssertEqual(usageService.fetchInvocations, [.nonForced, .forced])
        XCTAssertTrue(viewModel.projects.isEmpty)
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
    private var snapshots: [ProviderProjectSnapshot]
    private(set) var requestedPeriods: [ProjectPeriod] = []

    init(snapshots: [ProviderProjectSnapshot]) {
        self.snapshots = snapshots
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        requestedPeriods.append(period)
        if snapshots.count > 1 {
            return snapshots.removeFirst()
        }
        return snapshots[0]
    }
}
