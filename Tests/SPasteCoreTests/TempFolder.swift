import Foundation
@testable import SPasteCore

/// A throwaway directory under the system temp folder, removed on deinit.
final class TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spaste-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var history: URL { url.appendingPathComponent("history", isDirectory: true) }

    func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: history.path).sorted()
    }
}

/// A fixed calendar and clock, so ids and filters do not depend on the
/// machine's time zone.
enum Clock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
        return calendar
    }()

    /// 2026-10-30 10:00:00 in that zone.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10))!

    static func ago(_ minutes: Double) -> Date {
        now.addingTimeInterval(-minutes * 60)
    }

    static func item(
        _ id: String,
        _ kind: ClipKind = .text,
        _ preview: String = "",
        minutesAgo: Double = 0
    ) -> ClipItem {
        ClipItem(
            id: id,
            kind: kind,
            created: ago(minutesAgo),
            digest: id,
            preview: preview
        )
    }
}

