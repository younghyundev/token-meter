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
                ForEach(projects.prefix(8)) { project in
                    ProjectRow(project: project)
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: ProjectUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle()
                    .fill(colorForProject(project.name))
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
                    .fill(colorForProject(project.name).opacity(0.6))
                    .frame(width: geo.size.width * project.percentage / 100)
            }
            .frame(height: 3)
        }
    }

    private func colorForProject(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .cyan, .mint, .indigo, .teal]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
