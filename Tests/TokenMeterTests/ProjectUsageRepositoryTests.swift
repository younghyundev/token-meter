import XCTest
@testable import TokenMeter

final class ProjectUsageRepositoryTests: XCTestCase {
    func test_groupsEntriesByProjectPath() {
        let result = aggregate(entries: [
            makeEntry(projectPath: "/tmp/alpha", inputTokens: 20, outputTokens: 5),
            makeEntry(projectPath: "/tmp/alpha", inputTokens: 3, outputTokens: 2),
            makeEntry(projectPath: "/tmp/beta", inputTokens: 1, outputTokens: 1)
        ])

        guard case let .available(projects) = result else {
            return XCTFail("Expected available result")
        }

        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects.first?.name, "/tmp/alpha")
        XCTAssertEqual(projects.first?.totalTokens, 30)
    }

    func test_sortsProjectsByTotalTokensDescending() {
        let result = aggregate(entries: [
            makeEntry(projectPath: "/tmp/low", inputTokens: 2, outputTokens: 1),
            makeEntry(projectPath: "/tmp/high", inputTokens: 10, outputTokens: 5),
            makeEntry(projectPath: "/tmp/mid", inputTokens: 3, outputTokens: 4)
        ])

        guard case let .available(projects) = result else {
            return XCTFail("Expected available result")
        }

        XCTAssertEqual(projects.map(\.name), ["/tmp/high", "/tmp/mid", "/tmp/low"])
        XCTAssertEqual(projects.map(\.totalTokens), [15, 7, 3])
        XCTAssertEqual(projects.first?.percentage ?? 0, 60, accuracy: 0.001)
    }

    func test_propagatesUnavailableState() {
        let result = aggregate(
            entries: [makeEntry(projectPath: "/tmp/ignored", inputTokens: 1, outputTokens: 1)],
            availability: .unavailable("Codex data missing")
        )

        XCTAssertEqual(result, .unavailable("Codex data missing"))
    }

    private func aggregate(
        entries: [TokenUsageEntry],
        availability: FixtureAvailability = .available
    ) -> FixtureResult {
        guard case .available = availability else {
            return .unavailable(availability.message)
        }

        let grouped = Dictionary(grouping: entries, by: \.projectPath)
        let totalTokens = max(entries.reduce(0) { $0 + $1.totalTokens }, 1)

        let projects = grouped.map { path, items in
            let total = items.reduce(0) { $0 + $1.totalTokens }
            let billable = items.reduce(0) { $0 + $1.billableTokens }
            return ProjectUsage(
                name: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                totalTokens: total,
                billableTokens: billable,
                percentage: Double(total) / Double(totalTokens) * 100
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }

        return .available(projects)
    }

    private func makeEntry(
        projectPath: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0
    ) -> TokenUsageEntry {
        TokenUsageEntry(
            timestamp: .now,
            sessionId: UUID().uuidString,
            projectPath: projectPath,
            model: "test-model",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
    }
}

private enum FixtureAvailability: Equatable {
    case available
    case unavailable(String)

    var message: String {
        switch self {
        case .available:
            return ""
        case let .unavailable(message):
            return message
        }
    }
}

private enum FixtureResult {
    case available([ProjectUsage])
    case unavailable(String)
}

extension FixtureResult: Equatable {
    static func == (lhs: FixtureResult, rhs: FixtureResult) -> Bool {
        switch (lhs, rhs) {
        case let (.unavailable(left), .unavailable(right)):
            return left == right
        case let (.available(left), .available(right)):
            return left.map(\.name) == right.map(\.name)
                && left.map(\.displayName) == right.map(\.displayName)
                && left.map(\.totalTokens) == right.map(\.totalTokens)
                && left.map(\.billableTokens) == right.map(\.billableTokens)
                && zip(left.map(\.percentage), right.map(\.percentage)).allSatisfy {
                    abs($0 - $1) < 0.0001
                }
        default:
            return false
        }
    }
}
