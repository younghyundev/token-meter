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

protocol CodexStatusRepositoryProtocol {
    func snapshot() -> CodexStatusSnapshot
}

extension CodexStatusRepository: CodexStatusRepositoryProtocol {}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var lastRefreshed: Date = .now
    @Published var refreshInterval: Int = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 60 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    let usageService: any UsageServiceProtocol
    private let claudeProjectRepository: any ProjectUsageRepository
    private let codexProjectRepository: any ProjectUsageRepository
    private let codexStatusRepository: any CodexStatusRepositoryProtocol
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var projectRefreshTask: Task<Void, Never>?
    private var started = false
    private var isSyncingProjectPeriod = false
    private var projectCache: [UsageProvider: [ProjectPeriod: CachedProjectState]] = [:]
    private var activeProjectRequest: ProjectRequestKey?

    @Published var selectedProvider: UsageProvider = .claude {
        didSet { syncSelectedProviderState(shouldRefreshProviderState: true) }
    }
    @Published private(set) var projects: [ProjectUsage] = []
    @Published private(set) var claudeProjects: [ProjectUsage] = []
    @Published private(set) var codexProjects: [ProjectUsage] = []
    @Published private(set) var claudeProjectAvailability: ProviderAvailability = .available
    @Published private(set) var codexProjectAvailability: ProviderAvailability = .loginRequired
    @Published private(set) var codexStatusSnapshot: CodexStatusSnapshot = .loginRequired
    @Published private(set) var isProjectLoading = false
    @Published var projectPeriod: ProjectPeriod = .day {
        didSet {
            guard !isSyncingProjectPeriod else { return }
            storeProjectPeriod(projectPeriod, for: selectedProvider)
            applyCachedProjectState(for: selectedProvider, period: projectPeriod)
            loadProjects()
        }
    }
    @Published private(set) var claudeProjectPeriod: ProjectPeriod = .day
    @Published private(set) var codexProjectPeriod: ProjectPeriod = .day

    init(
        usageService: (any UsageServiceProtocol)? = nil,
        projectUsageRepository: (any ProjectUsageRepository)? = nil,
        claudeProjectRepository: (any ProjectUsageRepository)? = nil,
        codexProjectRepository: (any ProjectUsageRepository)? = nil,
        codexStatusRepository: (any CodexStatusRepositoryProtocol)? = nil
    ) {
        self.usageService = usageService ?? AnthropicUsageService()
        self.claudeProjectRepository = claudeProjectRepository ?? projectUsageRepository ?? ClaudeProjectUsageRepository()
        self.codexProjectRepository = codexProjectRepository ?? CodexProjectUsageRepository()
        self.codexStatusRepository = codexStatusRepository ?? CodexStatusRepository()
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

    var codexSessionPercentage: Double? {
        guard case let .usageMetric(primaryPercentage, _, _) = codexStatusSnapshot else {
            return nil
        }
        return primaryPercentage
    }

    var codexWeeklyPercentage: Double? {
        guard case let .usageMetric(_, secondaryPercentage, _) = codexStatusSnapshot else {
            return nil
        }
        return secondaryPercentage
    }

    var menuBarPercentage: Double {
        switch selectedProvider {
        case .claude:
            return sessionPercentage
        case .codex:
            return codexSessionPercentage ?? 0
        }
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
        if selectedProvider == .claude {
            await usageService.fetchUsage(force: false)
        }
        await refreshProviderState(for: selectedProvider)
        lastRefreshed = .now
    }

    func forceRefresh() async {
        if selectedProvider == .claude {
            await usageService.fetchUsage(force: true)
        }
        await refreshProviderState(for: selectedProvider)
        lastRefreshed = .now
    }

    // MARK: - Project Breakdown

    func loadProjects() {
        loadProjects(for: selectedProvider)
    }

    func loadProjects(for provider: UsageProvider) {
        projectRefreshTask?.cancel()
        let period = currentProjectPeriod(for: provider)
        beginProjectRequest(for: provider, period: period)
        projectRefreshTask = Task { [weak self] in
            await self?.refreshProjectState(for: provider, period: period)
        }
    }

    private func loadProviderState(for provider: UsageProvider) {
        projectRefreshTask?.cancel()
        let period = currentProjectPeriod(for: provider)
        beginProjectRequest(for: provider, period: period)
        projectRefreshTask = Task { [weak self] in
            await self?.refreshProviderState(for: provider, period: period)
        }
    }

    func currentProjectPeriod(for provider: UsageProvider) -> ProjectPeriod {
        switch provider {
        case .claude:
            claudeProjectPeriod
        case .codex:
            codexProjectPeriod
        }
    }

    func setProjectPeriod(_ period: ProjectPeriod, for provider: UsageProvider) {
        if provider == selectedProvider {
            projectPeriod = period
        } else {
            storeProjectPeriod(period, for: provider)
        }
    }

    func displayProjects(for provider: UsageProvider) -> [ProjectUsage] {
        switch provider {
        case .claude:
            claudeProjects
        case .codex:
            codexProjects
        }
    }

    func projectAvailability(for provider: UsageProvider) -> ProviderAvailability {
        switch provider {
        case .claude:
            claudeProjectAvailability
        case .codex:
            codexProjectAvailability
        }
    }

    func projectLoading(for provider: UsageProvider) -> Bool {
        guard let activeProjectRequest else { return false }
        return isProjectLoading
            && activeProjectRequest.provider == provider
            && activeProjectRequest.period == currentProjectPeriod(for: provider)
    }

    private func refreshProviderState(for provider: UsageProvider) async {
        let period = currentProjectPeriod(for: provider)
        beginProjectRequest(for: provider, period: period)
        await refreshProviderState(for: provider, period: period)
    }

    private func refreshProviderState(for provider: UsageProvider, period: ProjectPeriod) async {
        guard !Task.isCancelled else { return }
        defer { finishProjectRequest(for: provider, period: period) }

        switch provider {
        case .claude:
            let snapshot = await claudeProjectRepository.projectUsage(for: period)
            guard !Task.isCancelled else { return }
            applyProjectSnapshot(snapshot, for: .claude, period: period)
        case .codex:
            codexStatusSnapshot = codexStatusRepository.snapshot()
            let snapshot = await codexProjectRepository.projectUsage(for: period)
            guard !Task.isCancelled else { return }
            applyProjectSnapshot(snapshot, for: .codex, period: period)
        }

        if provider == selectedProvider {
            syncSelectedProviderState()
        }
    }

    private func refreshProjectState(for provider: UsageProvider, period: ProjectPeriod) async {
        guard !Task.isCancelled else { return }
        defer { finishProjectRequest(for: provider, period: period) }

        let snapshot: ProviderProjectSnapshot

        switch provider {
        case .claude:
            snapshot = await claudeProjectRepository.projectUsage(for: period)
        case .codex:
            snapshot = await codexProjectRepository.projectUsage(for: period)
        }

        guard !Task.isCancelled else { return }
        applyProjectSnapshot(snapshot, for: provider, period: period)

        if provider == selectedProvider {
            syncSelectedProviderState()
        }
    }

    private func beginProjectRequest(for provider: UsageProvider, period: ProjectPeriod) {
        let request = ProjectRequestKey(provider: provider, period: period)
        activeProjectRequest = request
        isProjectLoading = projectCache[provider]?[period] == nil
    }

    private func finishProjectRequest(for provider: UsageProvider, period: ProjectPeriod) {
        guard activeProjectRequest == ProjectRequestKey(provider: provider, period: period) else {
            return
        }

        activeProjectRequest = nil
        isProjectLoading = false
    }

    private func applyProjectSnapshot(
        _ snapshot: ProviderProjectSnapshot,
        for provider: UsageProvider,
        period: ProjectPeriod
    ) {
        let aggregated = ProjectUsageAggregation.projectUsage(from: snapshot)

        switch aggregated {
        case let .available(projects):
            updateProjects(projects, availability: snapshot.availability, for: provider, period: period)
        case .unavailable:
            updateProjects([], availability: snapshot.availability, for: provider, period: period)
        }
    }

    private func updateProjects(
        _ projects: [ProjectUsage],
        availability: ProviderAvailability,
        for provider: UsageProvider,
        period: ProjectPeriod
    ) {
        projectCache[provider, default: [:]][period] = CachedProjectState(
            projects: projects,
            availability: availability
        )

        guard currentProjectPeriod(for: provider) == period else { return }

        switch provider {
        case .claude:
            claudeProjects = projects
            claudeProjectAvailability = availability
        case .codex:
            codexProjects = projects
            codexProjectAvailability = availability
        }

        if provider == selectedProvider {
            self.projects = projects
        }
    }

    private func applyCachedProjectState(for provider: UsageProvider, period: ProjectPeriod) {
        guard let cachedState = projectCache[provider]?[period] else { return }

        switch provider {
        case .claude:
            claudeProjects = cachedState.projects
            claudeProjectAvailability = cachedState.availability
        case .codex:
            codexProjects = cachedState.projects
            codexProjectAvailability = cachedState.availability
        }

        if provider == selectedProvider {
            projects = cachedState.projects
        }
    }

    private func storeProjectPeriod(_ period: ProjectPeriod, for provider: UsageProvider) {
        switch provider {
        case .claude:
            claudeProjectPeriod = period
        case .codex:
            codexProjectPeriod = period
        }
    }

    private func syncSelectedProviderState(shouldRefreshProviderState: Bool = false) {
        isSyncingProjectPeriod = true
        projectPeriod = currentProjectPeriod(for: selectedProvider)
        isSyncingProjectPeriod = false
        projects = displayProjects(for: selectedProvider)

        if shouldRefreshProviderState {
            loadProviderState(for: selectedProvider)
        }
    }
}

private struct CachedProjectState {
    let projects: [ProjectUsage]
    let availability: ProviderAvailability
}

private struct ProjectRequestKey: Equatable {
    let provider: UsageProvider
    let period: ProjectPeriod
}

struct ClaudeProjectUsageRepository: ProjectUsageRepository, Sendable {
    private let parser: TokenParser
    private let now: @Sendable () -> Date

    init(
        parser: TokenParser = TokenParser(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.parser = parser
        self.now = now
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
        let referenceDate = now()

        switch period {
        case .day:
            let cutoff = referenceDate.addingTimeInterval(-24 * 3600)
            return entries.filter { $0.timestamp >= cutoff }
        case .week:
            let cutoff = referenceDate.addingTimeInterval(-7 * 24 * 3600)
            return entries.filter { $0.timestamp >= cutoff }
        case .all:
            return entries
        }
    }
}
