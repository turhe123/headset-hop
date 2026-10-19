import AppKit
import Carbon
import CoreBluetooth
import IOBluetooth

/// A paired Bluetooth device that exposes an audio profile, keyed by hardware address.
struct AudioDevice: Identifiable, Equatable {
    let id: String
    var name: String
    var isConnected: Bool
}

/// A favorite device with an optional Carbon global hotkey.
struct Favorite: Codable, Identifiable, Equatable {
    var id = UUID()
    var address: String
    var name: String
    var keyCode: UInt32?
    var modifiers: UInt32 = 0
    var keyLabel: String = ""
}

/// Overall availability of Bluetooth for the app.
enum BluetoothState {
    case ready, poweredOff, denied
}

/// Central observable model: lists paired audio devices, performs connections off the main
/// thread, keeps favorites and hotkeys in sync, and reacts to system Bluetooth and sleep events.
final class AppModel: NSObject, ObservableObject {
    static let shared = AppModel()
    static let maxFavorites = 5

    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var state: BluetoothState = .ready
    @Published private(set) var busy: Set<String> = []
    @Published private(set) var hotkeyErrors: [UUID: String] = [:]
    @Published var favorites: [Favorite] = [] {
        didSet { saveFavorites(); registerHotkeys() }
    }
    /// Suspends global hotkeys while the user records a new shortcut.
    var hotkeysPaused = false {
        didSet { registerHotkeys() }
    }

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var refreshTimer: Timer?
    private let defaults = UserDefaults.standard

    override init() {
        super.init()
        defaults.register(defaults: ["switchOutput": false, "disconnectOnSleep": false, "showToast": true])
        if let data = defaults.string(forKey: "favorites")?.data(using: .utf8),
           let saved = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = Array(saved.prefix(Self.maxFavorites))
        }
    }

    var anyFavoriteConnected: Bool {
        favorites.contains { fav in devices.contains { $0.id == fav.address && $0.isConnected } }
    }

    func isFavorite(_ id: String) -> Bool { favorites.contains { $0.address == id } }

    func displayName(for address: String) -> String {
        devices.first { $0.id == address }?.name ?? favorites.first { $0.address == address }?.name ?? address
    }

    // MARK: Lifecycle

    func start() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
        registerHotkeys()
    }

    /// Re-reads the paired device list, power state and permission status.
    func refresh() {
        let auth = CBManager.authorization
        if auth == .denied || auth == .restricted {
            state = .denied
            devices = []
            return
        }
        guard let host = IOBluetoothHostController.default(), host.powerState == kBluetoothHCIPowerStateON else {
            state = .poweredOff
            devices = []
            return
        }
        state = .ready
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let list = paired.filter(Self.isAudio).compactMap { device -> AudioDevice? in
            guard let raw = device.addressString else { return nil }
            let address = Self.normalize(raw)
            return AudioDevice(id: address, name: device.name ?? address, isConnected: device.isConnected())
        }
        devices = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Connections

    /// Connects a disconnected device or disconnects a connected one, without blocking the UI.
    func toggle(_ id: String) {
        refresh()
        guard let device = devices.first(where: { $0.id == id }) else {
            showToast("\(displayName(for: id)) isn't available", success: false)
            return
        }
        guard !busy.contains(id) else { return }
        busy.insert(id)
        let connect = !device.isConnected
        let switchOutput = defaults.bool(forKey: "switchOutput")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = Self.perform(address: id, connect: connect)
            DispatchQueue.main.async {
                self.busy.remove(id)
                self.refresh()
                let message = ok
                    ? "\(connect ? "Connected" : "Disconnected") \(device.name)"
                    : "Couldn't \(connect ? "connect" : "disconnect") \(device.name)"
                self.showToast(message, success: ok)
            }
            if ok && connect && switchOutput {
                AudioOutput.makeDefault(name: device.name, address: id)
            }
        }
    }

    /// Blocking IOBluetooth call; retries a connect once (devices busy with another Apple device).
    private static func perform(address: String, connect: Bool) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        if !connect {
            return device.closeConnection() == kIOReturnSuccess || !device.isConnected()
        }
        for attempt in 0..<2 {
            if device.openConnection() == kIOReturnSuccess || device.isConnected() { return true }
            if attempt == 0 { Thread.sleep(forTimeInterval: 1.5) }
        }
        return false
    }

    private func showToast(_ message: String, success: Bool) {
        guard defaults.bool(forKey: "showToast") else { return }
        Toast.show(message, success: success)
    }

    // MARK: Favorites & hotkeys

    func toggleFavorite(_ device: AudioDevice) {
        if let index = favorites.firstIndex(where: { $0.address == device.id }) {
            favorites.remove(at: index)
        } else if favorites.count < Self.maxFavorites {
            favorites.append(Favorite(address: device.id, name: device.name))
        }
    }

    func addFavorite() {
        guard favorites.count < Self.maxFavorites,
              let device = devices.first(where: { !isFavorite($0.id) }) ?? devices.first else { return }
        favorites.append(Favorite(address: device.id, name: device.name))
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites), let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: "favorites")
        }
    }

    private func registerHotkeys() {
        HotKeyCenter.shared.unregisterAll()
        guard !hotkeysPaused else { return }
        var errors: [UUID: String] = [:]
        for favorite in favorites {
            guard let keyCode = favorite.keyCode else { continue }
            let address = favorite.address
            let status = HotKeyCenter.shared.register(keyCode: keyCode, modifiers: favorite.modifiers) { [weak self] in
                self?.toggle(address)
            }
            if status != noErr {
                errors[favorite.id] = status == OSStatus(eventHotKeyExistsErr)
                    ? "Shortcut already in use" : "Couldn't register shortcut (\(status))"
            }
        }
        if errors != hotkeyErrors { hotkeyErrors = errors }
    }

    // MARK: System events

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let raw = device.addressString {
            disconnectNotifications[Self.normalize(raw)]?.unregister()
            disconnectNotifications[Self.normalize(raw)] = device.register(
                forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        }
        DispatchQueue.main.async { self.refresh() }
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        note.unregister()
        if let raw = device.addressString { disconnectNotifications[Self.normalize(raw)] = nil }
        DispatchQueue.main.async { self.refresh() }
    }

    @objc private func willSleep() {
        guard defaults.bool(forKey: "disconnectOnSleep") else { return }
        for device in devices where device.isConnected {
            _ = IOBluetoothDevice(addressString: device.id)?.closeConnection()
        }
    }

    // MARK: Helpers

    /// Audio major device class (0x04) or the "Audio" service-class bit (bit 21 of the CoD).
    private static func isAudio(_ device: IOBluetoothDevice) -> Bool {
        device.deviceClassMajor == 0x04 || (device.classOfDevice >> 21) & 1 == 1
    }

    static func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: ":", with: "-")
    }
}
