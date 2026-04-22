import Foundation
import Combine
import SwiftUI

@MainActor
protocol UsageServiceProtocol: AnyObject {
    var sessionPercentage: Double { get }
    var weeklyPercentage: Double { get }
    var resetTimeRemaining: String? { get }
    var fetchState: UsageFetchState { get }
    var hasCredentials: Bool { get }
    var minFetchInterval: TimeInterval { get set }

    func loadCredentials()
    func fetchUsage(force: Bool) async
}

extension AnthropicUsageService: UsageServiceProtocol {}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var lastRefreshed: Date = .now
    @Published var refreshInterval: Int = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 60 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    let usageService: any UsageServiceProtocol
    private let projectUsageRepository: any ProjectUsageRepository
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var projectRefreshTask: Task<Void, Never>?
    private var started = false

    @Published private(set) var projects: [ProjectUsage] = []
    @Published var projectPeriod: ProjectPeriod = .day {
        didSet { loadProjects() }
    }

    init(
        usageService: (any UsageServiceProtocol)? = nil,
        projectUsageRepository: (any ProjectUsageRepository)? = nil
    ) {
        self.usageService = usageService ?? AnthropicUsageService()
        self.projectUsageRepository = projectUsageRepository ?? ClaudeProjectUsageRepository()
    }

    // MARK: - Computed from API

    var sessionPercentage: Double {
        usageService.sessionPercentage
    }

    var remainingPercentage: Double {
        max(0, 100 - sessionPercentage)
    }

    var weeklyPercentage: Double {
        usageService.weeklyPercentage
    }

    var resetTimeRemaining: String? {
        usageService.resetTimeRemaining
    }

    var fetchState: UsageFetchState {
        usageService.fetchState
    }

    var hasCredentials: Bool {
        usageService.hasCredentials
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        usageService.loadCredentials()
        syncFetchInterval()
        Task { await refresh() }
        scheduleTimer()

        cancellable = $refreshInterval
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.syncFetchInterval()
                self?.scheduleTimer()
            }
    }

    private func syncFetchInterval() {
        usageService.minFetchInterval = TimeInterval(max(refreshInterval - 5, 55))
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancellable?.cancel()
        projectRefreshTask?.cancel()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(refreshInterval, 10))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        await usageService.fetchUsage(force: false)
        await refreshProjects()
        lastRefreshed = .now
    }

    func forceRefresh() async {
        await usageService.fetchUsage(force: true)
        await refreshProjects()
        lastRefreshed = .now
    }

    // MARK: - Project Breakdown

    func loadProjects() {
        projectRefreshTask?.cancel()
        projectRefreshTask = Task { [weak self] in
            await self?.refreshProjects()
        }
    }

    private func refreshProjects() async {
        let snapshot = await projectUsageRepository.projectUsage(for: projectPeriod)
        guard !Task.isCancelled else { return }

        switch ProjectUsageAggregation.projectUsage(from: snapshot) {
        case let .available(projects):
            self.projects = projects
        case .unavailable:
            projects = []
        }
    }
}

private struct ClaudeProjectUsageRepository: ProjectUsageRepository, Sendable {
    private let parser: TokenParser

    init(parser: TokenParser = TokenParser()) {
        self.parser = parser
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        let parser = parser
        let entries = await Task.detached {
            parser.parseAll()
        }.value

        return ProviderProjectSnapshot(
            provider: .claude,
            entries: filter(entries, for: period),
            availability: .available
        )
    }

    private func filter(_ entries: [TokenUsageEntry], for period: ProjectPeriod) -> [TokenUsageEntry] {
        switch period {
        case .day:
            let cutoff = Date.now.addingTimeInterval(-24 * 3600)
            return entries.filter { $0.timestamp >= cutoff }
        case .week:
            let cutoff = Date.now.addingTimeInterval(-7 * 24 * 3600)
            return entries.filter { $0.timestamp >= cutoff }
        case .all:
            return entries
        }
    }
}
