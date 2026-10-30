import Testing
@testable import SPasteCore

struct ConfigTests {
    @Test func defaultTextIsTheDefaults() {
        let parsed = Config.parse(Config.defaultText)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.config == Config())
    }

    @Test func readsEveryKey() {
        let text = """
            hotkey ctrl-alt-v
            max_items 50
            max_image_mb 5
            poll_ms 250
            paste_on_enter yes
            ignore_app com.example.vault
            ignore_app com.example.other
            ignore_type com.agilebits.onepassword
            """
        let parsed = Config.parse(text)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.config.hotkey == Hotkey(key: "v", modifiers: [.control, .option]))
        #expect(parsed.config.maxItems == 50)
        #expect(parsed.config.maxImageMB == 5)
        #expect(parsed.config.pollMilliseconds == 250)
        #expect(parsed.config.pasteOnEnter)
        #expect(parsed.config.ignoreApps == ["com.example.vault", "com.example.other"])
        #expect(parsed.config.ignoreTypes == ["com.agilebits.onepassword"])
    }

    @Test func badLinesKeepDefaults() {
        let parsed = Config.parse("max_items 3\nhotkey c\npaste_on_enter maybe\ncolour red\nignore_app\n")
        #expect(parsed.config == Config())
        #expect(parsed.issues.map(\.line) == [1, 2, 3, 4, 5])
        #expect(parsed.issues[3].message == "unknown option 'colour'")
    }

    @Test func hotkeys() {
        #expect(Hotkey.parse("shift-cmd-c") == Hotkey.default)
        #expect(Hotkey.parse("cmd-C") == Hotkey.default)
        #expect(Hotkey.parse("CMD-shift-c") == Hotkey.default)
        #expect(Hotkey.parse("f5") == Hotkey(key: "f5", modifiers: []))
        #expect(Hotkey.parse("ctrl-space") == Hotkey(key: "space", modifiers: [.control]))
        #expect(Hotkey.parse("cmd--") == Hotkey(key: "-", modifiers: [.command]))
        for bad in ["c", "shift-c", "space", "hyper-c", "cmd-", "cmd-enterx", ""] {
            #expect(Hotkey.parse(bad) == nil, "\(bad)")
        }
        #expect(Hotkey.default.description == "cmd-shift-c")
    }
}
