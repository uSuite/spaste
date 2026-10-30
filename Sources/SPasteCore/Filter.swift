import Foundation

/// A point in time as `:since` and `:until` write it: `30m`, `2h`, `3d`,
/// `1w`, `today`, `yesterday` or `2026-10-29`. A day is a span, so it
/// starts a `since` at its first second and ends an `until` at its last.
public enum TimeSpec: Sendable, Hashable, CustomStringConvertible {
    case ago(minutes: Int)
    case today
    case yesterday
    case day(year: Int, month: Int, day: Int)

    private static let units: [(Character, Int)] = [
        ("m", 1),
        ("h", 60),
        ("d", 1440),
        ("w", 10080),
    ]

    public static func parse(_ text: String) -> TimeSpec? {
        let lower = text.lowercased()
        switch lower {
        case "today":
            return .today
        case "yesterday":
            return .yesterday
        default:
            break
        }
        if let last = lower.last,
            let unit = units.first(where: { $0.0 == last }),
            let n = Int(lower.dropLast()),
            n > 0,
            n <= 1_000_000
        {
            return .ago(minutes: n * unit.1)
        }
        let parts = lower.split(separator: "-")
        guard parts.count == 3,
            parts[0].count == 4,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: Calendar(identifier: .gregorian)) else {
            return nil
        }
        return .day(year: year, month: month, day: day)
    }

    /// The first moment the spec names.
    public func start(
        now: Date,
        calendar: Calendar
    ) -> Date {
        switch self {
        case .ago(let minutes):
            return now.addingTimeInterval(-Double(minutes) * 60)
        case .today:
            return calendar.startOfDay(for: now)
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
        case .day(let year, let month, let day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? now
        }
    }

    /// The moment just after the span the spec names.
    public func end(
        now: Date,
        calendar: Calendar
    ) -> Date {
        switch self {
        case .ago:
            return start(now: now, calendar: calendar)
        case .today, .yesterday, .day:
            let first = start(now: now, calendar: calendar)
            return calendar.date(byAdding: .day, value: 1, to: first) ?? first
        }
    }

    public var description: String {
        switch self {
        case .ago(let minutes):
            for (unit, size) in Self.units.reversed() where minutes % size == 0 {
                return "\(minutes / size)\(unit)"
            }
            return "\(minutes)m"
        case .today:
            return "today"
        case .yesterday:
            return "yesterday"
        case .day(let year, let month, let day):
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }
}

/// What the panel shows: the kinds (none means all) and a time window.
public struct Filter: Sendable, Hashable, CustomStringConvertible {
    public var kinds: Set<ClipKind> = []
    public var since: TimeSpec?
    public var until: TimeSpec?

    public init(
        kinds: Set<ClipKind> = [],
        since: TimeSpec? = nil,
        until: TimeSpec? = nil
    ) {
        self.kinds = kinds
        self.since = since
        self.until = until
    }

    public var isEmpty: Bool { kinds.isEmpty && since == nil && until == nil }

    public func matches(
        _ item: ClipItem,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        if !kinds.isEmpty, !kinds.contains(item.kind) {
            return false
        }
        if let since, item.created < since.start(now: now, calendar: calendar) {
            return false
        }
        if let until, item.created >= until.end(now: now, calendar: calendar) {
            return false
        }
        return true
    }

    /// For the status line: `image file since 2h`.
    public var description: String {
        var parts = ClipKind.allCases.filter(kinds.contains).map(\.rawValue)
        if let since {
            parts.append("since \(since)")
        }
        if let until {
            parts.append("until \(until)")
        }
        return parts.joined(separator: " ")
    }
}

/// A search line split into filter tokens and the text to find.
public struct Query: Sendable, Equatable {
    public var filter: Filter
    public var text: String

    /// `type:image,file`, `since:2h` and `until:today` set fields over
    /// `base`; several `type:` tokens add up. A token that does not parse,
    /// such as a half-typed `type:fi`, stays part of the text.
    public static func parse(
        _ line: String,
        over base: Filter
    ) -> Query {
        var filter = base
        var typed = false
        var words: [Substring] = []
        for word in line.split(separator: " ") {
            let lower = word.lowercased()
            if lower.hasPrefix("type:"), let kinds = Self.kinds(String(lower.dropFirst(5))) {
                filter.kinds = (typed ? filter.kinds : []).union(kinds)
                typed = true
            } else if lower.hasPrefix("since:"), let spec = TimeSpec.parse(String(lower.dropFirst(6))) {
                filter.since = spec
            } else if lower.hasPrefix("until:"), let spec = TimeSpec.parse(String(lower.dropFirst(6))) {
                filter.until = spec
            } else {
                words.append(word)
            }
        }
        return Query(filter: filter, text: words.joined(separator: " "))
    }

    /// `all`, or kind words separated by commas; nil when one is unknown.
    static func kinds(_ text: String) -> Set<ClipKind>? {
        var kinds: Set<ClipKind> = []
        for word in text.split(separator: ",") {
            if word == "all" {
                continue
            }
            guard let kind = ClipKind.parse(String(word)) else {
                return nil
            }
            kinds.insert(kind)
        }
        return text.isEmpty ? nil : kinds
    }
}
