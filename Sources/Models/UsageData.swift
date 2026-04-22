import Foundation

enum ProjectPeriod: String, CaseIterable {
    case day, week, all
}

enum UsageProvider {
    case claude
    case codex
}

enum ProviderAvailability: Equatable {
    case available
    case unavailable(String)
}

struct TokenUsageEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sessionId: String
    let projectPath: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var billableTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens
    }
}

struct ProviderProjectSnapshot {
    let provider: UsageProvider
    let entries: [TokenUsageEntry]
    let availability: ProviderAvailability
}

struct ProjectUsage: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
    let totalTokens: Int
    let billableTokens: Int
    let percentage: Double

    static func == (lhs: ProjectUsage, rhs: ProjectUsage) -> Bool {
        lhs.name == rhs.name
            && lhs.displayName == rhs.displayName
            && lhs.totalTokens == rhs.totalTokens
            && lhs.billableTokens == rhs.billableTokens
            && abs(lhs.percentage - rhs.percentage) < 0.0001
    }
}
