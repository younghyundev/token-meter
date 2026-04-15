import Foundation
import Combine
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var lastRefreshed: Date = .now
    @Published var refreshInterval: Int = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 60 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    let usageService = AnthropicUsageService()
    private let projectParser = TokenParser()
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var started = false

    /// Cached parsed entries — only re-parsed on refresh, not on period change
    private var cachedEntries: [TokenUsageEntry] = []

    @Published private(set) var projects: [ProjectUsage] = []
    @Published var projectPeriod: ProjectPeriod = .day {
        didSet { rebuildProjects() }
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
        // Fetch API usage (network, already async)
        await usageService.fetchUsage()

        // Parse JSONL in background
        let parser = projectParser
        let entries = await Task.detached {
            parser.parseAll()
        }.value

        cachedEntries = entries
        rebuildProjects()
        lastRefreshed = .now
    }

    func forceRefresh() async {
        await usageService.fetchUsage(force: true)

        let parser = projectParser
        let entries = await Task.detached {
            parser.parseAll()
        }.value

        cachedEntries = entries
        rebuildProjects()
        lastRefreshed = .now
    }

    // MARK: - Project Breakdown

    func loadProjects() {
        rebuildProjects()
    }

    private func rebuildProjects() {
        let filtered: [TokenUsageEntry]
        switch projectPeriod {
        case .day:
            let cutoff = Date.now.addingTimeInterval(-24 * 3600)
            filtered = cachedEntries.filter { $0.timestamp >= cutoff }
        case .week:
            let cutoff = Date.now.addingTimeInterval(-7 * 24 * 3600)
            filtered = cachedEntries.filter { $0.timestamp >= cutoff }
        case .all:
            filtered = cachedEntries
        }

        let grouped = Dictionary(grouping: filtered, by: \.projectPath)
        let totalTokens = max(filtered.reduce(0) { $0 + $1.totalTokens }, 1)

        projects = grouped.map { path, items in
            let total = items.reduce(0) { $0 + $1.totalTokens }
            let billable = items.reduce(0) { $0 + $1.billableTokens }
            return ProjectUsage(
                name: path,
                displayName: Self.humanizeProjectPath(path),
                totalTokens: total,
                billableTokens: billable,
                percentage: Double(total) / Double(totalTokens) * 100
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }
    }

    private static func humanizeProjectPath(_ path: String) -> String {
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        return lastComponent.isEmpty ? path : lastComponent
    }
}
