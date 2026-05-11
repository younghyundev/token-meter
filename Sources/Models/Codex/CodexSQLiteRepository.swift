import Foundation
import SQLite3

final class CodexSQLiteRepository: ProjectUsageRepository, Sendable {
    private let databaseURL: URL
    private let logsDatabaseURL: URL
    private let now: @Sendable () -> Date
    private let cache = CodexSQLiteSnapshotCache()

    init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/state_5.sqlite"),
        logsDatabaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/logs_2.sqlite"),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.databaseURL = databaseURL
        self.logsDatabaseURL = logsDatabaseURL
        self.now = now
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        let usesTurnLogs = FileManager.default.fileExists(atPath: logsDatabaseURL.path)
        let cacheKey = cacheKey(usesTurnLogs: usesTurnLogs)
        let snapshot = await cache.snapshot(for: cacheKey) {
            if usesTurnLogs {
                return projectUsageFromAllTurnLogs()
            }

            return projectUsageFromAllThreadRows()
        }

        return filter(snapshot, for: period)
    }

    private func projectUsageFromAllThreadRows() -> ProviderProjectSnapshot {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return unavailableSnapshot(message: "Codex usage database is missing at \(databaseURL.path).")
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { sqliteErrorMessage($0) } ?? "SQLite open failed with code \(openResult)."
            if database != nil {
                sqlite3_close(database)
            }
            return unavailableSnapshot(message: message)
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT cwd, updated_at, tokens_used
        FROM threads
        WHERE archived = 0
          AND model_provider = 'openai'
        ORDER BY updated_at DESC;
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            let message = sqliteErrorMessage(database, fallbackCode: prepareResult)
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return unavailableSnapshot(message: message)
        }
        defer { sqlite3_finalize(statement) }

        var entries: [TokenUsageEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cwdPointer = sqlite3_column_text(statement, 0) else { continue }
            let cwd = String(cString: cwdPointer).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cwd.isEmpty else { continue }

            let updatedAt = sqlite3_column_int64(statement, 1)
            let totalTokens = Int(sqlite3_column_int64(statement, 2))
            guard totalTokens > 0 else { continue }

            entries.append(
                TokenUsageEntry(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(updatedAt)),
                    sessionId: "codex-sqlite:\(cwd):\(updatedAt)",
                    projectPath: cwd,
                    model: "openai",
                    inputTokens: totalTokens,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0
                )
            )
        }

        return ProviderProjectSnapshot(
            provider: .codex,
            entries: entries,
            availability: .available
        )
    }

    private func projectUsageFromAllTurnLogs() -> ProviderProjectSnapshot {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return unavailableSnapshot(message: "Codex usage database is missing at \(databaseURL.path).")
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(logsDatabaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { sqliteErrorMessage($0) } ?? "SQLite open failed with code \(openResult)."
            if database != nil {
                sqlite3_close(database)
            }
            return unavailableSnapshot(message: message)
        }
        defer { sqlite3_close(database) }

        let attachSQL = "ATTACH DATABASE '\(sqliteLiteral(databaseURL.path))' AS state;"
        guard sqlite3_exec(database, attachSQL, nil, nil, nil) == SQLITE_OK else {
            return unavailableSnapshot(message: sqliteErrorMessage(database))
        }

        let sql = """
        WITH usage_samples AS (
            SELECT
                logs.thread_id,
                logs.ts,
                substr(
                    substr(
                        logs.feedback_log_body,
                        instr(logs.feedback_log_body, 'turn_id=') + length('turn_id=')
                    ),
                    1,
                    instr(
                        substr(
                            logs.feedback_log_body,
                            instr(logs.feedback_log_body, 'turn_id=') + length('turn_id=')
                        ),
                        ' '
                    ) - 1
                ) AS turn_id,
                CAST(
                    substr(
                        substr(
                            logs.feedback_log_body,
                            instr(logs.feedback_log_body, 'total_usage_tokens=') + length('total_usage_tokens=')
                        ),
                        1,
                        instr(
                            substr(
                                logs.feedback_log_body,
                                instr(logs.feedback_log_body, 'total_usage_tokens=') + length('total_usage_tokens=')
                            ),
                            ' '
                        ) - 1
                    ) AS INTEGER
                ) AS tokens
            FROM logs
            WHERE logs.target = 'codex_core::session::turn'
              AND logs.thread_id IS NOT NULL
              AND logs.feedback_log_body LIKE '%post sampling token usage%'
              AND instr(logs.feedback_log_body, 'turn_id=') > 0
              AND instr(logs.feedback_log_body, 'total_usage_tokens=') > 0
        ),
        turns AS (
            SELECT
                thread_id,
                turn_id,
                MAX(ts) AS ts,
                MAX(tokens) AS tokens
            FROM usage_samples
            GROUP BY thread_id, turn_id
        )
        SELECT state.threads.cwd, turns.thread_id, turns.turn_id, turns.ts, turns.tokens
        FROM turns
        JOIN state.threads ON state.threads.id = turns.thread_id
        WHERE state.threads.archived = 0
          AND state.threads.model_provider = 'openai'
        ORDER BY turns.ts DESC;
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            let message = sqliteErrorMessage(database, fallbackCode: prepareResult)
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return unavailableSnapshot(message: message)
        }
        defer { sqlite3_finalize(statement) }

        return makeTurnLogSnapshot(from: statement)
    }

    private func unavailableSnapshot(message: String) -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(
            provider: .codex,
            entries: [],
            availability: .unavailable(message)
        )
    }

    private func makeTurnLogSnapshot(from statement: OpaquePointer) -> ProviderProjectSnapshot {
        var entries: [TokenUsageEntry] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cwdPointer = sqlite3_column_text(statement, 0) else { continue }
            let cwd = String(cString: cwdPointer).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cwd.isEmpty else { continue }

            let threadId = stringColumn(statement, 1) ?? ""
            let turnId = stringColumn(statement, 2) ?? ""
            let timestamp = sqlite3_column_int64(statement, 3)
            let totalTokens = Int(sqlite3_column_int64(statement, 4))
            guard totalTokens > 0 else { continue }

            entries.append(
                TokenUsageEntry(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                    sessionId: "codex-sqlite:\(threadId):\(turnId)",
                    projectPath: cwd,
                    model: "openai",
                    inputTokens: totalTokens,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0
                )
            )
        }

        return ProviderProjectSnapshot(
            provider: .codex,
            entries: entries,
            availability: .available
        )
    }

    private func filter(_ snapshot: ProviderProjectSnapshot, for period: ProjectPeriod) -> ProviderProjectSnapshot {
        guard snapshot.availability == .available, let cutoff = cutoffDate(for: period) else {
            return snapshot
        }

        return ProviderProjectSnapshot(
            provider: snapshot.provider,
            entries: snapshot.entries.filter { $0.timestamp >= cutoff },
            availability: snapshot.availability
        )
    }

    private func sqliteErrorMessage(_ database: OpaquePointer, fallbackCode: Int32? = nil) -> String {
        let rawMessage = sqlite3_errmsg(database).map { String(cString: $0) } ?? "unknown SQLite error"

        if let fallbackCode {
            return "Codex SQLite query failed (\(fallbackCode)): \(rawMessage)"
        }

        return "Codex SQLite open failed: \(rawMessage)"
    }

    private func sqliteLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func stringColumn(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func cacheKey(usesTurnLogs: Bool) -> CodexSQLiteCacheKey {
        CodexSQLiteCacheKey(
            databasePath: databaseURL.path,
            databaseModifiedAt: modifiedAt(databaseURL),
            logsPath: logsDatabaseURL.path,
            logsModifiedAt: usesTurnLogs ? modifiedAt(logsDatabaseURL) : nil,
            usesTurnLogs: usesTurnLogs
        )
    }

    private func modifiedAt(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func cutoffDate(for period: ProjectPeriod) -> Date? {
        let seconds: TimeInterval

        switch period {
        case .day:
            seconds = 24 * 3600
        case .week:
            seconds = 7 * 24 * 3600
        case .all:
            return nil
        }

        return now().addingTimeInterval(-seconds)
    }
}

private actor CodexSQLiteSnapshotCache {
    private var key: CodexSQLiteCacheKey?
    private var snapshot: ProviderProjectSnapshot?

    func snapshot(
        for key: CodexSQLiteCacheKey,
        load: @Sendable () -> ProviderProjectSnapshot
    ) -> ProviderProjectSnapshot {
        if self.key == key, let snapshot {
            return snapshot
        }

        let snapshot = load()
        self.key = key
        self.snapshot = snapshot
        return snapshot
    }
}

private struct CodexSQLiteCacheKey: Equatable {
    let databasePath: String
    let databaseModifiedAt: Date?
    let logsPath: String
    let logsModifiedAt: Date?
    let usesTurnLogs: Bool
}
