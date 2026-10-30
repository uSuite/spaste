import Testing
@testable import SPasteCore

struct BrowserTests {
    let items = [
        Clock.item("0", .text, "deploy script", minutesAgo: 1),
        Clock.item("1", .image, "", minutesAgo: 5),
        Clock.item("2", .text, "invoice 42", minutesAgo: 30),
        Clock.item("3", .file, "invoice.pdf", minutesAgo: 90),
        Clock.item("4", .text, "invoice 7", minutesAgo: 60 * 30),
    ]

    private func browser() -> Browser {
        Browser(
            items: items,
            now: { Clock.now },
            calendar: Clock.calendar
        )
    }

    @discardableResult
    private func run(
        _ browser: inout Browser,
        _ command: Command,
        count: Int? = nil
    ) -> [Browser.Effect] {
        browser.perform(Invocation(command, count: count))
    }

    @Test func movesWithCountsAndClamps() {
        var b = browser()
        run(&b, .down, count: 3)
        #expect(b.selected?.id == "3")
        run(&b, .down, count: 9)
        #expect(b.selected?.id == "4")
        run(&b, .up)
        #expect(b.selected?.id == "3")
        run(&b, .first)
        #expect(b.selected?.id == "0")
        run(&b, .last)
        #expect(b.selected?.id == "4")
        run(&b, .first, count: 2)
        #expect(b.selected?.id == "1")
        b.pageSize = 4
        run(&b, .halfDown)
        #expect(b.selected?.id == "3")
    }

    @Test func slashSearchesFromTheNewest() {
        var b = browser()
        run(&b, .last)
        run(&b, .searchForward)
        #expect(b.mode == .search(.down, ""))
        b.updateSearch("inv")
        #expect(b.selected?.id == "2")
        b.commitSearch()
        #expect(b.mode == .normal)
        #expect(b.message == nil)
        run(&b, .searchNext)
        #expect(b.selected?.id == "3")
        run(&b, .searchNext, count: 2)
        #expect(b.selected?.id == "2")
        run(&b, .searchPrevious)
        #expect(b.selected?.id == "4")
    }

    @Test func questionMarkSearchesFromTheOldest() {
        var b = browser()
        run(&b, .searchBackward)
        b.updateSearch("invoice")
        #expect(b.selected?.id == "4")
        b.commitSearch()
        run(&b, .searchNext)
        #expect(b.selected?.id == "3")
    }

    @Test func escapeRestoresSelectionAndFilter() {
        var b = browser()
        run(&b, .down)
        run(&b, .searchForward)
        b.updateSearch("type:text invoice")
        #expect(b.visible.map(\.id) == ["0", "2", "4"])
        #expect(b.selected?.id == "2")
        b.cancel()
        #expect(b.mode == .normal)
        #expect(b.visible.count == 5)
        #expect(b.selected?.id == "1")
    }

    @Test func searchTokensStayAsTheFilter() {
        var b = browser()
        run(&b, .searchForward)
        b.updateSearch("since:1h type:text")
        b.commitSearch()
        #expect(b.filter == Filter(kinds: [.text], since: .ago(minutes: 60)))
        #expect(b.visible.map(\.id) == ["0", "2"])
        run(&b, .searchNext)
        #expect(b.message == "no previous search")
    }

    @Test func missingSearchSaysSo() {
        var b = browser()
        run(&b, .down)
        run(&b, .searchForward)
        b.updateSearch("nothing")
        #expect(b.selected?.id == "1")
        b.commitSearch()
        #expect(b.message == "not found: nothing")
    }

    @Test func filtersNarrowAndReset() {
        var b = browser()
        run(&b, .down, count: 2)
        run(&b, .type([.text]))
        #expect(b.visible.map(\.id) == ["0", "2", "4"])
        #expect(b.selection == 0)
        run(&b, .since(.ago(minutes: 60)))
        #expect(b.visible.map(\.id) == ["0", "2"])
        run(&b, .type([]))
        run(&b, .until(.ago(minutes: 10)))
        #expect(b.visible.map(\.id) == ["2"])
        run(&b, .clear)
        #expect(b.visible.count == 5)
    }

    @Test func emptyFilterResultHasNoSelection() {
        var b = browser()
        run(&b, .since(.ago(minutes: 2)))
        run(&b, .type([.file]))
        #expect(b.visible.isEmpty)
        #expect(b.selected == nil)
        #expect(run(&b, .choose).isEmpty)
        #expect(run(&b, .delete).isEmpty)
    }

    @Test func itemEffects() {
        var b = browser()
        run(&b, .down)
        #expect(run(&b, .choose) == [.copy(items[1]), .close])
        #expect(run(&b, .pin) == [.setPinned(items[1], true)])
        #expect(run(&b, .delete, count: 2) == [.delete(items[1]), .delete(items[2])])
        #expect(run(&b, .wipe(confirmed: false)).isEmpty)
        #expect(b.message?.hasPrefix("use :wipe!") == true)
        #expect(run(&b, .wipe(confirmed: true)) == [.wipe])
        #expect(run(&b, .pause) == [.togglePause])
        #expect(run(&b, .close) == [.close])
    }

    @Test func commandLineRunsCommands() {
        var b = browser()
        run(&b, .commandLine)
        #expect(b.mode == .commandLine(""))
        b.updateCommandLine("type image")
        #expect(b.commitCommandLine().isEmpty)
        #expect(b.visible.map(\.id) == ["1"])
        run(&b, .commandLine)
        b.updateCommandLine("q")
        #expect(b.commitCommandLine() == [.close])
        run(&b, .commandLine)
        b.updateCommandLine("fly")
        #expect(b.commitCommandLine().isEmpty)
        #expect(b.message == "unknown command 'fly'")
        run(&b, .commandLine)
        b.cancel()
        #expect(b.mode == .normal)
    }

    @Test func selectClamps() {
        var b = browser()
        b.select(3)
        #expect(b.selected?.id == "3")
        b.select(99)
        #expect(b.selected?.id == "4")
        b.select(-1)
        #expect(b.selected?.id == "0")
    }

    @Test func replaceKeepsTheSelectedItem() {
        var b = browser()
        run(&b, .down, count: 2)
        let newer = Clock.item("n", .text, "new", minutesAgo: 0)
        b.replace([newer] + items)
        #expect(b.selected?.id == "2")
        b.replace(items.filter { $0.id != "2" })
        #expect(b.selection == 0)
        b.reopen()
        #expect(b.selected?.id == "0")
    }
}
