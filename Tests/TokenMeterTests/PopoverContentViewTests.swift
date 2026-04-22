import XCTest
@testable import TokenMeter

@MainActor
final class PopoverContentViewTests: XCTestCase {
    func test_usageViewModelDefaultsToClaudeProvider() {
        let viewModel = UsageViewModel(
            usageService: PopoverMockUsageService(),
            claudeProjectRepository: PopoverMockProjectUsageRepository(provider: .claude, snapshot: makeSnapshot(provider: .claude)),
            codexProjectRepository: PopoverMockProjectUsageRepository(provider: .codex, snapshot: makeSnapshot(provider: .codex)),
            codexStatusRepository: PopoverMockCodexStatusRepository(snapshot: .loginRequired)
        )

        XCTAssertEqual(viewModel.selectedProvider, .claude)
        XCTAssertEqual(viewModel.currentProjectPeriod(for: .claude), .day)
    }

    func test_codexPopoverStringsResolveInEnglish() {
        LocalizationManager.shared.language = .english

        XCTAssertEqual(L("provider.codex"), "Codex")
        XCTAssertEqual(L("footer.refresh.codex"), "Refresh Codex")
        XCTAssertEqual(L("codex.login.title"), "Codex login required")
        XCTAssertEqual(L("codex.unavailable.title"), "Codex unavailable")
    }

    private func makeSnapshot(provider: UsageProvider) -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(provider: provider, entries: [], availability: .available)
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
    private let snapshot: ProviderProjectSnapshot

    init(provider: UsageProvider, snapshot: ProviderProjectSnapshot) {
        self.provider = provider
        self.snapshot = snapshot
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        _ = provider
        _ = period
        return snapshot
    }
}

private final class PopoverMockCodexStatusRepository: CodexStatusRepositoryProtocol {
    private let snapshotValue: CodexStatusSnapshot

    init(snapshot: CodexStatusSnapshot) {
        self.snapshotValue = snapshot
    }

    func snapshot() -> CodexStatusSnapshot {
        snapshotValue
    }
}
