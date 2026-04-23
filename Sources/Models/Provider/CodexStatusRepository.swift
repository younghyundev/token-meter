import Foundation

enum CodexStatusSnapshot: Equatable {
    case usageMetric(primaryPercentage: Double, secondaryPercentage: Double?, subtitle: String?)
    case availabilityOnly(title: String, subtitle: String)
    case loginRequired
    case unavailable(message: String)
}

struct CodexStatusRepository: Sendable {
    private let sessionRateLimitParser: any CodexSessionRateLimitParsing
    private let authStateProbe: CodexAuthStateProbe

    init(
        sessionRateLimitParser: any CodexSessionRateLimitParsing = CodexSessionRateLimitParser(),
        authStateProbe: CodexAuthStateProbe = CodexAuthStateProbe()
    ) {
        self.sessionRateLimitParser = sessionRateLimitParser
        self.authStateProbe = authStateProbe
    }

    func snapshot() -> CodexStatusSnapshot {
        if let sessionSnapshot = sessionRateLimitParser.latestSnapshot() {
            return .usageMetric(
                primaryPercentage: sessionSnapshot.primaryUsedPercent,
                secondaryPercentage: sessionSnapshot.secondaryUsedPercent,
                subtitle: makeSubtitle(from: sessionSnapshot)
            )
        }

        switch authStateProbe.probe() {
        case .available:
            return .availabilityOnly(
                title: "Codex available",
                subtitle: "Current Codex session is authenticated on this Mac."
            )
        case .missing, .malformed:
            return .loginRequired
        }
    }

    private func makeSubtitle(from snapshot: CodexSessionRateLimitSnapshot) -> String? {
        var parts: [String] = []

        if let primaryWindowMinutes = snapshot.primaryWindowMinutes {
            parts.append(windowLabel(for: primaryWindowMinutes))
        }

        if let primaryResetsAt = snapshot.primaryResetsAt {
            parts.append("resets in \(relativeTimeString(until: primaryResetsAt))")
        }

        if let secondaryUsedPercent = snapshot.secondaryUsedPercent,
           let secondaryWindowMinutes = snapshot.secondaryWindowMinutes {
            parts.append("\(windowLabel(for: secondaryWindowMinutes)) \(Int(secondaryUsedPercent))%")
        }

        if let planType = snapshot.planType, !planType.isEmpty {
            parts.append(planType)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func relativeTimeString(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func windowLabel(for minutes: Int) -> String {
        switch minutes {
        case 300:
            return "5h window"
        case 10_080:
            return "7d window"
        default:
            return "\(minutes)m"
        }
    }
}
