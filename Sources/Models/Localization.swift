import SwiftUI

enum AppLanguage: String, CaseIterable {
    case korean = "ko"
    case english = "en"

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("appLanguage") var language: AppLanguage = .korean

    private init() {}
}

@MainActor
func L(_ key: String) -> String {
    let lang = LocalizationManager.shared.language

    guard let value = strings[lang]?[key] else {
        return strings[.english]?[key] ?? key
    }
    return value
}

private let strings: [AppLanguage: [String: String]] = [
    .korean: [
        "provider.claude": "Claude",
        "provider.codex": "Codex",
        "session.title": "세션 (5시간)",
        "weekly.title": "주간 (7일)",
        "projects.title": "프로젝트",
        "projects.empty": "사용 데이터 없음",
        "codex.projects.empty.title": "Codex 프로젝트 사용량 없음",
        "codex.projects.empty.body": "이 기간에는 로컬 Codex 사용량이 없습니다. 7일 또는 전체로 바꾸거나 프로젝트에서 Codex를 먼저 실행하세요.",
        "codex.projects.unavailable": "Token Meter가 현재 사용자 계정의 로컬 Codex 프로젝트 데이터를 읽지 못했습니다. Codex에 로그인한 뒤 새로고침해 보세요.",
        "codex.available.title": "Codex 사용 가능",
        "codex.available.description": "이 Mac에서 Codex 로그인 상태가 확인되었습니다.",
        "codex.session.title": "Codex 세션",
        "codex.login.title": "Codex 로그인 필요",
        "codex.login.description": "로컬에서 Codex에 로그인한 뒤 Token Meter를 새로고침하세요.",
        "codex.unavailable.title": "Codex를 사용할 수 없음",
        "codex.unavailable.description": "Token Meter가 현재 사용자 계정의 Codex 상태를 확인하지 못했습니다. Codex에 로그인한 뒤 새로고침해 보세요.",
        "codex.session.window.5h": "5시간 창",
        "codex.session.window.7d": "7일 창",
        "codex.session.resetsIn": "리셋까지",
        "footer.updated": "업데이트",
        "footer.ago": "전",
        "footer.quit": "종료",
        "footer.refresh": "새로고침",
        "footer.refresh.codex": "Codex 새로고침",
        "footer.settings": "설정",
        "reset.prefix": "리셋까지 ",
        "login.title": "로그인 필요",
        "login.description": "Claude Code에 먼저 로그인한 후\nToken Meter를 다시 실행하세요.",
        "settings.title": "설정",
        "settings.language": "언어",
        "settings.interval": "업데이트 주기",
        "settings.interval.unit": "초",
        "period.day": "1일",
        "period.week": "7일",
        "period.all": "전체",
    ],
    .english: [
        "provider.claude": "Claude",
        "provider.codex": "Codex",
        "session.title": "Session (5h)",
        "weekly.title": "Weekly (7d)",
        "projects.title": "Projects",
        "projects.empty": "No usage data",
        "codex.projects.empty.title": "No Codex project usage",
        "codex.projects.empty.body": "No local Codex usage was found for this time range. Try 7 days or All, or run Codex in a project first.",
        "codex.projects.unavailable": "Token Meter could not read local Codex project data for the current user. Sign in to Codex locally, then refresh.",
        "codex.available.title": "Codex available",
        "codex.available.description": "Codex authentication was detected on this Mac.",
        "codex.session.title": "Codex Session",
        "codex.login.title": "Codex login required",
        "codex.login.description": "Sign in to Codex locally, then refresh Token Meter.",
        "codex.unavailable.title": "Codex unavailable",
        "codex.unavailable.description": "Token Meter could not confirm Codex status for the current user. Sign in to Codex locally, then refresh.",
        "codex.session.window.5h": "5h window",
        "codex.session.window.7d": "7d window",
        "codex.session.resetsIn": "resets in",
        "footer.updated": "Updated",
        "footer.ago": "ago",
        "footer.quit": "Quit",
        "footer.refresh": "Refresh",
        "footer.refresh.codex": "Refresh Codex",
        "footer.settings": "Settings",
        "reset.prefix": "resets in ",
        "login.title": "Not logged in",
        "login.description": "Log in to Claude Code first,\nthen relaunch Token Meter.",
        "settings.title": "Settings",
        "settings.language": "Language",
        "settings.interval": "Update interval",
        "settings.interval.unit": "sec",
        "period.day": "1 day",
        "period.week": "7 days",
        "period.all": "all",
    ],
]
