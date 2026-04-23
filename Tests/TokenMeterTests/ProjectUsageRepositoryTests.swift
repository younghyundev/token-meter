import XCTest
@testable import TokenMeter

final class ProjectUsageRepositoryTests: XCTestCase {
    func test_groupsEntriesByProjectPath() {
        let snapshot = ProviderProjectSnapshot(
            provider: .codex,
            entries: [
                makeEntry(projectPath: "/tmp/alpha", inputTokens: 20, outputTokens: 5),
                makeEntry(projectPath: "/tmp/alpha", inputTokens: 3, outputTokens: 2),
                makeEntry(projectPath: "/tmp/beta", inputTokens: 1, outputTokens: 1)
            ],
            availability: .available
        )
        let result = ProjectUsageAggregation.projectUsage(from: snapshot)

        guard case let .available(projects) = result else {
            return XCTFail("Expected available result")
        }

        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects.first?.name, "/tmp/alpha")
        XCTAssertEqual(projects.first?.totalTokens, 30)
    }

    func test_sortsProjectsByTotalTokensDescending() {
        let snapshot = ProviderProjectSnapshot(
            provider: .codex,
            entries: [
                makeEntry(projectPath: "/tmp/low", inputTokens: 2, outputTokens: 1),
                makeEntry(projectPath: "/tmp/high", inputTokens: 10, outputTokens: 5),
                makeEntry(projectPath: "/tmp/mid", inputTokens: 3, outputTokens: 4)
            ],
            availability: .available
        )
        let result = ProjectUsageAggregation.projectUsage(from: snapshot)

        guard case let .available(projects) = result else {
            return XCTFail("Expected available result")
        }

        XCTAssertEqual(projects.map(\.name), ["/tmp/high", "/tmp/mid", "/tmp/low"])
        XCTAssertEqual(projects.map(\.totalTokens), [15, 7, 3])
        XCTAssertEqual(projects.first?.percentage ?? 0, 60, accuracy: 0.001)
    }

    func test_propagatesUnavailableState() {
        let snapshot = ProviderProjectSnapshot(
            provider: .codex,
            entries: [makeEntry(projectPath: "/tmp/ignored", inputTokens: 1, outputTokens: 1)],
            availability: .unavailable("Codex data missing")
        )
        let result = ProjectUsageAggregation.projectUsage(from: snapshot)

        XCTAssertEqual(result, .unavailable("Codex data missing"))
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
