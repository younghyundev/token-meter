import Foundation

enum CodexStatusSnapshot: Equatable, Sendable {
    case usageMetric(primaryPercentage: Double, secondaryPercentage: Double?, subtitle: String?)
    case availabilityOnly(title: String, subtitle: String)
    case loginRequired
    case unavailable(message: String)
}

struct CodexStatusRepository: Sendable {
    private let sessionRateLimitParser: any CodexSessionRateLimitParsing
    private let authStateProbe: CodexAuthStateProbe
    private let now: @Sendable () -> Date

    init(
        sessionRateLimitParser: any CodexSessionRateLimitParsing = CodexSessionRateLimitParser(),
        authStateProbe: CodexAuthStateProbe = CodexAuthStateProbe(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionRateLimitParser = sessionRateLimitParser
        self.authStateProbe = authStateProbe
        self.now = now
    }

    func snapshot() -> CodexStatusSnapshot {
        if let sessionSnapshot = sessionRateLimitParser.latestSnapshot() {
            return .usageMetric(
                primaryPercentage: sessionSnapshot.primaryUsedPercent,
                secondaryPercentage: currentSecondaryPercentage(from: sessionSnapshot),
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

        if let primaryResetsAt = snapshot.primaryResetsAt, primaryResetsAt > now() {
            parts.append("resets in \(relativeTimeString(until: primaryResetsAt))")
        }

        if let secondaryUsedPercent = currentSecondaryPercentage(from: snapshot),
           let secondaryWindowMinutes = snapshot.secondaryWindowMinutes {
            parts.append("\(windowLabel(for: secondaryWindowMinutes)) \(Int(secondaryUsedPercent))%")
        }

        if let planType = snapshot.planType, !planType.isEmpty {
            parts.append(planType)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func currentSecondaryPercentage(from snapshot: CodexSessionRateLimitSnapshot) -> Double? {
        guard let secondaryUsedPercent = snapshot.secondaryUsedPercent else {
            return nil
        }

        if let secondaryResetsAt = snapshot.secondaryResetsAt, secondaryResetsAt <= now() {
            return nil
        }

        return secondaryUsedPercent
    }

    private func relativeTimeString(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now())))
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
