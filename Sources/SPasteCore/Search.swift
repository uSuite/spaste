import Foundation

/// Down goes from newer to older items, as `/` does; up the other way.
public enum SearchDirection: Sendable, Equatable {
    case down
    case up

    public var reversed: SearchDirection { self == .down ? .up : .down }
}

/// vim search over the panel's items: smartcase, wrapping.
public enum Search {
    /// Case-insensitive unless the needle has an upper-case letter.
    public static func matches(
        _ item: ClipItem,
        _ needle: String
    ) -> Bool {
        guard !needle.isEmpty else {
            return false
        }
        let caseSensitive = needle.contains { $0.isUppercase }
        return item.preview.range(
            of: needle,
            options: caseSensitive ? [] : [.caseInsensitive]
        ) != nil
    }

    /// The index of the first match from `start` in `direction`, wrapping
    /// once round the list; `start` itself is checked only when
    /// `includingStart`.
    public static func find(
        _ needle: String,
        in items: [ClipItem],
        from start: Int,
        direction: SearchDirection,
        includingStart: Bool
    ) -> Int? {
        let count = items.count
        guard count > 0, !needle.isEmpty else {
            return nil
        }
        let step = direction == .down ? 1 : -1
        let first = includingStart ? start : start + step
        for offset in 0..<count {
            let index = ((first + offset * step) % count + count) % count
            if matches(items[index], needle) {
                return index
            }
        }
        return nil
    }
}
