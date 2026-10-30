import Foundation
import Testing
@testable import SPasteCore

struct HistoryStoreTests {
    private func store(_ folder: TempFolder) throws -> HistoryStore {
        let store = HistoryStore(directory: folder.history, calendar: Clock.calendar)
        try store.load()
        return store
    }

    @Test func foldersAreOwnerOnly() throws {
        let folder = try TempFolder()
        _ = try store(folder)
        let mode = try FileManager.default.attributesOfItem(atPath: folder.history.path)[.posixPermissions] as? Int
        #expect(mode == 0o700)
    }

    @Test func roundTripsEveryKind() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let text = ClipContent.text("hello world", rtf: Data("{\\rtf1 hello}".utf8))
        let image = ClipContent.image(Data([0x89, 0x50, 0x4e, 0x47]), type: .png)
        let files = ClipContent.files(["/tmp/a b.txt", "/tmp/c.png"])
        let t = try store.add(text, app: "com.apple.TextEdit", at: Clock.ago(3))
        let i = try store.add(image, app: nil, at: Clock.ago(2))
        let f = try store.add(files, app: "com.apple.finder", at: Clock.ago(1))
        #expect(store.items.map(\.id) == [f.id, i.id, t.id])
        #expect(t.id == "2026-10-30-095700-001")
        #expect(f.preview == "a b.txt  c.png")
        #expect(try folder.names() == [
            "2026-10-30-095700-001.rtf",
            "2026-10-30-095700-001.txt",
            "2026-10-30-095800-001.png",
            "2026-10-30-095900-001.files",
            "index",
        ])
        let reloaded = HistoryStore(directory: folder.history, calendar: Clock.calendar)
        try reloaded.load()
        #expect(reloaded.items == store.items)
        #expect(try reloaded.content(of: reloaded.items[2]) == text)
        #expect(try reloaded.content(of: reloaded.items[1]) == image)
        #expect(try reloaded.content(of: reloaded.items[0]) == files)
    }

    @Test func sameSecondGetsNextCounter() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let a = try store.add(.text("a", rtf: nil), app: nil, at: Clock.now)
        let b = try store.add(.text("b", rtf: nil), app: nil, at: Clock.now)
        #expect(a.id == "2026-10-30-100000-001")
        #expect(b.id == "2026-10-30-100000-002")
        #expect(store.items.first?.id == b.id)
    }

    @Test func copyingAgainMovesToTopAndKeepsPin() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let first = try store.add(.text("same", rtf: Data("r".utf8)), app: nil, at: Clock.ago(5))
        try store.setPinned(first.id, true)
        try store.add(.text("other", rtf: nil), app: nil, at: Clock.ago(4))
        let again = try store.add(.text("same", rtf: Data("r".utf8)), app: "com.x", at: Clock.ago(1))
        #expect(store.items.count == 2)
        #expect(store.items.first == again)
        #expect(again.pinned)
        #expect(again.app == "com.x")
        #expect(try folder.names().filter { $0.hasPrefix(first.id) }.isEmpty)
        #expect(try store.content(of: again) == .text("same", rtf: Data("r".utf8)))
    }

    @Test func deleteRemovesTheFiles() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let item = try store.add(.text("secret", rtf: Data("r".utf8)), app: nil, at: Clock.now)
        try store.delete(item.id)
        #expect(store.items.isEmpty)
        #expect(try folder.names() == ["index"])
        #expect(throws: HistoryStore.StoreError.unknownItem(item.id)) {
            try store.delete(item.id)
        }
    }

    @Test func pruneKeepsPinnedAndNewest() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        var ids: [String] = []
        for n in 0..<5 {
            ids.append(try store.add(.text("item \(n)", rtf: nil), app: nil, at: Clock.ago(Double(10 - n))).id)
        }
        try store.setPinned(ids[0], true)
        #expect(try store.prune(keeping: 2) == 2)
        #expect(store.items.map(\.id) == [ids[4], ids[3], ids[0]])
        #expect(try folder.names().count == 4)
        #expect(try store.prune(keeping: 2) == 0)
    }

    @Test func wipeDeletesEverything() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let item = try store.add(.text("a", rtf: nil), app: nil, at: Clock.now)
        try store.setPinned(item.id, true)
        try store.add(.image(Data([1]), type: .tiff), app: nil, at: Clock.now)
        try store.wipe()
        #expect(store.items.isEmpty)
        #expect(try folder.names() == ["index"])
    }

    @Test func lostIndexIsRebuiltFromTheFiles() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let item = try store.add(.text("keep me", rtf: nil), app: "com.x", at: Clock.now)
        try store.setPinned(item.id, true)
        try FileManager.default.removeItem(at: folder.history.appendingPathComponent("index"))
        let reloaded = HistoryStore(directory: folder.history, calendar: Clock.calendar)
        try reloaded.load()
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items[0].digest == item.digest)
        #expect(reloaded.items[0].preview == "keep me")
        #expect(reloaded.items[0].pinned == false)
        #expect(reloaded.items[0].app == nil)
        #expect(try folder.names().contains("index"))
    }

    @Test func strangeFilesAreIgnored() throws {
        let folder = try TempFolder()
        _ = try store(folder)
        try Data("x".utf8).write(to: folder.history.appendingPathComponent("notes.txt"))
        try Data("x".utf8).write(to: folder.history.appendingPathComponent("2026-10-30-100000-001.doc"))
        let reloaded = HistoryStore(directory: folder.history, calendar: Clock.calendar)
        try reloaded.load()
        #expect(reloaded.items.isEmpty)
    }

    @Test func imageURLOnlyForImages() throws {
        let folder = try TempFolder()
        let store = try store(folder)
        let image = try store.add(.image(Data([1]), type: .tiff), app: nil, at: Clock.now)
        let text = try store.add(.text("a", rtf: nil), app: nil, at: Clock.now)
        #expect(store.imageURL(of: image)?.lastPathComponent == "2026-10-30-100000-001.tiff")
        #expect(store.imageURL(of: text) == nil)
    }

    @Test func digestSeparatesKinds() {
        #expect(HistoryStore.digest(.text("a", rtf: nil)) == HistoryStore.digest(.text("a", rtf: Data("r".utf8))))
        #expect(HistoryStore.digest(.text("a", rtf: nil)) != HistoryStore.digest(.files(["a"])))
        #expect(HistoryStore.digest(.text("a", rtf: nil)).count == 32)
    }
}
