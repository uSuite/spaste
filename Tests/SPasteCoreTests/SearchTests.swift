import Testing
@testable import SPasteCore

struct SearchTests {
    let items = [
        Clock.item("0", .text, "deploy script"),
        Clock.item("1", .text, "Invoice 42"),
        Clock.item("2", .file, "report.pdf"),
        Clock.item("3", .text, "invoice 7"),
    ]

    @Test func smartcase() {
        #expect(Search.matches(items[1], "invoice"))
        #expect(Search.matches(items[3], "invoice"))
        #expect(Search.matches(items[1], "Invoice"))
        #expect(!Search.matches(items[3], "Invoice"))
        #expect(!Search.matches(items[0], ""))
    }

    @Test func downStartsAtTheNewest() {
        #expect(Search.find("invoice", in: items, from: 0, direction: .down, includingStart: true) == 1)
        #expect(Search.find("deploy", in: items, from: 0, direction: .down, includingStart: true) == 0)
    }

    @Test func upStartsAtTheOldest() {
        #expect(Search.find("invoice", in: items, from: 3, direction: .up, includingStart: true) == 3)
        #expect(Search.find("invoice", in: items, from: 3, direction: .up, includingStart: false) == 1)
    }

    @Test func wrapsRoundTheList() {
        #expect(Search.find("invoice", in: items, from: 3, direction: .down, includingStart: false) == 1)
        #expect(Search.find("deploy", in: items, from: 0, direction: .up, includingStart: false) == 0)
        #expect(Search.find("nothing", in: items, from: 0, direction: .down, includingStart: true) == nil)
        #expect(Search.find("x", in: [], from: 0, direction: .down, includingStart: true) == nil)
    }
}
