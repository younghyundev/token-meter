import SwiftUI

enum PopoverTab {
    case usage
    case settings
}

struct PopoverContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var localization = LocalizationManager.shared
    @State private var currentTab: PopoverTab = .usage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal)

            switch currentTab {
            case .usage:
                usageContent
            case .settings:
                settingsContent
            }

            Divider().padding(.horizontal)
            footer
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if viewModel.fetchState == .loading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            Spacer()

            Button {
                currentTab = currentTab == .settings ? .usage : .settings
            } label: {
                Image(systemName: currentTab == .settings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(currentTab == .settings ? .primary : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Usage Content

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            providerSelector
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider().padding(.horizontal)

            switch viewModel.selectedProvider {
            case .claude:
                if viewModel.hasCredentials {
                    sessionSection
                    Divider().padding(.horizontal)
                    weeklySection
                    Divider().padding(.horizontal)
                    projectSection
                } else {
                    noCredentialsView
                }
            case .codex:
                codexSessionSection
                Divider().padding(.horizontal)
                codexWeeklySection
                Divider().padding(.horizontal)
                projectSection
            }
        }
    }

    private var providerSelector: some View {
        Picker("", selection: $viewModel.selectedProvider) {
            Text(L("provider.claude")).tag(UsageProvider.claude)
            Text(L("provider.codex")).tag(UsageProvider.codex)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - Session

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            UsageGaugeView(
                title: L("session.title"),
                percentage: viewModel.sessionPercentage,
                subtitle: viewModel.resetTimeRemaining.map { L("reset.prefix") + $0 }
            )

            if case .error(let msg) = viewModel.fetchState {
                Text(msg)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Weekly

    private var weeklySection: some View {
        UsageGaugeView(
            title: L("weekly.title"),
            percentage: viewModel.weeklyPercentage,
            subtitle: nil
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Projects

    private var projectSection: some View {
        ProjectBreakdownView(
            projects: viewModel.projects,
            availability: viewModel.projectAvailability(for: viewModel.selectedProvider),
            emptyMessage: projectEmptyMessage,
            loginRequiredMessage: projectLoginRequiredMessage,
            unavailableMessage: projectUnavailableMessage,
            sectionTitle: projectSectionTitle,
            period: $viewModel.projectPeriod
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var projectSectionTitle: String {
        L("projects.title")
    }

    private var projectEmptyMessage: String {
        switch viewModel.selectedProvider {
        case .claude:
            L("projects.empty")
        case .codex:
            L("codex.projects.empty.title")
        }
    }

    private var projectLoginRequiredMessage: String {
        switch viewModel.selectedProvider {
        case .claude:
            L("login.description")
        case .codex:
            L("codex.login.description")
        }
    }

    private var projectUnavailableMessage: String {
        switch viewModel.selectedProvider {
        case .claude:
            L("projects.empty")
        case .codex:
            L("codex.projects.unavailable")
        }
    }
    private var codexSessionSection: some View {
        CodexStatusCardView(snapshot: viewModel.codexStatusSnapshot)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private var codexWeeklySection: some View {
        Group {
            if let weeklyPercentage = viewModel.codexWeeklyPercentage {
                UsageGaugeView(
                    title: L("weekly.title"),
                    percentage: weeklyPercentage,
                    subtitle: nil
                )
            } else {
                Text(L("codex.available.description"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - No Credentials

    private var noCredentialsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(L("login.title"))
                .font(.system(size: 12, weight: .medium))
            Text(L("login.description"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Settings

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("settings.title"))
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Text(L("settings.language"))
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $localization.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }

            HStack {
                Text(L("settings.interval"))
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.refreshInterval) {
                    Text("1min").tag(60)
                    Text("5min").tag(300)
                    Text("10min").tag(600)
                    Text("30min").tag(1800)
                    Text("60min").tag(3600)
                }
                .labelsHidden()
                .frame(width: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(L("footer.updated")) \(viewModel.lastRefreshed, style: .relative) \(L("footer.ago"))")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                Task { await viewModel.forceRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(viewModel.selectedProvider == .codex ? L("footer.refresh.codex") : L("footer.refresh"))
            .help(viewModel.selectedProvider == .codex ? L("footer.refresh.codex") : L("footer.refresh"))

            Button(L("footer.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
