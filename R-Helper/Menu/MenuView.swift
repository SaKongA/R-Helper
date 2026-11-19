import SwiftUI
import ServiceManagement
import AppKit

struct MenuView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var performanceState = PerformanceState.shared
    @ObservedObject private var monitoring = HardwareMonitoringState.shared
    @AppStorage("fnNotificationEnabled") private var fnNotificationEnabled = true
    @AppStorage("appLanguage") private var language = "system"
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @ObservedObject private var hotkeyMonitor = HotkeyMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("R-Helper")
                    .font(.headline)
                Spacer()
                Button {
                    openWindow(id: "kextStatus")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(kextColor)
                        .frame(width: 16, height: 16)
                        .offset(y: -0)
                }
                .buttonStyle(.plain)
                .help(kextTitle)
                .accessibilityLabel(kextTitle)
                Link(destination: URL(string: "https://github.com/SaKongA/R-Helper")!) {
                    Image("GitHub")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .help(L10n.text("打开 GitHub"))
                .accessibilityLabel(L10n.text("打开 GitHub"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            HardwareMetricsView()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            Divider().padding(.horizontal, 10).padding(.vertical, 3)

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    ForEach(PerformanceMode.allCases) { mode in
                        MenuRow(L10n.text(mode.rawValue), isSelected: performanceState.mode == mode) {
                            performanceState.select(mode)
                        }
                        .disabled(performanceState.isApplying)
                    }
                }

                Image(systemName: performanceState.mode?.symbol ?? "xmark")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 90)
                    .accessibilityLabel(performanceState.mode.map { L10n.pair("当前模式", L10n.text($0.rawValue)) } ?? L10n.text("性能模式不可用"))
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 3)

            MenuRow(L10n.text("Fn 快捷键提示"), isSelected: fnNotificationEnabled) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    fnNotificationEnabled.toggle()
                }
            }

            LanguageMenuRow()

            if hotkeyMonitor.needsInputMonitoring {
                MenuRow(L10n.text("允许输入监控")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else if let error = hotkeyMonitor.openError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
            }

            MenuRow(L10n.text("登录时自动启动"), isSelected: loginStatus == .enabled) {
                do {
                    if loginStatus == .enabled || loginStatus == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    } else {
                        try SMAppService.mainApp.register()
                    }
                    loginError = nil
                } catch {
                    loginError = error.localizedDescription
                }
                withAnimation(.easeInOut(duration: 0.18)) {
                    loginStatus = SMAppService.mainApp.status
                }
            }

            if loginStatus == .requiresApproval {
                MenuRow(L10n.text("在系统设置中允许")) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 3)

            MenuRow(L10n.text("退出 R-Helper"), isLast: true) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .frame(width: 320)
        .alert(L10n.text("操作失败"), isPresented: Binding(
            get: { loginError != nil },
            set: { if !$0 { loginError = nil } }
        )) {
            Button(L10n.text("好"), role: .cancel) { loginError = nil }
        } message: {
            Text(loginError ?? L10n.text("未知错误"))
        }
        .onAppear {
            loginStatus = SMAppService.mainApp.status
            hotkeyMonitor.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
            hotkeyMonitor.start()
        }
    }

    private var kextTitle: String {
        switch monitoring.driverStatus {
        case .connected: L10n.text("Kext 已连接")
        case .disconnected: L10n.text("Kext 未连接")
        case nil: L10n.text("正在检查 Kext")
        }
    }

    private var kextColor: Color {
        switch monitoring.driverStatus {
        case .connected: .green
        case .disconnected: .red
        case nil: .secondary
        }
    }
}
