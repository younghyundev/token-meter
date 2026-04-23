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
        let repository = CodexSQLiteRepository(databaseURL: databaseURL, now: { .distantPast })

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
        let repository = CodexSQLiteRepository(databaseURL: missingURL)

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertEqual(snapshot.availability, .unavailable("Codex usage database is unavailable."))
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
                "CREATE TABLE threads (cwd TEXT, tokens_used INTEGER, archived INTEGER, model_provider TEXT, updated_at INTEGER);",
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        for row in rows {
            let sql = "INSERT INTO threads (cwd, tokens_used, archived, model_provider, updated_at) VALUES (?, ?, ?, ?, ?);"
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
            guard let statement else {
                throw FixtureError.failedToPrepare
            }

            sqlite3_bind_text(statement, 1, row.cwd, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 2, sqlite3_int64(row.tokensUsed))
            sqlite3_bind_int(statement, 3, Int32(row.archived))
            sqlite3_bind_text(statement, 4, row.modelProvider, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 5, sqlite3_int64(row.updatedAt))
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }

        return fileURL
    }

    private struct FixtureRow {
        let cwd: String
        let tokensUsed: Int
        let archived: Int
        let modelProvider: String
        let updatedAt: Int64

        init(
            cwd: String,
            tokensUsed: Int,
            archived: Int,
            modelProvider: String,
            updatedAt: Int64 = 1_776_904_700
        ) {
            self.cwd = cwd
            self.tokensUsed = tokensUsed
            self.archived = archived
            self.modelProvider = modelProvider
            self.updatedAt = updatedAt
        }
    }

    private enum FixtureError: Error {
        case failedToOpen
        case failedToPrepare
    }
}
