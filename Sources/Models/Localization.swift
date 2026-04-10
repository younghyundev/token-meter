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
        "session.title": "세션 (5시간)",
        "weekly.title": "주간 (7일)",
        "projects.title": "프로젝트",
        "projects.empty": "사용 데이터 없음",
        "footer.updated": "업데이트",
        "footer.ago": "전",
        "footer.quit": "종료",
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
        "session.title": "Session (5h)",
        "weekly.title": "Weekly (7d)",
        "projects.title": "Projects",
        "projects.empty": "No usage data",
        "footer.updated": "Updated",
        "footer.ago": "ago",
        "footer.quit": "Quit",
        "footer.settings": "Settings",
        "reset.prefix": "resets in ",
        "login.title": "Not logged in",
        "login.description": "Log in to Claude Code first,\nthen relaunch Token Meter.",
        "settings.title": "Settings",
        "settings.language": "Language",
        "settings.interval": "Update interval",
        "settings.interval.unit": "sec",
        "period.day": "1D",
        "period.week": "7D",
        "period.all": "All",
    ],
]
