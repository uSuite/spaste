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

struct ConfigTextTests {
    @Test func textRoundTripsEveryKey() throws {
        var config = Config()
        config.hotkey = Hotkey(key: "v", modifiers: [.control, .option])
        config.maxItems = 42
        config.pasteOnEnter = true
        for key in Config.keys {
            var copy = Config()
            try copy.set(key, try #require(config.text(for: key)))
            #expect(copy.text(for: key) == config.text(for: key), "\(key)")
        }
        #expect(config.text(for: "ignore_app") == nil)
        #expect(Config().values(for: "ignore_app") == [])
        #expect(Config().values(for: "hotkey") == nil)
    }

    @Test func listLinesReplaceInPlace() {
        let text = "# ignore_app com.example\nmax_items 50\nignore_app a\npoll_ms 250\nignore_app b\n"
        let updated = Config.setting(list: "ignore_app", to: ["x", "y"], in: text)
        #expect(updated == "# ignore_app com.example\nmax_items 50\nignore_app x\nignore_app y\npoll_ms 250\n")
        #expect(Config.parse(updated).config.ignoreApps == ["x", "y"])
        let cleared = Config.setting(list: "ignore_app", to: [], in: text)
        #expect(cleared == "# ignore_app com.example\nmax_items 50\npoll_ms 250\n")
    }

    @Test func listLinesAppendWhenAbsent() {
        let updated = Config.setting(list: "ignore_type", to: ["t.one"], in: "max_items 50\n")
        #expect(updated == "max_items 50\nignore_type t.one\n")
        #expect(Config.setting(list: "ignore_type", to: ["t"], in: Config.defaultText).hasSuffix("ignore_type t\n"))
    }

    @Test func archiveChecksBothFiles() {
        #expect(ConfigArchive.spaste.fileNames == ["config", "keymap"])
        #expect(ConfigArchive.spasteIssues(name: "config", text: Config.defaultText).isEmpty)
        #expect(ConfigArchive.spasteIssues(name: "config", text: "colour red").count == 1)
        #expect(ConfigArchive.spasteIssues(name: "keymap", text: "zz fly").count == 1)
    }
}
