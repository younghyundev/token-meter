import Foundation
import SQLite3

final class CodexSQLiteRepository: ProjectUsageRepository, Sendable {
    private let databaseURL: URL
    private let now: @Sendable () -> Date

    init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/state_5.sqlite"),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.databaseURL = databaseURL
        self.now = now
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return unavailableSnapshot(message: "Codex usage database is unavailable.")
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database
        else {
            if database != nil {
                sqlite3_close(database)
            }
            return unavailableSnapshot(message: "Codex usage database is unavailable.")
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT cwd, SUM(tokens_used) AS total_tokens
        FROM threads
        WHERE archived = 0 AND model_provider = 'openai'
        GROUP BY cwd
        ORDER BY total_tokens DESC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return unavailableSnapshot(message: "Codex usage database is unavailable.")
        }
        defer { sqlite3_finalize(statement) }

        var entries: [TokenUsageEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cwdPointer = sqlite3_column_text(statement, 0) else { continue }
            let cwd = String(cString: cwdPointer).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cwd.isEmpty else { continue }

            let totalTokens = Int(sqlite3_column_int64(statement, 1))
            guard totalTokens > 0 else { continue }

            entries.append(
                TokenUsageEntry(
                    timestamp: now(),
                    sessionId: "codex-sqlite:\(cwd)",
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

    private func unavailableSnapshot(message: String) -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(
            provider: .codex,
            entries: [],
            availability: .unavailable(message)
        )
    }
}
