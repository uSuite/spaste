import Carbon.HIToolbox
import SPasteCore

/// The global hotkey, through Carbon's `RegisterEventHotKey`: no permission
/// needed, and the key reaches sPaste whichever app is in front.
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private(set) var registered: Hotkey?

    private static let codes: [String: Int] = {
        var codes: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
            "]": kVK_ANSI_RightBracket, ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
            ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
            "\\": kVK_ANSI_Backslash, "`": kVK_ANSI_Grave,
        ]
        for (code, name) in KeyTranslator.named where codes[name] == nil {
            codes[name] = Int(code)
        }
        codes["space"] = kVK_Space
        return codes
    }()

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else {
                    return noErr
                }
                let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async {
                    hotKey.action()
                }
                return noErr
            },
            1,
            &spec,
            context,
            &handler
        )
    }

    /// Registers `hotkey` in place of the current one; false when macOS
    /// refuses it or the key has no code.
    @discardableResult
    func register(_ hotkey: Hotkey) -> Bool {
        if hotkey == registered {
            return true
        }
        unregister()
        guard let code = Self.codes[hotkey.key] else {
            return false
        }
        var modifiers = 0
        if hotkey.modifiers.contains(.command) {
            modifiers |= cmdKey
        }
        if hotkey.modifiers.contains(.shift) {
            modifiers |= shiftKey
        }
        if hotkey.modifiers.contains(.option) {
            modifiers |= optionKey
        }
        if hotkey.modifiers.contains(.control) {
            modifiers |= controlKey
        }
        let status = RegisterEventHotKey(
            UInt32(code),
            UInt32(modifiers),
            EventHotKeyID(signature: OSType(0x7350_7374), id: 1),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else {
            reference = nil
            return false
        }
        registered = hotkey
        return true
    }

    func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        reference = nil
        registered = nil
    }
}
