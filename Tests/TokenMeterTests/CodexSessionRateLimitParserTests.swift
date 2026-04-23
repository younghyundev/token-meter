import XCTest
@testable import TokenMeter

final class CodexSessionRateLimitParserTests: XCTestCase {
    func test_returnsLatestSnapshotAcrossMultipleFiles() throws {
        let sessionsDirectory = try makeSessionsFixture(files: [
            "2026/04/22/rollout-1.jsonl": [
                #"{"timestamp":"2026-04-22T04:36:46.257Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":82.0,"window_minutes":300,"resets_at":1776841132},"secondary":{"used_percent":13.0,"window_minutes":10080,"resets_at":1777427932},"plan_type":"plus"}}}"#
            ],
            "2026/04/23/rollout-2.jsonl": [
                #"{"timestamp":"2026-04-23T07:38:32.034Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":150284}},"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1776859163},"secondary":{"used_percent":4.0,"window_minutes":10080,"resets_at":1777427932},"plan_type":"prolite"}}}"#
            ]
        ])
        let parser = CodexSessionRateLimitParser(sessionsDirectory: sessionsDirectory)

        let snapshot = parser.latestSnapshot()

        XCTAssertEqual(snapshot?.primaryUsedPercent, 12.0)
        XCTAssertEqual(snapshot?.primaryWindowMinutes, 300)
        XCTAssertEqual(snapshot?.secondaryUsedPercent, 4.0)
        XCTAssertEqual(snapshot?.secondaryWindowMinutes, 10080)
        XCTAssertEqual(snapshot?.totalTokens, 150_284)
        XCTAssertEqual(snapshot?.planType, "prolite")
        XCTAssertEqual(snapshot?.primaryResetsAt, Date(timeIntervalSince1970: 1_776_859_163))
        XCTAssertEqual(snapshot?.secondaryResetsAt, Date(timeIntervalSince1970: 1_777_427_932))
        XCTAssertEqual(snapshot?.observedAt, isoDate("2026-04-23T07:38:32.034Z"))
    }

    func test_skipsMalformedAndUnrelatedLines() throws {
        let sessionsDirectory = try makeSessionsFixture(files: [
            "rollout.jsonl": [
                "{",
                #"{"timestamp":"2026-04-23T07:38:31.119Z","type":"event_msg","payload":{"type":"agent_message","message":"ignore me"}}"#,
                #"{"timestamp":"2026-04-23T07:38:32.034Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":17,"window_minutes":300,"resets_at":1776859163},"plan_type":"prolite"}}}"#
            ]
        ])
        let parser = CodexSessionRateLimitParser(sessionsDirectory: sessionsDirectory)

        let snapshot = parser.latestSnapshot()

        XCTAssertEqual(snapshot?.primaryUsedPercent, 17)
        XCTAssertEqual(snapshot?.primaryWindowMinutes, 300)
        XCTAssertEqual(snapshot?.planType, "prolite")
    }

    func test_returnsNilWhenNoValidTokenCountExists() throws {
        let sessionsDirectory = try makeSessionsFixture(files: [
            "rollout.jsonl": [
                #"{"timestamp":"2026-04-23T07:38:31.119Z","type":"event_msg","payload":{"type":"agent_message","message":"ignore me"}}"#
            ]
        ])
        let parser = CodexSessionRateLimitParser(sessionsDirectory: sessionsDirectory)

        XCTAssertNil(parser.latestSnapshot())
    }

    private func makeSessionsFixture(files: [String: [String]]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for (relativePath, lines) in files {
            let fileURL = root.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return root
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
