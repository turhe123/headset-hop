import SwiftUI
import AppKit

/// App entry point: a menu bar extra for quick toggling plus a Settings window.
@main
struct HeadsetHopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.anyFavoriteConnected ? "headphones.circle.fill" : "headphones")
                .accessibilityLabel("HeadsetHop")
        }
        .menuBarExtraStyle(.window)

        Window("HeadsetHop Settings", id: "settings") {
            SettingsView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}

/// Starts Bluetooth observation and hotkeys once AppKit has finished launching.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }
}

/// Shared external links used across the UI.
enum Links {
    static let donate = URL(string: "https://ko-fi.com/leodavidai")!
    static let github = URL(string: "https://github.com/turhe123/headset-hop")!
    static let bluetoothSettings = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!
    static let bluetoothPrivacy = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!

    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
