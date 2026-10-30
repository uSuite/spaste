import Foundation
import SCommon

/// How the Settings window writes the config file: one line per control,
/// through the same text `set` reads, so the file stays the truth and its
/// comments and layout survive.
extension Config {
    /// The single-value keys, in the order the default file lists them.
    public static let keys = [
        "hotkey",
        "max_items",
        "max_image_mb",
        "poll_ms",
        "paste_on_enter",
    ]

    /// The keys that repeat, one line per value.
    public static let listKeys = [
        "ignore_app",
        "ignore_type",
    ]

    /// The value of `key` as the config file writes it, so `set(key, text)`
    /// gives this config's value back; nil for a key not in `keys`.
    public func text(for key: String) -> String? {
        switch key {
        case "hotkey":
            return hotkey.description
        case "max_items":
            return String(maxItems)
        case "max_image_mb":
            return String(maxImageMB)
        case "poll_ms":
            return String(pollMilliseconds)
        case "paste_on_enter":
            return pasteOnEnter ? "yes" : "no"
        default:
            return nil
        }
    }

    /// The values of a repeating key; nil for a key not in `listKeys`.
    public func values(for key: String) -> [String]? {
        switch key {
        case "ignore_app":
            return ignoreApps
        case "ignore_type":
            return ignoreTypes
        default:
            return nil
        }
    }

    /// `text` with every active `key` line replaced by one line per value:
    /// the first one's place keeps them, the others go, and when there was
    /// none they are appended. Comments, including commented examples of
    /// the key, stay.
    public static func setting(
        list key: String,
        to values: [String],
        in text: String
    ) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let positions = lines.indices.filter { KeyValueParser.parse(lines[$0]).first?.key == key }
        let entries = values.map { "\(key) \($0)" }
        guard let first = positions.first else {
            if let last = lines.last, last.isEmpty {
                lines.removeLast()
            }
            return (lines + entries).joined(separator: "\n") + "\n"
        }
        for position in positions.reversed() {
            lines.remove(at: position)
        }
        lines.insert(contentsOf: entries, at: first)
        return lines.joined(separator: "\n")
    }
}

/// Export Config, `:export` and Import Config: config and keymap in one
/// `spaste/` folder of a zip. The history is data, never part of it.
extension ConfigArchive {
    public static let spaste = ConfigArchive(
        app: "spaste",
        fileNames: ["config", "keymap"]
    )

    /// The problems sPaste would report in a file a zip brings, as it
    /// reports them for the files on disk.
    @Sendable
    public static func spasteIssues(
        name: String,
        text: String
    ) -> [String] {
        name == "config"
            ? Config.parse(text).issues.map(\.description)
            : Keymap.overlaid(text).issues.map(\.description)
    }
}
