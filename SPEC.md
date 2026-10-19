# HeadsetHop — specification

**Tagline:** Connect or disconnect your paired Bluetooth headphones and speakers from the menu bar with one click or hotkey.

**Category:** Audio

**Inspired by (paid):** ToothFairy ($6.99 one-time)

**Frameworks:** SwiftUI, AppKit, IOBluetooth, ServiceManagement, Carbon

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: ToothFairy sits in the menu bar and lets you connect or disconnect a paired Bluetooth audio device, especially AirPods, in a single click, with a per-device global hotkey. It is sold on the Mac App Store for 6.99 dollars one-time and is also part of the Setapp catalog, and it has been covered repeatedly by Mac news sites over several years, which shows steady demand because the built-in Bluetooth menu takes several clicks to reconnect a headset. Our clean-room version, HeadsetHop, reproduces only that core idea.

Feature set: list every paired Bluetooth device that exposes an audio profile, show a connected or disconnected dot, toggle the connection on click, assign an optional global hotkey to each of up to five favorite devices, show a brief on-screen confirmation when a connection succeeds or fails, and optionally set the connected device as the system output after it connects. Also include an option to disconnect a device automatically when the Mac goes to sleep, and an option to start at login. This fits within roughly 350 to 450 lines of Swift.

UI spec: a MenuBarExtra with window style content or a simple menu. The menu lists paired devices, each row has a name, a battery-free status dot, and a small star button to mark favorites. A footer has Settings and Quit. The menu bar icon is a headphone symbol that is filled when any favorite is connected and outlined otherwise. A Settings window has three sections: Favorites (up to five rows with a device picker and a hotkey recorder field), Behavior (switch output after connecting, disconnect on sleep, show confirmation toast, launch at login) and About. Empty state: if no paired audio devices exist, show a message that says to pair a device in System Settings first, with a button that opens the Bluetooth pane. Keyboard: each favorite has its own recorded shortcut, and the menu itself opens with the pointer.

Technical approach: use IOBluetooth. IOBluetoothDevice.pairedDevices returns the paired list, isConnected reports state, and openConnection or closeConnection performs the change. Run connection calls off the main thread because openConnection can block for several seconds, then publish results back to an observable model. Observe connect and disconnect notifications through IOBluetoothDevice.register(forConnectNotifications) so the UI stays in sync when a device connects from elsewhere. To make the connected device the system output, use CoreAudio property calls (kAudioHardwarePropertyDefaultOutputDevice) after matching the device by name or address in the audio device list, retrying for a couple of seconds because the audio device appears slightly after the link is up. Global hotkeys use the Carbon RegisterEventHotKey API, which needs no special permission. Bluetooth access requires the NSBluetoothAlwaysUsageDescription key and the user approves a [removed] on first use. Persist favorites as an array of device address strings plus hotkey codes in UserDefaults through AppStorage with JSON encoding. Launch at login uses SMAppService.mainApp register and unregister, and the toggle reflects the real status.

Edge cases: a device that is out of range makes openConnection fail, so show a failure toast and leave state unchanged. A device that is connected to another Apple device may need a retry, so offer one automatic retry. If Bluetooth is off, show a banner with a link to settings instead of an empty list. Handle devices whose names change by keying on the hardware address. If the hotkey conflicts with another registration, show a message in the recorder field. If permission is denied, explain how to re-enable it in Privacy settings. Device lists refresh when the menu opens and when the system posts a Bluetooth change, so they never go stale for long.
