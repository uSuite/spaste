import AppKit
import SPasteCore

/// Maps an `NSEvent` key press to the keymap's `Key`: printed characters
/// keep their case (so shift is implied), named keys keep modifiers. The
/// same mapping as sView's.
enum KeyTranslator {
    static let named: [UInt16: String] = [
        49: "space",
        36: "enter",
        76: "enter",
        48: "tab",
        53: "esc",
        51: "backspace",
        117: "delete",
        123: "left",
        124: "right",
        125: "down",
        126: "up",
        115: "home",
        119: "end",
        116: "pageup",
        121: "pagedown",
        122: "f1",
        120: "f2",
        99: "f3",
        118: "f4",
        96: "f5",
        97: "f6",
        98: "f7",
        100: "f8",
        101: "f9",
        109: "f10",
        103: "f11",
        111: "f12",
    ]

    static func key(for event: NSEvent) -> Key? {
        var modifiers: Key.Modifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if let name = named[event.keyCode] {
            return Key(name, modifiers: modifiers)
        }
        // With control or command, use the unmodified character (ctrl-d is
        // "d", not a control code); otherwise the printed one, so option
        // combinations that print a character bind as that character.
        let source = modifiers.isDisjoint(with: [.control, .command])
            ? event.characters
            : event.charactersIgnoringModifiers
        guard let text = source, text.count == 1, let character = text.first, !character.isNewline else {
            return nil
        }
        if modifiers.isDisjoint(with: [.control, .command]) {
            modifiers.remove(.option)
        }
        return Key(String(character), modifiers: modifiers)
    }
}
