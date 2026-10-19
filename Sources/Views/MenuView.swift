import SwiftUI
import AppKit

/// Menu bar popover: device list with status dots and favorite stars, plus footer actions.
struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HeadsetHop").font(.headline)
            content
            Divider()
            HStack {
                Button("Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            Button {
                Links.openDonate()
            } label: {
                Text("Support / Donate ❤️").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { model.refresh() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .denied:
            NoticeView(icon: "lock.shield",
                       text: "HeadsetHop doesn't have Bluetooth access. Turn it on in System Settings › Privacy & Security › Bluetooth.",
                       buttonTitle: "Open Privacy Settings", url: Links.bluetoothPrivacy)
        case .poweredOff:
            NoticeView(icon: "bolt.horizontal.circle",
                       text: "Bluetooth is turned off.",
                       buttonTitle: "Open Bluetooth Settings", url: Links.bluetoothSettings)
        case .ready where model.devices.isEmpty:
            NoticeView(icon: "headphones",
                       text: "No paired audio devices. Pair a device in System Settings first.",
                       buttonTitle: "Open Bluetooth Settings", url: Links.bluetoothSettings)
        case .ready:
            VStack(spacing: 2) {
                ForEach(model.devices) { DeviceRow(device: $0) }
            }
        }
    }
}

/// One clickable device row: status dot, name, progress while busy, and a favorite star.
private struct DeviceRow: View {
    @EnvironmentObject private var model: AppModel
    let device: AudioDevice
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(device.isConnected ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(device.name).lineLimit(1)
            Spacer()
            if model.busy.contains(device.id) {
                ProgressView().controlSize(.small)
            }
            Button {
                model.toggleFavorite(device)
            } label: {
                Image(systemName: model.isFavorite(device.id) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(device.id) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(model.isFavorite(device.id) ? "Remove from favorites" : "Add to favorites")
            .disabled(!model.isFavorite(device.id) && model.favorites.count >= AppModel.maxFavorites)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.toggle(device.id) }
        .help(device.isConnected ? "Click to disconnect" : "Click to connect")
    }
}

/// Explanatory banner with a button that opens the relevant System Settings pane.
struct NoticeView: View {
    let icon: String
    let text: String
    let buttonTitle: String
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(text, systemImage: icon)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle) { NSWorkspace.shared.open(url) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
