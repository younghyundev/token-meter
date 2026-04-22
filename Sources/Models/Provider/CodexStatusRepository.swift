import Foundation

enum CodexStatusSnapshot: Equatable {
    case usageMetric(percentage: Double, subtitle: String?)
    case availabilityOnly(title: String, subtitle: String)
    case loginRequired
    case unavailable(message: String)
}

struct CodexStatusRepository: Sendable {
    private let authStateProbe: CodexAuthStateProbe

    init(authStateProbe: CodexAuthStateProbe = CodexAuthStateProbe()) {
        self.authStateProbe = authStateProbe
    }

    func snapshot() -> CodexStatusSnapshot {
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
}
