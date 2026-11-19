import SwiftUI
import AppKit
import MenuBarExtraAccess

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyMonitor = HotkeyMonitor.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["fnNotificationEnabled": true])
        hotkeyMonitor.start(requestPermission: true)
        HardwareMonitoringState.shared.start()
        AsusACPIController.readStartupInformation { mode in
            Task { @MainActor in PerformanceState.shared.initialize(hardwareMode: mode) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor.stop()
        HardwareMonitoringState.shared.stop()
    }
}

@main
struct RHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var menuPresentation = MenuPresentation.shared
    @AppStorage("appLanguage") private var language = "system"

    var body: some Scene {
        MenuBarExtra("R-Helper", image: "MenuBarIcon") {
            MenuView()
                .introspectMenuBarExtraWindow { window in
                    window.animationBehavior = .utilityWindow
                }
        }
        .menuBarExtraAccess(isPresented: $menuPresentation.isPresented) { _ in }
        .menuBarExtraStyle(.window)

        Window(L10n.text("Kext 状态"), id: "kextStatus") {
            KextStatusView()
        }
        .windowResizability(.contentSize)
    }
}
