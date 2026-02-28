import SwiftUI

struct UsagePanelView: View {
    @Bindable var state: AppState
    @State private var showSettings = false

    // MARK: - Theme

    private let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.76, blue: 0.96),
            Color(red: 0.68, green: 0.65, blue: 0.92),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let dividerColor = Color.white.opacity(0.2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.bottom, 8)

                sectionDivider

                if let usage = state.usageData {
                    usageSection(usage)
                } else if let error = state.lastError {
                    errorSection(error)
                        .padding(.vertical, 8)
                } else {
                    loadingSection
                }

                sectionDivider

                actionLinksSection
                    .padding(.vertical, 8)

                sectionDivider

                footerSection
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(bgGradient)
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Claude")
                    .font(.system(size: 16, weight: .bold))

                if let usage = state.usageData {
                    Text("Updated \(usage.fetchedAt, style: .relative) ago")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                } else if state.isRefreshing {
                    Text("Updating...")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if state.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task { await state.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .buttonStyle(.borderless)
                .disabled(state.isRefreshing)

                if let plan = state.usageData?.planInfo {
                    Text(plan.tier.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tierColor(plan.tier).opacity(0.2))
                        .foregroundStyle(tierColor(plan.tier))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Usage

    @ViewBuilder
    private func usageSection(_ usage: UsageData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if usage.session.isAvailable {
                UsageRowView(
                    title: "Session",
                    window: usage.session,
                    showRemaining: state.showRemaining
                )
            }

            if usage.weekly.isAvailable {
                UsageRowView(
                    title: "Weekly",
                    window: usage.weekly,
                    showRemaining: state.showRemaining
                )
            }

            if let opus = usage.opusWeekly, opus.isAvailable {
                UsageRowView(
                    title: "Opus",
                    window: opus,
                    showRemaining: state.showRemaining
                )
            }

            if let sonnet = usage.sonnetWeekly, sonnet.isAvailable {
                UsageRowView(
                    title: "Sonnet",
                    window: sonnet,
                    showRemaining: state.showRemaining
                )
            }
        }
        .padding(.vertical, 8)

        if let extra = usage.extraUsage {
            sectionDivider
            extraUsageSection(extra)
                .padding(.vertical, 8)
        }

        if let error = state.lastError {
            errorSection(error)
                .padding(.top, 4)
        }
    }

    // MARK: - Extra Usage

    private func extraUsageSection(_ extra: ExtraUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extra usage")
                .font(.system(size: 14, weight: .semibold))

            GeometryReader { geo in
                let percent = extra.limitCents > 0
                    ? min(1.0, Double(extra.spentCents) / Double(extra.limitCents))
                    : 0.0
                let fillWidth = max(0, geo.size.width * percent)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: fillWidth)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, fillWidth - 4))
                }
            }
            .frame(height: 4)

            HStack {
                Text(String(
                    format: "This month: $ %.2f / $ %.2f",
                    extra.spentDollars,
                    extra.limitDollars
                ))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.7))

                Spacer()

                if extra.limitCents > 0 {
                    let pct = Int(Double(extra.spentCents) / Double(extra.limitCents) * 100)
                    Text("\(pct)% used")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Error

    private func errorSection(_ error: UsageError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 11))
            Text(error.localizedDescription)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Loading

    private var loadingSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Fetching usage data...")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Action Links

    private var actionLinksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            linkButton(
                icon: "chart.bar",
                label: "Usage Dashboard",
                url: "https://claude.ai/settings/usage"
            )
            linkButton(
                icon: "bolt.horizontal",
                label: "Status Page",
                url: "https://status.anthropic.com"
            )
        }
    }

    private func linkButton(icon: String, label: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.primary.opacity(0.7))
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Settings...")
                        .font(.system(size: 12))
                    Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.primary.opacity(0.7))
            }
            .buttonStyle(.borderless)

            if showSettings {
                settingsSection
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack {
                Text("AI Usage Bar v1.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.35))
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.6))
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Show remaining")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                Toggle("", isOn: $state.showRemaining)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack {
                Text("Refresh")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                Picker("", selection: $state.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 120)
            }

            HStack {
                Text("Source")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                Picker("", selection: $state.preferredSource) {
                    ForEach(PreferredSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 120)
            }
        }
    }

    // MARK: - Helpers

    private func tierColor(_ tier: PlanInfo.PlanTier) -> Color {
        switch tier {
        case .free: .gray
        case .pro: .blue
        case .max: .purple
        case .team: .green
        case .enterprise: .orange
        case .unknown: .gray
        }
    }
}
