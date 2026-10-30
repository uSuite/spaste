import Foundation

/// The age column of a row: `now`, `5m`, `3h`, `2d`, then the date.
public enum RelativeTime {
    public static func label(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "now"
        case ..<3600:
            return "\(seconds / 60)m"
        case ..<86_400:
            return "\(seconds / 3600)h"
        case ..<604_800:
            return "\(seconds / 86_400)d"
        default:
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
    }
}
