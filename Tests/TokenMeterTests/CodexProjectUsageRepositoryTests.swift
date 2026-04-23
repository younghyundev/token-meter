import XCTest
import SQLite3
@testable import TokenMeter

final class CodexProjectUsageRepositoryTests: XCTestCase {
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func test_buildsProjectRowsFromSQLiteTotals() async throws {
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(cwd: "/tmp/workspaces/alpha", rolloutPath: "/tmp/rollouts/alpha.jsonl", tokensUsed: 20, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/rollouts/beta.jsonl", rolloutPath: "/tmp/rollouts/beta.jsonl", tokensUsed: 7, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/workspaces/gamma", rolloutPath: nil, tokensUsed: 3, archived: 0, modelProvider: "openai")
        ])
        let sessionsDirectory = try makeSessionsDirectory(
            relativePath: "2026/04/22/rollout-alpha.jsonl",
            contents: """
            {"payload":{"rollout_path":"/tmp/rollouts/alpha.jsonl","cwd":"/tmp/workspaces/alpha","session_id":"session-a"},"timestamp":"2026-04-22T07:00:00.000Z"}
            {"payload":{"rollout_path":"/tmp/rollouts/beta.jsonl","cwd":"/tmp/workspaces/beta","session_id":"session-b"},"timestamp":"2026-04-22T08:00:00.000Z"}
            """
        )
        let authURL = try makeAuthFixture(valid: true)
        let repository = CodexProjectUsageRepository(
            sqliteRepository: CodexSQLiteRepository(databaseURL: databaseURL, now: { .distantPast }),
            rolloutParser: CodexRolloutParser(sessionsDirectory: sessionsDirectory),
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertEqual(snapshot.availability, .available)
        XCTAssertEqual(snapshot.entries.map(\.projectPath), [
            "/tmp/workspaces/alpha",
            "/tmp/workspaces/beta",
            "/tmp/workspaces/gamma"
        ])
        XCTAssertEqual(snapshot.entries.map(\.totalTokens), [20, 7, 3])

        let aggregated = ProjectUsageAggregation.projectUsage(from: snapshot)
        guard case let .available(projects) = aggregated else {
            return XCTFail("Expected available project usage")
        }

        XCTAssertEqual(projects.map(\.displayName), ["alpha", "beta", "gamma"])
        XCTAssertEqual(projects.map(\.totalTokens), [20, 7, 3])
    }

    func test_returnsLoginRequiredWhenAuthIsMissing() async throws {
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(cwd: "/tmp/workspaces/alpha", rolloutPath: nil, tokensUsed: 5, archived: 0, modelProvider: "openai")
        ])
        let missingAuthURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let repository = CodexProjectUsageRepository(
            sqliteRepository: CodexSQLiteRepository(databaseURL: databaseURL),
            rolloutParser: CodexRolloutParser(sessionsDirectory: FileManager.default.temporaryDirectory),
            authStateProbe: CodexAuthStateProbe(authURL: missingAuthURL)
        )

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertEqual(snapshot.availability, .loginRequired)
    }

    func test_returnsAvailableWithEmptyEntriesWhenAuthenticatedRangeHasNoRows() async throws {
        let databaseURL = try makeSQLiteFixture(rows: [])
        let authURL = try makeAuthFixture(valid: true)
        let repository = CodexProjectUsageRepository(
            sqliteRepository: CodexSQLiteRepository(databaseURL: databaseURL),
            rolloutParser: CodexRolloutParser(sessionsDirectory: FileManager.default.temporaryDirectory),
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        let snapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertEqual(snapshot.availability, .available)
    }

    func test_preservesDisplayNameNormalizationAndDescendingTokenSorting() async throws {
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(cwd: "/tmp/workspaces/charlie", rolloutPath: nil, tokensUsed: 4, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/workspaces/alpha", rolloutPath: nil, tokensUsed: 12, archived: 0, modelProvider: "openai"),
            .init(cwd: "/tmp/workspaces/bravo", rolloutPath: nil, tokensUsed: 8, archived: 0, modelProvider: "openai")
        ])
        let authURL = try makeAuthFixture(valid: true)
        let repository = CodexProjectUsageRepository(
            sqliteRepository: CodexSQLiteRepository(databaseURL: databaseURL),
            rolloutParser: CodexRolloutParser(sessionsDirectory: FileManager.default.temporaryDirectory),
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        let snapshot = await repository.projectUsage(for: .all)
        let aggregated = ProjectUsageAggregation.projectUsage(from: snapshot)

        guard case let .available(projects) = aggregated else {
            return XCTFail("Expected available project usage")
        }

        XCTAssertEqual(projects.map(\.displayName), ["alpha", "bravo", "charlie"])
        XCTAssertEqual(projects.map(\.totalTokens), [12, 8, 4])
    }

    func test_appliesPeriodFilteringFromSQLiteUpdatedAt() async throws {
        let referenceNow = Date(timeIntervalSince1970: 1_776_904_700)
        let databaseURL = try makeSQLiteFixture(rows: [
            .init(cwd: "/tmp/workspaces/day", rolloutPath: nil, tokensUsed: 10, archived: 0, modelProvider: "openai", updatedAt: Int64(referenceNow.timeIntervalSince1970 - 3600)),
            .init(cwd: "/tmp/workspaces/week", rolloutPath: nil, tokensUsed: 20, archived: 0, modelProvider: "openai", updatedAt: Int64(referenceNow.timeIntervalSince1970 - (3 * 24 * 3600))),
            .init(cwd: "/tmp/workspaces/all", rolloutPath: nil, tokensUsed: 30, archived: 0, modelProvider: "openai", updatedAt: Int64(referenceNow.timeIntervalSince1970 - (10 * 24 * 3600)))
        ])
        let authURL = try makeAuthFixture(valid: true)
        let repository = CodexProjectUsageRepository(
            sqliteRepository: CodexSQLiteRepository(databaseURL: databaseURL, now: { referenceNow }),
            rolloutParser: CodexRolloutParser(sessionsDirectory: FileManager.default.temporaryDirectory),
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        let daySnapshot = await repository.projectUsage(for: .day)
        let weekSnapshot = await repository.projectUsage(for: .week)
        let allSnapshot = await repository.projectUsage(for: .all)

        XCTAssertEqual(daySnapshot.entries.map(\.projectPath), ["/tmp/workspaces/day"])
        XCTAssertEqual(Set(weekSnapshot.entries.map(\.projectPath)), Set(["/tmp/workspaces/day", "/tmp/workspaces/week"]))
        XCTAssertEqual(Set(allSnapshot.entries.map(\.projectPath)), Set(["/tmp/workspaces/day", "/tmp/workspaces/week", "/tmp/workspaces/all"]))
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
                "CREATE TABLE threads (cwd TEXT, rollout_path TEXT, tokens_used INTEGER, archived INTEGER, model_provider TEXT, updated_at INTEGER);",
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        for row in rows {
            let sql = "INSERT INTO threads (cwd, rollout_path, tokens_used, archived, model_provider, updated_at) VALUES (?, ?, ?, ?, ?, ?);"
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
            guard let statement else {
                throw FixtureError.failedToPrepare
            }

            sqlite3_bind_text(statement, 1, row.cwd, -1, sqliteTransient)
            if let rolloutPath = row.rolloutPath {
                sqlite3_bind_text(statement, 2, rolloutPath, -1, sqliteTransient)
            } else {
                sqlite3_bind_null(statement, 2)
            }
            sqlite3_bind_int64(statement, 3, sqlite3_int64(row.tokensUsed))
            sqlite3_bind_int(statement, 4, Int32(row.archived))
            sqlite3_bind_text(statement, 5, row.modelProvider, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 6, sqlite3_int64(row.updatedAt))
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }

        return fileURL
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

    private func makeAuthFixture(valid: Bool) throws -> URL {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let contents = valid
            ? """
            {
              "tokens": {
                "opaque": "secret-value"
              }
            }
            """
            : "{"
        try contents.write(to: authURL, atomically: true, encoding: .utf8)
        return authURL
    }

    private struct FixtureRow {
        let cwd: String
        let rolloutPath: String?
        let tokensUsed: Int
        let archived: Int
        let modelProvider: String
        let updatedAt: Int64

        init(
            cwd: String,
            rolloutPath: String?,
            tokensUsed: Int,
            archived: Int,
            modelProvider: String,
            updatedAt: Int64 = 1_776_904_700
        ) {
            self.cwd = cwd
            self.rolloutPath = rolloutPath
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
