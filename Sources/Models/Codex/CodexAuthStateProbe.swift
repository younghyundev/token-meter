import Foundation

enum CodexAuthState: Equatable {
    case available
    case missing
    case malformed
}

struct CodexAuthStateProbe: Sendable {
    private let authURL: URL

    init(authURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")) {
        self.authURL = authURL
    }

    func probe() -> CodexAuthState {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            return .missing
        }

        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .malformed
        }

        if json["tokens"] is [String: Any] || json["account_id"] != nil || !json.isEmpty {
            return .available
        }

        return .malformed
    }
}
