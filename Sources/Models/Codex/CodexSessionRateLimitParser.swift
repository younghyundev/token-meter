import Foundation

struct CodexSessionRateLimitSnapshot: Equatable, Sendable {
    let primaryUsedPercent: Double
    let primaryWindowMinutes: Int?
    let primaryResetsAt: Date?
    let secondaryUsedPercent: Double?
    let secondaryWindowMinutes: Int?
    let secondaryResetsAt: Date?
    let totalTokens: Int?
    let planType: String?
    let observedAt: Date
}

protocol CodexSessionRateLimitParsing: Sendable {
    func latestSnapshot() -> CodexSessionRateLimitSnapshot?
}

final class CodexSessionRateLimitParser: CodexSessionRateLimitParsing, Sendable {
    private let sessionsDirectory: URL

    init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")) {
        self.sessionsDirectory = sessionsDirectory
    }

    func latestSnapshot() -> CodexSessionRateLimitSnapshot? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsDirectory.path),
              let enumerator = fileManager.enumerator(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return nil
        }

        var latest: CodexSessionRateLimitSnapshot?

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            parseSessionFile(at: fileURL, latest: &latest)
        }

        return latest
    }

    private func parseSessionFile(at url: URL, latest: inout CodexSessionRateLimitSnapshot?) {
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
                      let snapshot = parseSnapshot(from: json)
                else {
                    continue
                }

                if let latest, latest.observedAt >= snapshot.observedAt {
                    continue
                }
                latest = snapshot
            }
        }
    }

    private func parseSnapshot(from json: [String: Any]) -> CodexSessionRateLimitSnapshot? {
        guard (json["type"] as? String) == "event_msg",
              let payload = json["payload"] as? [String: Any],
              (payload["type"] as? String) == "token_count",
              let rateLimits = payload["rate_limits"] as? [String: Any],
              let primary = rateLimits["primary"] as? [String: Any],
              let primaryUsedPercent = doubleValue(primary["used_percent"]),
              let timestampString = json["timestamp"] as? String,
              let observedAt = Self.parseDate(timestampString)
        else {
            return nil
        }

        let secondary = rateLimits["secondary"] as? [String: Any]
        let info = payload["info"] as? [String: Any]
        let totalTokenUsage = info?["total_token_usage"] as? [String: Any]

        return CodexSessionRateLimitSnapshot(
            primaryUsedPercent: primaryUsedPercent,
            primaryWindowMinutes: intValue(primary["window_minutes"]),
            primaryResetsAt: dateValue(primary["resets_at"]),
            secondaryUsedPercent: secondary.flatMap { doubleValue($0["used_percent"]) },
            secondaryWindowMinutes: secondary.flatMap { intValue($0["window_minutes"]) },
            secondaryResetsAt: secondary.flatMap { dateValue($0["resets_at"]) },
            totalTokens: intValue(totalTokenUsage?["total_tokens"]),
            planType: rateLimits["plan_type"] as? String,
            observedAt: observedAt
        )
    }

    private func doubleValue(_ raw: Any?) -> Double? {
        switch raw {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private func intValue(_ raw: Any?) -> Int? {
        switch raw {
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private func dateValue(_ raw: Any?) -> Date? {
        guard let seconds = intValue(raw) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
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
