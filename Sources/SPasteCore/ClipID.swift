import Foundation

/// Item ids: `yyyy-MM-dd-HHmmss-nnn` in local time, so names sort in copy
/// order and say when the copy was made; `nnn` separates copies within one
/// second.
public enum ClipID {
    public static func make(
        at date: Date,
        taken: Set<String>,
        calendar: Calendar
    ) -> String {
        let c = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let stem = String(
            format: "%04d-%02d-%02d-%02d%02d%02d",
            c.year ?? 0,
            c.month ?? 0,
            c.day ?? 0,
            c.hour ?? 0,
            c.minute ?? 0,
            c.second ?? 0
        )
        var counter = 1
        while taken.contains(String(format: "%@-%03d", stem, counter)), counter < 999 {
            counter += 1
        }
        return String(format: "%@-%03d", stem, counter)
    }

    /// The date an id names, nil when the text is not an id.
    public static func date(
        of id: String,
        calendar: Calendar
    ) -> Date? {
        let parts = id.split(separator: "-")
        guard parts.count == 5,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[2].count == 2,
            parts[3].count == 6,
            parts[4].count == 3,
            parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) })
        else {
            return nil
        }
        let time = Array(parts[3])
        var components = DateComponents()
        components.year = Int(parts[0])
        components.month = Int(parts[1])
        components.day = Int(parts[2])
        components.hour = Int(String(time[0...1]))
        components.minute = Int(String(time[2...3]))
        components.second = Int(String(time[4...5]))
        guard components.isValidDate(in: calendar) else {
            return nil
        }
        return calendar.date(from: components)
    }
}
