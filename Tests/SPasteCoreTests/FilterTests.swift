import Foundation
import Testing
@testable import SPasteCore

struct FilterTests {
    @Test func parsesTimeSpecs() {
        #expect(TimeSpec.parse("30m") == .ago(minutes: 30))
        #expect(TimeSpec.parse("2h") == .ago(minutes: 120))
        #expect(TimeSpec.parse("3D") == .ago(minutes: 4320))
        #expect(TimeSpec.parse("1w") == .ago(minutes: 10080))
        #expect(TimeSpec.parse("Today") == .today)
        #expect(TimeSpec.parse("yesterday") == .yesterday)
        #expect(TimeSpec.parse("2026-10-29") == .day(year: 2026, month: 10, day: 29))
        for bad in ["", "h", "0h", "-2h", "2x", "2026-02-30", "26-10-29", "soon"] {
            #expect(TimeSpec.parse(bad) == nil, "\(bad)")
        }
    }

    @Test func describesSpecsInTheirLargestUnit() {
        #expect(TimeSpec.ago(minutes: 120).description == "2h")
        #expect(TimeSpec.ago(minutes: 90).description == "90m")
        #expect(TimeSpec.ago(minutes: 20160).description == "2w")
        #expect(TimeSpec.day(year: 2026, month: 1, day: 5).description == "2026-01-05")
    }

    @Test func daysAreSpans() {
        let cal = Clock.calendar
        let today = cal.startOfDay(for: Clock.now)
        #expect(TimeSpec.today.start(now: Clock.now, calendar: cal) == today)
        #expect(TimeSpec.today.end(now: Clock.now, calendar: cal) == today.addingTimeInterval(86_400))
        #expect(TimeSpec.yesterday.start(now: Clock.now, calendar: cal) == today.addingTimeInterval(-86_400))
        #expect(TimeSpec.yesterday.end(now: Clock.now, calendar: cal) == today)
        #expect(TimeSpec.ago(minutes: 60).end(now: Clock.now, calendar: cal) == Clock.ago(60))
    }

    @Test func matchesKindsAndTimes() {
        let cal = Clock.calendar
        let recentImage = Clock.item("a", .image, minutesAgo: 30)
        let oldText = Clock.item("b", .text, minutesAgo: 60 * 24 * 2)
        let images = Filter(kinds: [.image])
        #expect(images.matches(recentImage, now: Clock.now, calendar: cal))
        #expect(!images.matches(oldText, now: Clock.now, calendar: cal))
        let lastHour = Filter(since: .ago(minutes: 60))
        #expect(lastHour.matches(recentImage, now: Clock.now, calendar: cal))
        #expect(!lastHour.matches(oldText, now: Clock.now, calendar: cal))
        let beforeToday = Filter(until: .yesterday)
        #expect(!beforeToday.matches(recentImage, now: Clock.now, calendar: cal))
        #expect(beforeToday.matches(oldText, now: Clock.now, calendar: cal))
        #expect(Filter().isEmpty)
        #expect(Filter(kinds: [.file, .image], since: .ago(minutes: 120)).description == "image file since 2h")
    }

    @Test func queryTakesFilterTokens() {
        let query = Query.parse("invoice type:image since:1h  total", over: Filter())
        #expect(query.text == "invoice total")
        #expect(query.filter == Filter(kinds: [.image], since: .ago(minutes: 60)))
    }

    @Test func typeTokensAddUpAndReplaceTheBase() {
        let base = Filter(kinds: [.text], until: .today)
        let query = Query.parse("type:image type:files", over: base)
        #expect(query.filter == Filter(kinds: [.image, .file], until: .today))
        #expect(Query.parse("type:all", over: base).filter.kinds.isEmpty)
        #expect(Query.parse("type:image,text x", over: Filter()).filter.kinds == [.image, .text])
    }

    @Test func halfTypedTokensStaySearchText() {
        let query = Query.parse("type:fi since:2 until:", over: Filter())
        #expect(query.text == "type:fi since:2 until:")
        #expect(query.filter.isEmpty)
    }

    @Test func relativeTimeLabels() {
        let cal = Clock.calendar
        #expect(RelativeTime.label(Clock.ago(0.5), now: Clock.now, calendar: cal) == "now")
        #expect(RelativeTime.label(Clock.ago(5), now: Clock.now, calendar: cal) == "5m")
        #expect(RelativeTime.label(Clock.ago(180), now: Clock.now, calendar: cal) == "3h")
        #expect(RelativeTime.label(Clock.ago(60 * 48), now: Clock.now, calendar: cal) == "2d")
        #expect(RelativeTime.label(Clock.ago(60 * 24 * 10), now: Clock.now, calendar: cal) == "2026-10-20")
    }

    @Test func clipIDs() {
        let cal = Clock.calendar
        let id = ClipID.make(at: Clock.now, taken: ["2026-10-30-100000-001"], calendar: cal)
        #expect(id == "2026-10-30-100000-002")
        #expect(ClipID.date(of: id, calendar: cal) == Clock.now)
        for bad in ["2026-10-30-100000", "2026-13-30-100000-001", "2026-10-30-1000a0-001", "index"] {
            #expect(ClipID.date(of: bad, calendar: cal) == nil, "\(bad)")
        }
    }
}
