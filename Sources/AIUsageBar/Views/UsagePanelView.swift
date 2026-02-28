import SwiftUI

struct UsagePanelView: View {
    @Bindable var state: AppState
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.bottom, 12)

                if let usage = state.usageData {
                    usageSection(usage)
                } else if let error = state.lastError {
                    errorSection(error)
                        .padding(.bottom, 12)
                } else {
                    loadingSection
                }

                Divider()
                    .padding(.vertical, 8)

                actionLinksSection

                Divider()
                    .padding(.vertical, 8)

                footerSection
            }
            .padding(16)
        }
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude")
                    .font(.system(size: 15, weight: .semibold))

                if let usage = state.usageData {
                    Text(
                        "Updated \(usage.fetchedAt, style: .relative) ago"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                } else if state.isRefreshing {
                    Text("Updating...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await state.refresh() }
                } label: {
                    if state.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(state.isRefreshing)

                if let plan = state.usageData?.planInfo {
                    planBadge(plan.tier)
                }
            }
        }
    }

    private func planBadge(_ tier: PlanInfo.PlanTier) -> some View {
        Text(tier.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tierColor(tier))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tierColor(tier).opacity(0.12))
            )
    }

    // MARK: - Usage

    @ViewBuilder
    private func usageSection(_ usage: UsageData) -> some View {
        VStack(spacing: 2) {
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.bottom, 12)

        if let extra = usage.extraUsage {
            extraUsageSection(extra)
                .padding(.bottom, 12)
        }

        if let error = state.lastError {
            errorSection(error)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Extra Usage

    private func extraUsageSection(
        _ extra: ExtraUsage
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Extra usage")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if extra.limitCents > 0 {
                    let pct = Int(
                        Double(extra.spentCents)
                            / Double(extra.limitCents) * 100
                    )
                    Text("\(pct)%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                let percent = extra.limitCents > 0
                    ? min(
                        1.0,
                        Double(extra.spentCents)
                            / Double(extra.limitCents)
                    )
                    : 0.0
                let fillWidth = max(0, geo.size.width * percent)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 6)

            Text(String(
                format: "$%.2f / $%.2f this month",
                extra.spentDollars,
                extra.limitDollars
            ))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Error

    private func errorSection(
        _ error: UsageError
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 11))
            Text(error.localizedDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.08))
        )
    }

    // MARK: - Loading

    private var loadingSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Fetching usage data...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Action Links

    private var actionLinksSection: some View {
        VStack(alignment: .leading, spacing: 2) {
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

    private func linkButton(
        icon: String,
        label: String,
        url: String
    ) -> some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
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
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                    Text("Settings")
                        .font(.system(size: 12))
                    Image(
                        systemName: showSettings
                            ? "chevron.up" : "chevron.down"
                    )
                    .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            if showSettings {
                settingsSection
                    .padding(.top, 4)
                    .transition(
                        .opacity.combined(with: .move(edge: .top))
                    )
            }

            HStack {
                Text("AI Usage Bar v1.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Show remaining")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $state.showRemaining)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack {
                Text("Refresh")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $state.refreshInterval) {
                    ForEach(RefreshInterval.allCases) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 110)
            }

            HStack {
                Text("Source")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $state.preferredSource) {
                    ForEach(PreferredSource.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 110)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
