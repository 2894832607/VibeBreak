import SwiftUI
import VibeBreakCore

/*
 THESIS: One quiet control surface for exact agent lifecycle actions; it refuses
 dashboard density and decorative cards.
 OWN-WORLD: Native macOS forms, system symbols, restrained semantic color, and
 standard spacing.
 STORY: Confirm the source, choose start and completion actions, then verify them.
 FIRST VIEWPORT: Two native tabs; Automation opens directly on the enabled state,
 source health, and both application choices.
 FORM: Operate-mode macOS settings utility, code-led native composition.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the
 finish review, the verdict, and DESIGN.md
*/

struct SettingsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        TabView {
            AutomationSettingsView(model: model)
                .tabItem {
                    Label("自动化", systemImage: "arrow.left.arrow.right")
                }

            DiagnosticsView(model: model)
                .tabItem {
                    Label("诊断", systemImage: "waveform.path.ecg")
                }
        }
        .frame(width: 610, height: 520)
    }
}

private struct AutomationSettingsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Form {
            Section {
                Toggle("启用自动切换", isOn: model.enabled)

                LabeledContent("来源状态") {
                    HStack(spacing: 7) {
                        StatusDot(health: model.sourceHealth)
                        Text(model.healthDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("自动化")
            }

            Section("事件来源") {
                ForEach(model.sourceDescriptors) { descriptor in
                    SourceToggleRow(
                        descriptor: descriptor,
                        isOn: model.sourceEnabled(descriptor.id),
                        health: model.sourceHealth(for: descriptor.id),
                        integrationStatus: model.integrationStatus(
                            for: descriptor.id
                        ),
                        isOperating: model.integrationOperationSourceID
                            == descriptor.id,
                        onInstall: {
                            model.installIntegration(for: descriptor.id)
                        },
                        onUninstall: {
                            model.uninstallIntegration(for: descriptor.id)
                        }
                    )
                }
            }

            Section {
                ApplicationPicker(
                    title: "任务开始时",
                    selection: model.startApplication,
                    applications: model.applications,
                    isRefreshing: model.isRefreshingApplications
                )

                Picker("任务完成时", selection: model.completionAction) {
                    Text("打开应用").tag(CompletionAction.openApplication)
                    Text("恢复原应用").tag(
                        CompletionAction.restorePreviousApplication
                    )
                    Text("保持当前应用").tag(CompletionAction.stay)
                }
                .pickerStyle(.segmented)

                if model.settings.completionAction == .openApplication {
                    ApplicationPicker(
                        title: "完成后打开",
                        selection: model.completionApplication,
                        applications: model.applications,
                        isRefreshing: model.isRefreshingApplications
                    )
                }
            } header: {
                Text("应用动作")
            }

            Section {
                HStack {
                    Button {
                        model.testStartAction()
                    } label: {
                        Label("测试开始动作", systemImage: "play.fill")
                    }
                    .disabled(!model.startApplicationIsAvailable)

                    Button {
                        model.testCompletionAction()
                    } label: {
                        Label("测试完成动作", systemImage: "return")
                    }
                    .disabled(
                        model.settings.completionAction != .openApplication
                            || !model.completionApplicationIsAvailable
                    )

                    Spacer()

                    Button {
                        model.refreshApplications()
                    } label: {
                        Label("刷新应用", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshingApplications)
                }
            }

            if let warning = model.configurationWarning {
                Section {
                    IssueRow(message: warning, canDismiss: false) {}
                }
            }

            if let error = model.lastError {
                Section {
                    IssueRow(message: error, canDismiss: true) {
                        model.clearError()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Form {
            Section("运行状态") {
                ForEach(model.sourceDescriptors) { descriptor in
                    SourceStatusRow(
                        descriptor: descriptor,
                        isEnabled: model.settings.sourceIsEnabled(descriptor.id),
                        health: model.sourceHealth(for: descriptor.id),
                        integrationStatus: model.integrationStatus(
                            for: descriptor.id
                        )
                    )
                }

                LabeledContent("活跃任务") {
                    Text(model.activeTaskCount, format: .number)
                        .monospacedDigit()
                }

                LabeledContent("最近事件") {
                    Text(model.lastEventDescription)
                }
            }

            Section("本地数据") {
                PathRow(title: "Codex 数据库", path: model.sourceDatabaseURL.path)
                PathRow(title: "Bridge 事件", path: model.bridgeEventURL.path)
                PathRow(title: "诊断日志", path: model.diagnosticLogURL.path)
            }

            Section {
                HStack {
                    Button {
                        model.openDiagnosticLog()
                    } label: {
                        Label("打开日志", systemImage: "doc.text")
                    }

                    Button {
                        model.copyDiagnostics()
                    } label: {
                        Label("复制诊断信息", systemImage: "doc.on.doc")
                    }
                    Spacer()
                }
            }

            Section("隐私") {
                Text("所有检测和应用切换均在本机完成。VibeBreak 不上传日志，也不保存消息内容。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

private struct SourceToggleRow: View {
    let descriptor: AgentSourceDescriptor
    @Binding var isOn: Bool
    let health: SourceHealth
    let integrationStatus: AgentIntegrationStatus
    let isOperating: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                    Text(descriptor.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(integrationStatus == .notInstalled)

            Spacer(minLength: 12)

            if isOperating {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在更新 \(descriptor.name) 接入")
            } else {
                integrationControl
            }
        }
    }

    @ViewBuilder
    private var integrationControl: some View {
        switch integrationStatus {
        case .builtIn:
            SourceHealthLabel(health: isOn ? health : .stopped)
        case .installed:
            Menu {
                Button("移除接入", role: .destructive, action: onUninstall)
            } label: {
                Label("已接入", systemImage: "checkmark.circle.fill")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        case .updateAvailable:
            Button(action: onInstall) {
                Label("更新接入", systemImage: "arrow.down.circle")
            }
            .controlSize(.small)
        case .notInstalled:
            Button(action: onInstall) {
                Label("安装接入", systemImage: "link.badge.plus")
            }
            .controlSize(.small)
        case .manual:
            Text("手动接入")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SourceStatusRow: View {
    let descriptor: AgentSourceDescriptor
    let isEnabled: Bool
    let health: SourceHealth
    let integrationStatus: AgentIntegrationStatus

    var body: some View {
        LabeledContent(descriptor.name) {
            HStack(spacing: 7) {
                StatusDot(health: isEnabled ? health : .stopped)
                Text(statusDescription)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusDescription: String {
        guard isEnabled else { return "未启用" }
        switch integrationStatus {
        case .notInstalled:
            return "未安装接入"
        case .manual:
            return "Bridge 监听中，等待外部事件"
        case .updateAvailable:
            return "接入可更新"
        case .builtIn, .installed:
            return healthDescription(health)
        }
    }
}

private struct SourceHealthLabel: View {
    let health: SourceHealth

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(health: health)
            Text(healthDescription(health))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }
}

private struct ApplicationPicker: View {
    let title: String
    @Binding var selection: String
    let applications: [ApplicationChoice]
    let isRefreshing: Bool

    var body: some View {
        HStack {
            Picker(title, selection: $selection) {
                if selection.isEmpty {
                    Text("选择应用…").tag("")
                } else if !applications.contains(where: {
                    $0.bundleIdentifier == selection
                }) {
                    Label(
                        "\(selection)（不可用）",
                        systemImage: "exclamationmark.triangle"
                    )
                    .tag(selection)
                }

                ForEach(applications) { application in
                    HStack {
                        Image(nsImage: application.icon)
                            .accessibilityHidden(true)
                        Text(application.name)
                    }
                    .tag(application.bundleIdentifier)
                }
            }
            .accessibilityLabel(title)

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在刷新应用列表")
            }
        }
    }
}

private struct IssueRow: View {
    let message: String
    let canDismiss: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(.red)
                .textSelection(.enabled)
            Spacer()
            if canDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭错误")
                .accessibilityLabel("关闭错误")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StatusDot: View {
    let health: SourceHealth

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch health {
        case .monitoring:
            return .green
        case .connecting:
            return .orange
        case .failed, .incompatible:
            return .red
        case .stopped:
            return .secondary
        }
    }
}

private func healthDescription(_ health: SourceHealth) -> String {
    switch health {
    case .stopped:
        return "已停止"
    case .connecting:
        return "正在连接"
    case .monitoring:
        return "正在监听"
    case .incompatible:
        return "不兼容"
    case .failed:
        return "连接失败"
    }
}

private struct PathRow: View {
    let title: String
    let path: String

    var body: some View {
        LabeledContent(title) {
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(path)
                .textSelection(.enabled)
        }
    }
}
