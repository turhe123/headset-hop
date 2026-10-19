import AppKit
import Carbon
import SwiftUI

/// Click-to-record shortcut field. Esc cancels; a modifier (⌘, ⌥ or ⌃) is required.
struct HotKeyRecorder: View {
    @EnvironmentObject private var model: AppModel
    @Binding var favorite: Favorite
    var error: String?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Button(title) { recording ? stop() : start() }
                    .frame(minWidth: 130)
                if favorite.keyCode != nil && !recording {
                    Button {
                        favorite.keyCode = nil
                        favorite.keyLabel = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear shortcut")
                }
            }
            if let error, !recording {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear { stop() }
    }

    private var title: String {
        if recording { return "Type shortcut…" }
        return favorite.keyCode == nil ? "Record Shortcut" : favorite.keyLabel
    }

    private func start() {
        recording = true
        model.hotkeysPaused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.subtracting(.shift).isEmpty else {
                NSSound.beep()
                return nil
            }
            favorite.keyCode = UInt32(event.keyCode)
            favorite.modifiers = Self.carbonModifiers(flags)
            favorite.keyLabel = Self.label(flags: flags, event: event)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording {
            recording = false
            model.hotkeysPaused = false
        }
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }

    private static func label(flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
                                      kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
                                      kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
                                      kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
                                      kVK_F11: "F11", kVK_F12: "F12"]
        if let name = special[Int(event.keyCode)] {
            text += name
        } else if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty,
                  chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
            text += chars
        } else {
            text += "Key \(event.keyCode)"
        }
        return text
    }
}
