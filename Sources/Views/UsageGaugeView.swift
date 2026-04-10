import SwiftUI

struct UsageGaugeView: View {
    let title: String
    let percentage: Double
    let subtitle: String?

    private var barColor: Color {
        switch percentage {
        case ..<50: return .green
        case 50..<80: return .yellow
        case 80..<90: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(percentage, 100) / 100)
                }
            }
            .frame(height: 6)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

func formatTokens(_ count: Int) -> String {
    switch count {
    case ..<1_000:
        return "\(count) tokens"
    case ..<1_000_000:
        return String(format: "%.1fK tokens", Double(count) / 1_000)
    case ..<1_000_000_000:
        return String(format: "%.1fM tokens", Double(count) / 1_000_000)
    default:
        return String(format: "%.1fB tokens", Double(count) / 1_000_000_000)
    }
}
