import SwiftUI
import ServiceManagement

/// Settings window: favorites with hotkeys, behavior toggles, and About.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("switchOutput") private var switchOutput = false
    @AppStorage("disconnectOnSleep") private var disconnectOnSleep = false
    @AppStorage("showToast") private var showToast = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginMessage: String?

    var body: some View {
        Form {
            Section("Favorites") {
                if model.favorites.isEmpty {
                    Text("Star a device in the menu or add one here to give it a global shortcut.")
                        .foregroundStyle(.secondary)
                }
                ForEach($model.favorites) { $favorite in
                    HStack(alignment: .top) {
                        Picker("Device", selection: deviceBinding($favorite)) {
                            ForEach(model.devices) { Text($0.name).tag($0.id) }
                            if !model.devices.contains(where: { $0.id == favorite.address }) {
                                Text(favorite.name).tag(favorite.address)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        Spacer()
                        HotKeyRecorder(favorite: $favorite, error: model.hotkeyErrors[favorite.id])
                        Button {
                            model.favorites.removeAll { $0.id == favorite.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove favorite")
                    }
                }
                Button("Add Favorite") { model.addFavorite() }
                    .disabled(model.favorites.count >= AppModel.maxFavorites || model.devices.isEmpty)
            }

            Section("Behavior") {
                Toggle("Switch sound output after connecting", isOn: $switchOutput)
                Toggle("Disconnect devices when the Mac sleeps", isOn: $disconnectOnSleep)
                Toggle("Show confirmation toast", isOn: $showToast)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginMessage {
                    Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Text("Connect or disconnect your paired Bluetooth headphones and speakers from the menu bar with one click or hotkey. Free and open source (MIT).")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Support / Donate ❤️") { Links.openDonate() }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    Link("Source on GitHub", destination: Links.github)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 520)
        .onAppear {
            model.refresh()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func deviceBinding(_ favorite: Binding<Favorite>) -> Binding<String> {
        Binding(
            get: { favorite.wrappedValue.address },
            set: { address in
                favorite.wrappedValue.address = address
                favorite.wrappedValue.name = model.displayName(for: address)
            })
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled, service.status != .enabled { try service.register() }
            if !enabled, service.status == .enabled { try service.unregister() }
            loginMessage = service.status == .requiresApproval
                ? "Approve HeadsetHop in System Settings › General › Login Items." : nil
        } catch {
            loginMessage = "Couldn't update login item: \(error.localizedDescription)"
        }
        let actual = service.status == .enabled
        if actual != launchAtLogin { launchAtLogin = actual }
    }
}
