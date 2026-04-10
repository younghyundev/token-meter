import Foundation

final class TokenParser: Sendable {
    private let claudeDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = home.appendingPathComponent(".claude/projects")
    }

    /// Parse all JSONL files — call from background thread
    func parseAll() -> [TokenUsageEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeDir.path) else { return [] }

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: claudeDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var entries: [TokenUsageEntry] = []
        entries.reserveCapacity(4000)

        for projectDir in projectDirs {
            let projectName = projectDir.lastPathComponent
            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
            for file in jsonlFiles {
                parseJSONLInto(url: file, project: projectName, entries: &entries)
            }
        }

        return entries
    }

    private func parseJSONLInto(url: URL, project: String, entries: inout [TokenUsageEntry]) {
        guard let data = try? Data(contentsOf: url) else { return }

        // Process line by line without creating a full String copy
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let count = buffer.count
            var lineStart = 0

            for i in 0...count {
                let isEnd = (i == count) || (base[i] == 0x0A) // newline
                guard isEnd, i > lineStart else {
                    if isEnd { lineStart = i + 1 }
                    continue
                }

                let lineData = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: base.advanced(by: lineStart)),
                                     count: i - lineStart, deallocator: .none)
                lineStart = i + 1

                guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let message = json["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { continue }

                let inputTokens = usage["input_tokens"] as? Int ?? 0
                let outputTokens = usage["output_tokens"] as? Int ?? 0
                let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

                guard inputTokens > 0 || outputTokens > 0 || cacheCreation > 0 else { continue }

                let timestampStr = json["timestamp"] as? String ?? ""
                let timestamp = Self.parseDate(timestampStr) ?? Date()
                let sessionId = json["sessionId"] as? String ?? "unknown"
                let model = message["model"] as? String ?? "unknown"
                let cwd = json["cwd"] as? String ?? project

                entries.append(TokenUsageEntry(
                    timestamp: timestamp,
                    sessionId: sessionId,
                    projectPath: cwd,
                    model: model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationTokens: cacheCreation,
                    cacheReadTokens: cacheRead
                ))
            }
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFrac.date(from: string)
    }
}
