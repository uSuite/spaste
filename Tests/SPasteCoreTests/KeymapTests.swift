import Testing
@testable import SPasteCore

struct KeymapTests {
    @Test func defaultsParseCleanly() {
        let parsed = Keymap.parse(Keymap.defaultText)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.keymap == Keymap.default)
        #expect(Keymap.default.command(for: [Key("/")]) == .searchForward)
        #expect(Keymap.default.command(for: [Key("?")]) == .searchBackward)
        #expect(Keymap.default.command(for: [Key("enter")]) == .choose)
        #expect(Keymap.default.command(for: [Key("d", modifiers: .control)]) == .halfDown)
    }

    @Test func sequencesAndCounts() {
        var matcher = KeyMatcher(keymap: .default)
        #expect(matcher.feed(Key("5")) == .pending(display: "5"))
        #expect(matcher.feed(Key("j")) == .matched(Invocation(.down, count: 5)))
        #expect(matcher.feed(Key("g")) == .pending(display: "g"))
        #expect(matcher.feed(Key("g")) == .matched(Invocation(.first)))
        #expect(matcher.feed(Key("f")) == .pending(display: "f"))
        #expect(matcher.feed(Key("i")) == .matched(Invocation(.type([.image]))))
        #expect(matcher.feed(Key("3")) == .pending(display: "3"))
        #expect(matcher.feed(Key("d")) == .pending(display: "3d"))
        #expect(matcher.feed(Key("d")) == .matched(Invocation(.delete, count: 3)))
    }

    @Test func userLinesApplyOverDefaults() {
        let parsed = Keymap.overlaid("x delete\ndd nop\nzz fly\n")
        #expect(parsed.keymap.command(for: [Key("x")]) == .delete)
        #expect(parsed.keymap.command(for: [Key("d"), Key("d")]) == nil)
        #expect(parsed.keymap.command(for: [Key("j")]) == .down)
        #expect(parsed.issues.map(\.line) == [3])
    }
}
