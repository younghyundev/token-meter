import SwiftUI

struct CodexStatusCardView: View {
    let snapshot: CodexStatusSnapshot

    var body: some View {
        switch snapshot {
        case let .usageMetric(percentage, subtitle):
            UsageGaugeView(
                title: L("session.title"),
                percentage: percentage,
                subtitle: subtitle
            )
        case let .availabilityOnly(title, subtitle):
            statusCard(
                icon: "checkmark.seal",
                title: title,
                body: subtitle,
                accent: .secondary
            )
        case .loginRequired:
            statusCard(
                icon: "person.crop.circle.badge.questionmark",
                title: L("codex.login.title"),
                body: L("codex.login.description"),
                accent: .secondary
            )
        case let .unavailable(message):
            statusCard(
                icon: "exclamationmark.triangle",
                title: L("codex.unavailable.title"),
                body: message,
                accent: .red
            )
        }
    }

    private func statusCard(icon: String, title: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(body)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
