import SwiftUI
import AppKit

struct KextStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var monitoring = HardwareMonitoringState.shared
    @ObservedObject private var logs = AppLogStore.shared
    @AppStorage("appLanguage") private var language = "system"

    private var title: String {
        switch monitoring.driverStatus {
        case .connected: L10n.text("Kext 已连接")
        case .disconnected: L10n.text("Kext 未连接")
        case nil: L10n.text("正在检查 Kext")
        }
    }

    private var details: String {
        switch monitoring.driverStatus {
        case .connected(let version): "AsusACPIService · \(L10n.pair("协议版本", "\(version)"))"
        case .disconnected(let error): error
        case nil: L10n.text("正在读取驱动状态")
        }
    }

    private var statusColor: Color {
        switch monitoring.driverStatus {
        case .connected: .green
        case .disconnected: .red
        case nil: .secondary
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 32))
                .foregroundStyle(statusColor)

            Text(title)
                .font(.headline)

            Text(details)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                ScrollView {
                    Text(logs.entries.isEmpty ? L10n.text("暂无日志") : logs.entries.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 100)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button(L10n.text("复制错误信息")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(title)\n\(details)\n\n\(logs.entries.joined(separator: "\n"))", forType: .string)
                }
                Spacer()
                Button(L10n.text("确认")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 360)
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
