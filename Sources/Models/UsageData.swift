import Foundation

enum ProjectPeriod: String, CaseIterable {
    case day, week, all
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

struct ProjectUsage: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let totalTokens: Int
    let billableTokens: Int
    let percentage: Double
}
