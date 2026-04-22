import Foundation

protocol ProjectUsageRepository {
    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot
}

enum ProjectUsageRepositoryResult: Equatable {
    case available([ProjectUsage])
    case unavailable(String)
}

enum ProjectUsageAggregation {
    static func projectUsage(from snapshot: ProviderProjectSnapshot) -> ProjectUsageRepositoryResult {
        switch snapshot.availability {
        case .available:
            let grouped = Dictionary(grouping: snapshot.entries, by: \.projectPath)
            let totalTokens = max(snapshot.entries.reduce(0) { $0 + $1.totalTokens }, 1)

            let projects = grouped.map { path, items in
                let total = items.reduce(0) { $0 + $1.totalTokens }
                let billable = items.reduce(0) { $0 + $1.billableTokens }
                return ProjectUsage(
                    name: path,
                    displayName: humanizeProjectPath(path),
                    totalTokens: total,
                    billableTokens: billable,
                    percentage: Double(total) / Double(totalTokens) * 100
                )
            }
            .sorted { $0.totalTokens > $1.totalTokens }

            return .available(projects)
        case let .unavailable(message):
            return .unavailable(message)
        }
    }

    private static func humanizeProjectPath(_ path: String) -> String {
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        return lastComponent.isEmpty ? path : lastComponent
    }
}
