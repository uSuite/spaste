import Foundation

/// Every user action. Keys, the menu, the `:` line and tests all speak this
/// vocabulary; each case has a kebab-case name used by the keymap file.
public enum Command: Sendable, Hashable {
    // Moving
    case down
    case up
    case halfDown
    case halfUp
    case first
    case last
    // Searching
    case searchForward
    case searchBackward
    case searchNext
    case searchPrevious
    // Items
    case choose
    case pin
    case delete
    case wipe(confirmed: Bool)
    // Filters; an empty set or nil clears that part
    case type(Set<ClipKind>)
    case since(TimeSpec?)
    case until(TimeSpec?)
    case clear
    // Panel and app
    case commandLine
    case close
    case pause
    case settings
    /// The config zip, at a path or (empty) dated on the Desktop.
    case export(String)

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case empty
        case unknown(String)
        case badArgument(command: String, reason: String)

        public var description: String {
            switch self {
            case .empty:
                return "no command"
            case .unknown(let name):
                return "unknown command '\(name)'"
            case .badArgument(let command, let reason):
                return "\(command) \(reason)"
            }
        }
    }

    private static let simple: [String: Command] = [
        "down": .down,
        "up": .up,
        "half-down": .halfDown,
        "half-up": .halfUp,
        "first": .first,
        "last": .last,
        "search-forward": .searchForward,
        "search-backward": .searchBackward,
        "search-next": .searchNext,
        "search-previous": .searchPrevious,
        "choose": .choose,
        "pin": .pin,
        "delete": .delete,
        "wipe": .wipe(confirmed: false),
        "wipe!": .wipe(confirmed: true),
        "clear": .clear,
        "command-line": .commandLine,
        "close": .close,
        "pause": .pause,
        "settings": .settings,
    ]

    /// Short names the `:` line also takes.
    private static let aliases: [String: String] = [
        "q": "close",
        "quit": "close",
    ]

    /// Every command name, for help and completion.
    public static let names: [String] = (Array(simple.keys) + ["type", "since", "until", "export"]).sorted()

    /// `name [args]` as the keymap file writes it.
    public static func parse(_ text: String) throws(ParseError) -> Command {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let name = String(trimmed.prefix { !$0.isWhitespace })
        let rest = trimmed.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            throw .empty
        }
        if let command = simple[name] {
            guard rest.isEmpty else {
                throw .badArgument(command: name, reason: "takes no argument")
            }
            return command
        }
        switch name {
        case "type":
            let words = rest.split(separator: " ").joined(separator: ",")
            guard let kinds = words.isEmpty ? [] : Query.kinds(words) else {
                throw .badArgument(command: name, reason: "takes text, image, file or all")
            }
            return .type(kinds)
        case "since", "until":
            var spec: TimeSpec?
            if !rest.isEmpty {
                guard let parsed = TimeSpec.parse(rest) else {
                    throw .badArgument(command: name, reason: "takes 30m, 2h, 3d, 1w, today, yesterday or a yyyy-mm-dd date")
                }
                spec = parsed
            }
            return name == "since" ? .since(spec) : .until(spec)
        case "export":
            return .export(rest)
        default:
            throw .unknown(name)
        }
    }

    /// A line typed after `:`, which also takes the aliases.
    public static func parseCommandLine(_ text: String) throws(ParseError) -> Command {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let name = String(trimmed.prefix { !$0.isWhitespace })
        if let alias = aliases[name] {
            return try parse(alias + trimmed.dropFirst(name.count))
        }
        return try parse(trimmed)
    }
}
