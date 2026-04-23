import XCTest
@testable import TokenMeter

final class ClaudeProjectUsageRepositoryTests: XCTestCase {
    func test_tokenParserReusesCacheUntilFilesChange() throws {
        let root = makeTemporaryClaudeProjectsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root
            .appendingPathComponent("sample-project")
            .appendingPathComponent("session.jsonl")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try makeJSONL(timestamp: "2026-04-20T12:00:00.000Z", cwd: "/tmp/one", tokens: 10).write(
            to: file,
            atomically: true,
            encoding: .utf8
        )

        let parser = TokenParser(claudeDir: root)
        let firstEntries = parser.parseAll()
        XCTAssertEqual(firstEntries.map(\.projectPath), ["/tmp/one"])

        let secondEntries = parser.parseAll()
        XCTAssertEqual(secondEntries.map(\.projectPath), ["/tmp/one"])

        Thread.sleep(forTimeInterval: 1.1)
        try makeJSONL(timestamp: "2026-04-20T12:05:00.000Z", cwd: "/tmp/two", tokens: 20).write(
            to: file,
            atomically: true,
            encoding: .utf8
        )

        let refreshedEntries = parser.parseAll()
        XCTAssertEqual(Set(refreshedEntries.map(\.projectPath)), Set(["/tmp/two"]))
    }

    func test_tokenParserRecursivelyReadsNestedClaudeJsonlFiles() {
        let root = makeTemporaryClaudeProjectsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let nestedFile = root
            .appendingPathComponent("sample-project")
            .appendingPathComponent("session-1")
            .appendingPathComponent("subagents")
            .appendingPathComponent("agent-1.jsonl")
        try? FileManager.default.createDirectory(
            at: nestedFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let line = """
        {"timestamp":"2026-04-20T12:00:00.000Z","sessionId":"nested","cwd":"/tmp/sample-project","message":{"model":"claude","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":2,"cache_read_input_tokens":1}}}
        """
        try? line.write(to: nestedFile, atomically: true, encoding: .utf8)

        let parser = TokenParser(claudeDir: root)
        let entries = parser.parseAll()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.projectPath, "/tmp/sample-project")
        XCTAssertEqual(entries.first?.totalTokens, 18)
    }

    func test_claudeRepositoryFiltersDifferentPeriods() async {
        let root = makeTemporaryClaudeProjectsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root
            .appendingPathComponent("sample-project")
            .appendingPathComponent("session.jsonl")
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let contents = [
            #"{"timestamp":"2026-04-23T06:00:00.000Z","sessionId":"day","cwd":"/tmp/day","message":{"model":"claude","usage":{"input_tokens":10,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"timestamp":"2026-04-20T11:00:00.000Z","sessionId":"week","cwd":"/tmp/week","message":{"model":"claude","usage":{"input_tokens":20,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#,
            #"{"timestamp":"2026-04-10T11:00:00.000Z","sessionId":"all","cwd":"/tmp/all","message":{"model":"claude","usage":{"input_tokens":30,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#
        ].joined(separator: "\n")
        try? contents.write(to: file, atomically: true, encoding: .utf8)

        let repository = ClaudeProjectUsageRepository(
            parser: TokenParser(claudeDir: root),
            now: { ISO8601DateFormatter().date(from: "2026-04-23T12:00:00Z")! }
        )

        let daySnapshot = await repository.projectUsage(for: .day)
        let weekSnapshot = await repository.projectUsage(for: .week)
        let allSnapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(daySnapshot.entries.map(\.projectPath), ["/tmp/day"])
        XCTAssertEqual(Set(weekSnapshot.entries.map(\.projectPath)), Set(["/tmp/day", "/tmp/week"]))
        XCTAssertEqual(Set(allSnapshot.entries.map(\.projectPath)), Set(["/tmp/day", "/tmp/week", "/tmp/all"]))
    }

    private func makeTemporaryClaudeProjectsRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    private func makeJSONL(timestamp: String, cwd: String, tokens: Int) -> String {
        """
        {"timestamp":"\(timestamp)","sessionId":"session","cwd":"\(cwd)","message":{"model":"claude","usage":{"input_tokens":\(tokens),"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
    }
}
