import SwiftUI

struct ProjectBreakdownView: View {
    let projects: [ProjectUsage]
    @Binding var period: ProjectPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("projects.title"))
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Picker("", selection: $period) {
                    Text(L("period.day")).tag(ProjectPeriod.day)
                    Text(L("period.week")).tag(ProjectPeriod.week)
                    Text(L("period.all")).tag(ProjectPeriod.all)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }

            if projects.isEmpty {
                Text(L("projects.empty"))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(projects.prefix(8).enumerated()), id: \.element.id) { index, project in
                    ProjectRow(project: project, colorIndex: index)
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: ProjectUsage
    let colorIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle()
                    .fill(colorForProject(colorIndex))
                    .frame(width: 8, height: 8)

                Text(project.displayName)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer()

                Text(formatTokens(project.totalTokens))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForProject(colorIndex).opacity(0.6))
                    .frame(width: geo.size.width * project.percentage / 100)
            }
            .frame(height: 3)
        }
    }

    private func colorForProject(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.35, green: 0.56, blue: 1.0),   // blue
            Color(red: 0.96, green: 0.40, blue: 0.40),   // red
            Color(red: 0.25, green: 0.80, blue: 0.50),   // green
            Color(red: 0.95, green: 0.70, blue: 0.22),   // amber
            Color(red: 0.68, green: 0.38, blue: 0.95),   // purple
            Color(red: 0.98, green: 0.50, blue: 0.18),   // orange
            Color(red: 0.20, green: 0.75, blue: 0.82),   // teal
            Color(red: 0.92, green: 0.40, blue: 0.68),   // pink
            Color(red: 0.55, green: 0.75, blue: 0.25),   // lime
            Color(red: 0.85, green: 0.55, blue: 0.95),   // lavender
            Color(red: 1.0,  green: 0.60, blue: 0.48),   // coral
            Color(red: 0.30, green: 0.65, blue: 0.55),   // emerald
            Color(red: 0.90, green: 0.75, blue: 0.45),   // gold
            Color(red: 0.45, green: 0.45, blue: 0.85),   // indigo
            Color(red: 0.75, green: 0.25, blue: 0.45),   // burgundy
            Color(red: 0.40, green: 0.80, blue: 1.0),    // sky
        ]
        return colors[index % colors.count]
    }
}
