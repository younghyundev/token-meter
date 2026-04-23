import Foundation

struct CodexRolloutMetadata: Equatable, Sendable {
    let rolloutPath: String?
    let cwd: String?
    let sessionId: String?
    let timestamp: Date?
}

final class CodexRolloutParser: Sendable {
    private let sessionsDirectory: URL

    init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")) {
        self.sessionsDirectory = sessionsDirectory
    }

    func parseAll() -> [CodexRolloutMetadata] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsDirectory.path),
              let enumerator = fileManager.enumerator(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return []
        }

        var metadata: [CodexRolloutMetadata] = []
        metadata.reserveCapacity(256)

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            parseRolloutFile(at: fileURL, into: &metadata)
        }

        return metadata
    }

    private func parseRolloutFile(at url: URL, into metadata: inout [CodexRolloutMetadata]) {
        guard let data = try? Data(contentsOf: url) else { return }

        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let count = buffer.count
            var lineStart = 0

            for index in 0...count {
                let isLineEnd = (index == count) || (base[index] == 0x0A)
                guard isLineEnd, index > lineStart else {
                    if isLineEnd { lineStart = index + 1 }
                    continue
                }

                let lineData = Data(
                    bytesNoCopy: UnsafeMutableRawPointer(mutating: base.advanced(by: lineStart)),
                    count: index - lineStart,
                    deallocator: .none
                )
                lineStart = index + 1

                guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let rolloutMetadata = parseMetadata(from: json)
                else {
                    continue
                }

                metadata.append(rolloutMetadata)
            }
        }
    }

    private func parseMetadata(from json: [String: Any]) -> CodexRolloutMetadata? {
        let payload = json["payload"] as? [String: Any]
        let rolloutPath = stringValue(from: json, payload: payload, keys: ["rollout_path", "rolloutPath"])
        let cwd = stringValue(from: json, payload: payload, keys: ["cwd"])
        let sessionId = stringValue(from: json, payload: payload, keys: ["session_id", "sessionId"])

        let timestampString = stringValue(from: json, payload: payload, keys: ["timestamp"])
        let timestamp = timestampString.flatMap(Self.parseDate)

        guard rolloutPath != nil || cwd != nil || sessionId != nil || timestamp != nil else {
            return nil
        }

        return CodexRolloutMetadata(
            rolloutPath: rolloutPath,
            cwd: cwd,
            sessionId: sessionId,
            timestamp: timestamp
        )
    }

    private func stringValue(from json: [String: Any], payload: [String: Any]?, keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String, !value.isEmpty {
                return value
            }
            if let value = payload?[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFractionalSeconds.date(from: string)
    }
}
