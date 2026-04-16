import Foundation
import Security

struct UsageWindow {
    let utilization: Double  // 0.0 ~ 1.0
    let resetsAt: Date?
}

struct ClaudeUsageData {
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
    let sevenDaySonnet: UsageWindow
    let isExtraUsageEnabled: Bool
}

enum UsageFetchState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

@MainActor
final class AnthropicUsageService: ObservableObject {
    @Published var usageData: ClaudeUsageData?
    @Published var fetchState: UsageFetchState = .idle
    @Published private(set) var hasCredentials: Bool = false

    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var cachedFileJSON: [String: Any]?
    private var lastFetchedAt: Date?
    private let minForceInterval: TimeInterval = 60
    var minFetchInterval: TimeInterval = 55
    private var isFetching = false
    private let tokenExpirySeconds = 3600
    private let oauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private static let credentialsFileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Computed

    var sessionPercentage: Double {
        (usageData?.fiveHour.utilization ?? 0) * 100
    }

    var weeklyPercentage: Double {
        (usageData?.sevenDay.utilization ?? 0) * 100
    }

    var resetTimeRemaining: String? {
        guard let resetsAt = usageData?.fiveHour.resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSince(.now)
        guard remaining > 0 else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    // MARK: - Credentials

    func loadCredentials() {
        // 1) 파일에서 먼저 시도 (키체인 접근 없음)
        if let data = try? Data(contentsOf: Self.credentialsFileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauth = json["claudeAiOauth"] as? [String: Any],
           let accessToken = oauth["accessToken"] as? String {
            cachedAccessToken = accessToken
            cachedRefreshToken = oauth["refreshToken"] as? String
            cachedFileJSON = json
            hasCredentials = true
            return
        }

        // 2) 파일이 없으면 키체인에서 한 번만 읽어서 파일로 마이그레이션
        if migrateFromKeychain() { return }

        hasCredentials = false
    }

    private static let keychainService = "Claude Code-credentials"

    /// 키체인에서 읽어서 파일로 저장 (최초 1회만 실행됨)
    private func migrateFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String
        else { return false }

        cachedAccessToken = accessToken
        cachedRefreshToken = oauth["refreshToken"] as? String
        cachedFileJSON = json
        hasCredentials = true

        // 파일로 저장하여 다음부터는 키체인 접근 불필요
        try? data.write(to: Self.credentialsFileURL, options: .atomic)
        return true
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = cachedRefreshToken,
              let url = URL(string: "https://platform.claude.com/v1/oauth/token")
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthClientId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await Self.urlSession.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String
        else { return false }

        cachedAccessToken = newAccessToken
        if let newRefresh = json["refresh_token"] as? String {
            cachedRefreshToken = newRefresh
        }
        saveCredentials(accessToken: newAccessToken, refreshToken: cachedRefreshToken ?? refreshToken)
        return true
    }

    private func saveCredentials(accessToken: String, refreshToken: String) {
        var json = cachedFileJSON ?? [:]
        var oauthDict = (json["claudeAiOauth"] as? [String: Any]) ?? [:]
        oauthDict["accessToken"] = accessToken
        oauthDict["refreshToken"] = refreshToken
        oauthDict["expiresAt"] = Int(Date().timeIntervalSince1970) + tokenExpirySeconds
        json["claudeAiOauth"] = oauthDict
        cachedFileJSON = json

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else { return }
        try? data.write(to: Self.credentialsFileURL, options: .atomic)
    }

    // MARK: - Fetch Usage

    func fetchUsage(force: Bool = false) async {
        if !hasCredentials {
            loadCredentials()
        }
        guard hasCredentials else {
            fetchState = .error("No credentials. Log in to Claude Code first.")
            return
        }

        guard !isFetching else { return }

        if let lastFetch = lastFetchedAt {
            let elapsed = Date().timeIntervalSince(lastFetch)
            if force {
                guard elapsed >= minForceInterval else { return }
            } else {
                guard elapsed >= minFetchInterval else { return }
            }
        }

        isFetching = true
        fetchState = .loading
        await performFetch(retryOnAuthFailure: true)
        isFetching = false
    }

    private func performFetch(retryOnAuthFailure: Bool) async {
        guard let accessToken = cachedAccessToken,
              let url = URL(string: "https://api.anthropic.com/api/oauth/usage")
        else {
            fetchState = .error("No access token")
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await Self.urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                fetchState = .error("No response")
                return
            }

            // Rate limited — back off and keep last known data
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                    .flatMap(Double.init) ?? 60
                lastFetchedAt = Date().addingTimeInterval(retryAfter - minFetchInterval)
                fetchState = usageData != nil ? .loaded : .error("Rate limited. Retry in \(Int(retryAfter))s")
                return
            }

            if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) && retryOnAuthFailure {
                // 1) refresh token으로 재발급
                if await refreshAccessToken() {
                    await performFetch(retryOnAuthFailure: false)
                    return
                }
                // 2) 파일 재로드 (Claude Code가 파일을 갱신했을 수 있음)
                loadCredentials()
                if hasCredentials, cachedAccessToken != accessToken {
                    await performFetch(retryOnAuthFailure: false)
                    return
                }
                // 3) 키체인에서 읽기 (Claude Code가 키체인에 새 토큰 저장했을 수 있음)
                if migrateFromKeychain(), cachedAccessToken != accessToken {
                    await performFetch(retryOnAuthFailure: false)
                    return
                }
                fetchState = .error("Auth failed. Re-login to Claude Code.")
                return
            }

            guard httpResponse.statusCode == 200 else {
                fetchState = .error("HTTP \(httpResponse.statusCode)")
                return
            }

            parseUsageResponse(data)
            lastFetchedAt = Date()
        } catch {
            fetchState = .error(error.localizedDescription)
        }
    }

    private func parseUsageResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fetchState = .error("Parse error")
            return
        }

        func parseWindow(_ key: String) -> UsageWindow {
            guard let window = json[key] as? [String: Any] else {
                return UsageWindow(utilization: 0, resetsAt: nil)
            }
            let utilization = (window["utilization"] as? Double) ?? 0
            let resetsAtStr = window["resets_at"] as? String
            let resetsAt = resetsAtStr.flatMap { Self.isoFormatter.date(from: $0) }
            return UsageWindow(utilization: utilization / 100.0, resetsAt: resetsAt)
        }

        let extraUsage = json["extra_usage"] as? [String: Any]
        let isExtraEnabled = (extraUsage?["is_enabled"] as? Bool) ?? false

        usageData = ClaudeUsageData(
            fiveHour: parseWindow("five_hour"),
            sevenDay: parseWindow("seven_day"),
            sevenDaySonnet: parseWindow("seven_day_sonnet"),
            isExtraUsageEnabled: isExtraEnabled
        )

        fetchState = .loaded
    }
}
