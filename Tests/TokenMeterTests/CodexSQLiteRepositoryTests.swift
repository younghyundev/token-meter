import XCTest
import SQLite3
@testable import TokenMeter

final class CodexSQLiteRepositoryTests: XCTestCase {
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func test_groupsThreadsByCWD() async throws {
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(cwd: "/tmp/alpha", tokensUsed: 20, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/alpha", tokensUsed: 5, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/beta", tokensUsed: 4, archived: 0, modelProvider: "openai"),
            .init(cwd: "", tokensUsed: 99, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/ignored", tokensUsed: 500, archived: 1, modelProvider: "openai"),
            .init(cwd: "/tmp/ignored-provider", tokensUsed: 100, archived: 0, modelProvider: "anthropic"),
        ])
        let repository = CodexSQLiteRepository(databaseURL: databaseURL, logsDatabaseURL: missingLogsURL(), now: { .distantPast })

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(snapshot.availability, .available)
        XCTAssertEqual(snapshot.entries.map(\.projectPath), ["/tmp/alpha", "/tmp/beta"])
        XCTAssertEqual(snapshot.entries.map(\.totalTokens), [25, 4])
        XCTAssertEqual(snapshot.entries.map(\.timestamp), [.distantPast, .distantPast])
    }

    func test_returnsUnavailableForMissingDatabase() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.sqlite")
        let repository = CodexSQLiteRepository(databaseURL: missingURL, logsDatabaseURL: missingLogsURL())

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertEqual(snapshot.availability, .unavailable("Codex usage database is missing at \(missingURL.path)."))
    }

    func test_returnsSQLiteErrorWhenThreadsQueryCannotBePrepared() async throws {
        let databaseURL = try makeSQLiteFixtureWithoutThreadsTable()
        let repository = CodexSQLiteRepository(databaseURL: databaseURL, logsDatabaseURL: missingLogsURL())

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertTrue(snapshot.entries.isEmpty)
        guard case let .unavailable(message) = snapshot.availability else {
            return XCTFail("Expected unavailable snapshot")
        }
        XCTAssertTrue(message.contains("Codex SQLite query failed"), message)
        XCTAssertTrue(message.contains("no such table: threads"), message)
    }

    func test_usesTurnLogsForPeriodSpecificCodexUsageWhenAvailable() async throws {
        let referenceNow = Date(timeIntervalSince1970: 1_776_904_700)
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(id: "thread-day", cwd: "/tmp/day", tokensUsed: 999, archived: 0, modelProvider: "openai"),
            .init(id: "thread-week", cwd: "/tmp/week", tokensUsed: 999, archived: 0, modelProvider: "openai"),
            .init(id: "thread-all", cwd: "/tmp/all", tokensUsed: 999, archived: 0, modelProvider: "openai")
        ])
        let logsURL = try makeLogsFixture(rows: [
            .init(threadId: "thread-day", turnId: "turn-day", tokens: 10, timestamp: Int64(referenceNow.timeIntervalSince1970 - 3600)),
            .init(threadId: "thread-day", turnId: "turn-day", tokens: 12, timestamp: Int64(referenceNow.timeIntervalSince1970 - 3500)),
            .init(threadId: "thread-week", turnId: "turn-week", tokens: 20, timestamp: Int64(referenceNow.timeIntervalSince1970 - (3 * 24 * 3600))),
            .init(threadId: "thread-all", turnId: "turn-all", tokens: 30, timestamp: Int64(referenceNow.timeIntervalSince1970 - (10 * 24 * 3600)))
        ])
        let repository = CodexSQLiteRepository(
            databaseURL: databaseURL,
            logsDatabaseURL: logsURL,
            now: { referenceNow }
        )

        let daySnapshot = await repository.projectUsage(for: .day)
        let weekSnapshot = await repository.projectUsage(for: .week)
        let allSnapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(daySnapshot.entries.map(\.projectPath), ["/tmp/day"])
        XCTAssertEqual(daySnapshot.entries.map(\.totalTokens), [12])
        XCTAssertEqual(Set(weekSnapshot.entries.map(\.projectPath)), Set(["/tmp/day", "/tmp/week"]))
        XCTAssertEqual(weekSnapshot.entries.reduce(0) { $0 + $1.totalTokens }, 32)
        XCTAssertEqual(Set(allSnapshot.entries.map(\.projectPath)), Set(["/tmp/day", "/tmp/week", "/tmp/all"]))
        XCTAssertEqual(allSnapshot.entries.reduce(0) { $0 + $1.totalTokens }, 62)
    }

    func test_authProbeReturnsAvailableWithoutTokens() throws {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "tokens": {
            "opaque": "secret-value"
          },
          "account_id": "acct_123"
        }
        """.write(to: authURL, atomically: true, encoding: .utf8)

        let probe = CodexAuthStateProbe(authURL: authURL)

        XCTAssertEqual(probe.probe(), .available)
    }

    func test_authProbeReturnsMalformedForInvalidJSON() throws {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "{".write(to: authURL, atomically: true, encoding: .utf8)

        let probe = CodexAuthStateProbe(authURL: authURL)

        XCTAssertEqual(probe.probe(), .malformed)
    }

    private func makeSQLiteFixture(rows: [FixtureRow]) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("state_5.sqlite")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(fileURL.path, &database), SQLITE_OK)
        guard let database else {
            throw FixtureError.failedToOpen
        }
        defer { sqlite3_close(database) }

        XCTAssertEqual(
            sqlite3_exec(
                database,
                "CREATE TABLE threads (id TEXT, cwd TEXT, tokens_used INTEGER, archived INTEGER, model_provider TEXT, updated_at INTEGER);",
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        for row in rows {
            let sql = "INSERT INTO threads (id, cwd, tokens_used, archived, model_provider, updated_at) VALUES (?, ?, ?, ?, ?, ?);"
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
            guard let statement else {
                throw FixtureError.failedToPrepare
            }

            sqlite3_bind_text(statement, 1, row.id, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, row.cwd, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 3, sqlite3_int64(row.tokensUsed))
            sqlite3_bind_int(statement, 4, Int32(row.archived))
            sqlite3_bind_text(statement, 5, row.modelProvider, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 6, sqlite3_int64(row.updatedAt))
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }

        return fileURL
    }

    private func makeSQLiteFixtureWithoutThreadsTable() throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("state_5.sqlite")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(fileURL.path, &database), SQLITE_OK)
        guard let database else {
            throw FixtureError.failedToOpen
        }
        defer { sqlite3_close(database) }

        XCTAssertEqual(
            sqlite3_exec(database, "CREATE TABLE unrelated (id INTEGER);", nil, nil, nil),
            SQLITE_OK
        )

        return fileURL
    }

    private func makeLogsFixture(rows: [LogFixtureRow]) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("logs_2.sqlite")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(fileURL.path, &database), SQLITE_OK)
        guard let database else {
            throw FixtureError.failedToOpen
        }
        defer { sqlite3_close(database) }

        XCTAssertEqual(
            sqlite3_exec(
                database,
                "CREATE TABLE logs (ts INTEGER, target TEXT, thread_id TEXT, feedback_log_body TEXT);",
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        for row in rows {
            let sql = "INSERT INTO logs (ts, target, thread_id, feedback_log_body) VALUES (?, ?, ?, ?);"
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
            guard let statement else {
                throw FixtureError.failedToPrepare
            }

            let body = "post sampling token usage turn_id=\(row.turnId) total_usage_tokens=\(row.tokens) estimated_token_count=Some(1)"
            sqlite3_bind_int64(statement, 1, sqlite3_int64(row.timestamp))
            sqlite3_bind_text(statement, 2, "codex_core::session::turn", -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, row.threadId, -1, sqliteTransient)
            sqlite3_bind_text(statement, 4, body, -1, sqliteTransient)
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }

        return fileURL
    }

    private func missingLogsURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing-logs.sqlite")
    }

    private struct FixtureRow {
        let id: String
        let cwd: String
        let tokensUsed: Int
        let archived: Int
        let modelProvider: String
        let updatedAt: Int64

        init(
            id: String = UUID().uuidString,
            cwd: String,
            tokensUsed: Int,
            archived: Int,
            modelProvider: String,
            updatedAt: Int64 = 1_776_904_700
        ) {
            self.id = id
            self.cwd = cwd
            self.tokensUsed = tokensUsed
            self.archived = archived
            self.modelProvider = modelProvider
            self.updatedAt = updatedAt
        }
    }

    private struct LogFixtureRow {
        let threadId: String
        let turnId: String
        let tokens: Int
        let timestamp: Int64
    }

    private enum FixtureError: Error {
        case failedToOpen
        case failedToPrepare
    }
}
