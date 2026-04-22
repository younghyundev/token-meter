import XCTest
@testable import TokenMeter

final class CodexRolloutParserTests: XCTestCase {
    func test_extractsMetadataFromValidRolloutEvents() throws {
        let sessionsDirectory = try makeSessionsDirectory(
            relativePath: "2026/04/22/rollout-valid.jsonl",
            contents: """
            {"payload":{"rollout_path":"/tmp/rollouts/a","cwd":"/tmp/workspaces/alpha","session_id":"session-a"},"timestamp":"2026-04-22T07:00:00.000Z"}
            {"cwd":"/tmp/workspaces/beta","sessionId":"session-b","timestamp":"2026-04-22T08:00:00Z"}
            """
        )
        let parser = CodexRolloutParser(sessionsDirectory: sessionsDirectory)

        let metadata = parser.parseAll()

        XCTAssertEqual(metadata.count, 2)
        XCTAssertEqual(metadata[0].rolloutPath, "/tmp/rollouts/a")
        XCTAssertEqual(metadata[0].cwd, "/tmp/workspaces/alpha")
        XCTAssertEqual(metadata[0].sessionId, "session-a")
        XCTAssertEqual(metadata[1].cwd, "/tmp/workspaces/beta")
        XCTAssertEqual(metadata[1].sessionId, "session-b")
        XCTAssertNotNil(metadata[0].timestamp)
        XCTAssertNotNil(metadata[1].timestamp)
    }

    func test_skipsMalformedLines() throws {
        let sessionsDirectory = try makeSessionsDirectory(
            relativePath: "2026/04/22/rollout-malformed.jsonl",
            contents: """

            {
            {"payload":{"irrelevant":true}}
            {"payload":{"cwd":"/tmp/workspaces/gamma"},"timestamp":"2026-04-22T09:00:00Z"}
            """
        )
        let parser = CodexRolloutParser(sessionsDirectory: sessionsDirectory)

        let metadata = parser.parseAll()

        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata.first?.cwd, "/tmp/workspaces/gamma")
    }

    private func makeSessionsDirectory(relativePath: String, contents: String) throws -> URL {
        let sessionsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("sessions")
        let fileURL = sessionsDirectory.appendingPathComponent(relativePath)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)

        return sessionsDirectory
    }
}
