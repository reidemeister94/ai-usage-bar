import SwiftUI

struct UsagePanelView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            headerSection

            Divider()

            if let usage = state.usageData {
                usageSection(usage)
            } else if let error = state.lastError {
                errorSection(error)
            } else {
                loadingSection
            }

            Divider()

            settingsSection

            Divider()

            footerSection
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.system(size: 14, weight: .bold))
                if let plan = state.usageData?.planInfo {
                    HStack(spacing: 4) {
                        Text(plan.tier.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(tierColor(plan.tier).opacity(0.15))
                            .foregroundStyle(tierColor(plan.tier))
                            .clipShape(Capsule())
                        if let org = plan.orgName {
                            Text(org)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            if state.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Button(action: { Task { await state.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .disabled(state.isRefreshing)
        }
    }

    @ViewBuilder
    private func usageSection(_ usage: UsageData) -> some View {
        if usage.session.isAvailable {
            UsageRowView(title: "Session (5h)", window: usage.session, showRemaining: state.showRemaining)
        }

        if usage.weekly.isAvailable {
            UsageRowView(title: "Weekly (7d)", window: usage.weekly, showRemaining: state.showRemaining)
        }

        if let opus = usage.opusWeekly, opus.isAvailable {
            UsageRowView(title: "Opus Weekly", window: opus, showRemaining: state.showRemaining)
        }

        if let sonnet = usage.sonnetWeekly, sonnet.isAvailable {
            UsageRowView(title: "Sonnet Weekly", window: sonnet, showRemaining: state.showRemaining)
        }

        if let extra = usage.extraUsage {
            HStack {
                Text("Extra Usage")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "$%.2f / $%.2f", extra.spentDollars, extra.limitDollars))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }

        // Metadata
        HStack {
            Text("via \(usage.source.rawValue)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(usage.fetchedAt, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }

        if let error = state.lastError {
            errorSection(error)
        }
    }

    private func errorSection(_ error: UsageError) -> some View {
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
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

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

    private var settingsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Show remaining")
                    .font(.system(size: 11))
                Spacer()
                Toggle("", isOn: $state.showRemaining)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack {
                Text("Refresh")
                    .font(.system(size: 11))
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

    private var footerSection: some View {
        HStack {
            Text("AI Usage Bar v1.0")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
        }
    }

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
