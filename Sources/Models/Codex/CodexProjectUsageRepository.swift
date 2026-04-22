import Foundation

struct CodexProjectUsageRepository: ProjectUsageRepository, Sendable {
    private let sqliteRepository: CodexSQLiteRepository
    private let rolloutParser: CodexRolloutParser
    private let authStateProbe: CodexAuthStateProbe

    init(
        sqliteRepository: CodexSQLiteRepository = CodexSQLiteRepository(),
        rolloutParser: CodexRolloutParser = CodexRolloutParser(),
        authStateProbe: CodexAuthStateProbe = CodexAuthStateProbe()
    ) {
        self.sqliteRepository = sqliteRepository
        self.rolloutParser = rolloutParser
        self.authStateProbe = authStateProbe
    }

    func projectUsage(for period: ProjectPeriod) async -> ProviderProjectSnapshot {
        switch authStateProbe.probe() {
        case .missing, .malformed:
            return loginRequiredSnapshot()
        case .available:
            break
        }

        let sqliteSnapshot = await sqliteRepository.projectUsage(for: period)
        guard case .available = sqliteSnapshot.availability else {
            return unavailableSnapshot()
        }

        let rolloutMetadata = rolloutParser.parseAll()
        let normalizedEntries = normalizeEntries(sqliteSnapshot.entries, with: rolloutMetadata)

        return ProviderProjectSnapshot(
            provider: .codex,
            entries: normalizedEntries,
            availability: .available
        )
    }

    private func normalizeEntries(
        _ entries: [TokenUsageEntry],
        with metadata: [CodexRolloutMetadata]
    ) -> [TokenUsageEntry] {
        let cwdByRolloutPath = metadata.reduce(into: [String: String]()) { result, item in
            guard let rolloutPath = normalizedPath(item.rolloutPath),
                  let cwd = normalizedPath(item.cwd),
                  result[rolloutPath] == nil
            else {
                return
            }

            result[rolloutPath] = cwd
        }

        var buckets: [String: [TokenUsageEntry]] = [:]

        for entry in entries {
            let normalizedProjectPath = normalizedProjectPath(
                for: entry.projectPath,
                cwdByRolloutPath: cwdByRolloutPath
            )
            guard let normalizedProjectPath else { continue }

            var bucket = buckets[normalizedProjectPath, default: []]
            bucket.append(entry)
            buckets[normalizedProjectPath] = bucket
        }

        return buckets.map { path, items in
            TokenUsageEntry(
                timestamp: items.map(\.timestamp).max() ?? .now,
                sessionId: "codex:\(path)",
                projectPath: path,
                model: items.first?.model ?? "openai",
                inputTokens: items.reduce(0) { $0 + $1.inputTokens },
                outputTokens: items.reduce(0) { $0 + $1.outputTokens },
                cacheCreationTokens: items.reduce(0) { $0 + $1.cacheCreationTokens },
                cacheReadTokens: items.reduce(0) { $0 + $1.cacheReadTokens }
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }
    }

    private func normalizedProjectPath(
        for rawPath: String,
        cwdByRolloutPath: [String: String]
    ) -> String? {
        guard let normalized = normalizedPath(rawPath) else {
            return nil
        }

        if let reconciled = cwdByRolloutPath[normalized] {
            return reconciled
        }

        return normalized.contains("/rollout-") ? nil : normalized
    }

    private func normalizedPath(_ rawPath: String?) -> String? {
        guard let rawPath else { return nil }

        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }

    private func unavailableSnapshot() -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(
            provider: .codex,
            entries: [],
            availability: .unavailable("Codex local data unavailable")
        )
    }

    private func loginRequiredSnapshot() -> ProviderProjectSnapshot {
        ProviderProjectSnapshot(
            provider: .codex,
            entries: [],
            availability: .loginRequired
        )
    }
}
