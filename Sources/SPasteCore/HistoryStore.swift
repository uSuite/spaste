import CryptoKit
import Foundation

/// The history folder: one file per item (two for text with rich text), an
/// `index` with one `<id> <app> <digest> [pin]` line per item, the folder
/// readable by its owner only. The file names alone rebuild everything but
/// the app and the pins, so a lost index costs little.
public final class HistoryStore {
    public enum StoreError: Error, Equatable, CustomStringConvertible {
        case unknownItem(String)
        case unreadable(String)

        public var description: String {
            switch self {
            case .unknownItem(let id):
                return "no item \(id)"
            case .unreadable(let id):
                return "cannot read item \(id)"
            }
        }
    }

    public let directory: URL
    /// Newest first.
    public private(set) var items: [ClipItem] = []
    private let calendar: Calendar
    private var extensions: [String: [String]] = [:]

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sPaste/history", isDirectory: true)
    }

    private static let itemExtensions: [String: ClipKind] = [
        "txt": .text,
        "png": .image,
        "tiff": .image,
        "files": .file,
    ]

    public init(
        directory: URL = HistoryStore.defaultDirectory,
        calendar: Calendar = .current
    ) {
        self.directory = directory
        self.calendar = calendar
    }

    private var indexURL: URL { directory.appendingPathComponent("index") }

    private func url(_ id: String, _ ext: String) -> URL {
        directory.appendingPathComponent("\(id).\(ext)")
    }

    /// Creates the folder (mode 0700) when missing and reads it.
    public func load() throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        var found: [String: [String]] = [:]
        for name in try manager.contentsOfDirectory(atPath: directory.path) {
            guard let dot = name.firstIndex(of: ".") else {
                continue
            }
            let id = String(name[..<dot])
            let ext = String(name[name.index(after: dot)...])
            guard ClipID.date(of: id, calendar: calendar) != nil else {
                continue
            }
            found[id, default: []].append(ext)
        }
        let index = readIndex()
        var loaded: [ClipItem] = []
        var rebuilt = false
        for (id, exts) in found {
            guard let created = ClipID.date(of: id, calendar: calendar),
                let kind = exts.lazy.compactMap({ Self.itemExtensions[$0] }).first
            else {
                continue
            }
            extensions[id] = exts
            let content = try? read(id, kind: kind, exts: exts)
            let entry = index[id]
            let digest = entry?.digest ?? content.map(Self.digest) ?? ""
            if entry == nil {
                rebuilt = true
            }
            loaded.append(
                ClipItem(
                    id: id,
                    kind: kind,
                    created: created,
                    app: entry?.app,
                    pinned: entry?.pinned ?? false,
                    digest: digest,
                    preview: content.map(Self.preview) ?? ""
                )
            )
        }
        items = loaded.sorted { $0.id > $1.id }
        if rebuilt || index.count != items.count {
            try writeIndex()
        }
    }

    /// Stores a copy, or moves an item with the same content to the top
    /// under a new id, keeping its pin.
    @discardableResult
    public func add(
        _ content: ClipContent,
        app: String?,
        at date: Date = Date()
    ) throws -> ClipItem {
        let digest = Self.digest(content)
        let id = ClipID.make(
            at: date,
            taken: Set(items.map(\.id)),
            calendar: calendar
        )
        let created = ClipID.date(of: id, calendar: calendar) ?? date
        var item = ClipItem(
            id: id,
            kind: content.kind,
            created: created,
            app: app,
            digest: digest,
            preview: Self.preview(content)
        )
        if let old = items.firstIndex(where: { $0.digest == digest && $0.kind == content.kind }) {
            let previous = items.remove(at: old)
            item.pinned = previous.pinned
            let exts = extensions.removeValue(forKey: previous.id) ?? []
            for ext in exts {
                try FileManager.default.moveItem(
                    at: url(previous.id, ext),
                    to: url(id, ext)
                )
            }
            extensions[id] = exts
        } else {
            extensions[id] = try write(content, id: id)
        }
        items.insert(item, at: 0)
        try writeIndex()
        return item
    }

    /// The stored content of an item, for copying it back.
    public func content(of item: ClipItem) throws -> ClipContent {
        guard let exts = extensions[item.id] else {
            throw StoreError.unknownItem(item.id)
        }
        return try read(item.id, kind: item.kind, exts: exts)
    }

    /// Deletes the item's files.
    public func delete(_ id: String) throws {
        guard let position = items.firstIndex(where: { $0.id == id }) else {
            throw StoreError.unknownItem(id)
        }
        removeFiles(id)
        items.remove(at: position)
        try writeIndex()
    }

    public func setPinned(
        _ id: String,
        _ pinned: Bool
    ) throws {
        guard let position = items.firstIndex(where: { $0.id == id }) else {
            throw StoreError.unknownItem(id)
        }
        items[position].pinned = pinned
        try writeIndex()
    }

    /// Deletes the oldest unpinned items until at most `maxItems` unpinned
    /// remain; returns how many went.
    @discardableResult
    public func prune(keeping maxItems: Int) throws -> Int {
        var unpinned = items.filter { !$0.pinned }.count
        var removed = 0
        for item in items.reversed() where unpinned > maxItems && !item.pinned {
            removeFiles(item.id)
            items.removeAll { $0.id == item.id }
            unpinned -= 1
            removed += 1
        }
        if removed > 0 {
            try writeIndex()
        }
        return removed
    }

    /// Deletes every item, pinned ones included.
    public func wipe() throws {
        for item in items {
            removeFiles(item.id)
        }
        items = []
        try writeIndex()
    }

    // MARK: files

    private func removeFiles(_ id: String) {
        for ext in extensions.removeValue(forKey: id) ?? [] {
            try? FileManager.default.removeItem(at: url(id, ext))
        }
    }

    private func write(
        _ content: ClipContent,
        id: String
    ) throws -> [String] {
        switch content {
        case .text(let text, let rtf):
            try Data(text.utf8).write(to: url(id, "txt"), options: .atomic)
            guard let rtf else {
                return ["txt"]
            }
            try rtf.write(to: url(id, "rtf"), options: .atomic)
            return ["txt", "rtf"]
        case .image(let data, let type):
            try data.write(to: url(id, type.rawValue), options: .atomic)
            return [type.rawValue]
        case .files(let paths):
            try Data((paths.joined(separator: "\n") + "\n").utf8).write(to: url(id, "files"), options: .atomic)
            return ["files"]
        }
    }

    private func read(
        _ id: String,
        kind: ClipKind,
        exts: [String]
    ) throws -> ClipContent {
        switch kind {
        case .text:
            let data = try Data(contentsOf: url(id, "txt"))
            let rtf = exts.contains("rtf") ? try? Data(contentsOf: url(id, "rtf")) : nil
            return .text(String(decoding: data, as: UTF8.self), rtf: rtf)
        case .image:
            guard let ext = exts.first(where: { ImageType(rawValue: $0) != nil }),
                let type = ImageType(rawValue: ext)
            else {
                throw StoreError.unreadable(id)
            }
            return .image(try Data(contentsOf: url(id, ext)), type: type)
        case .file:
            let text = try String(contentsOf: url(id, "files"), encoding: .utf8)
            return .files(text.split(separator: "\n").map(String.init))
        }
    }

    // MARK: index

    private struct IndexEntry {
        let app: String?
        let digest: String
        let pinned: Bool
    }

    private func readIndex() -> [String: IndexEntry] {
        guard let text = try? String(contentsOf: indexURL, encoding: .utf8) else {
            return [:]
        }
        var entries: [String: IndexEntry] = [:]
        for entry in KeyValueParser.parse(text) {
            let fields = entry.value.split(separator: " ").map(String.init)
            guard fields.count >= 2 else {
                continue
            }
            entries[entry.key] = IndexEntry(
                app: fields[0] == "-" ? nil : fields[0],
                digest: fields[1],
                pinned: fields.dropFirst(2).contains("pin")
            )
        }
        return entries
    }

    private func writeIndex() throws {
        var lines = ["# sPaste history index: <id> <app> <digest> [pin], newest first. Rebuilt from the files when lost."]
        for item in items {
            var line = "\(item.id) \(item.app ?? "-") \(item.digest)"
            if item.pinned {
                line += " pin"
            }
            lines.append(line)
        }
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: indexURL, options: .atomic)
    }

    // MARK: content

    /// SHA-256 of the kind and the main data, first 16 bytes in hex.
    public static func digest(_ content: ClipContent) -> String {
        var hash = SHA256()
        hash.update(data: Data(content.kind.rawValue.utf8))
        switch content {
        case .text(let text, _):
            hash.update(data: Data(text.utf8))
        case .image(let data, _):
            hash.update(data: data)
        case .files(let paths):
            hash.update(data: Data(paths.joined(separator: "\n").utf8))
        }
        return hash.finalize().prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public static func preview(_ content: ClipContent) -> String {
        switch content {
        case .text(let text, _):
            return String(text.prefix(ClipItem.previewLimit))
        case .image:
            return ""
        case .files(let paths):
            return paths.map { ($0 as NSString).lastPathComponent }.joined(separator: "  ")
        }
    }
}
