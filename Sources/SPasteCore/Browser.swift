import Foundation

/// The panel's state: the items, the filter, the selection and the mode. It
/// is the only place commands turn into changes; what needs the disk, the
/// pasteboard or the window comes back as `Effect`s for the app to carry
/// out.
public struct Browser: Sendable {
    public enum Mode: Sendable, Equatable {
        case normal
        /// Typing a search; the text excludes the `/` or `?`.
        case search(SearchDirection, String)
        /// Typing after `:`.
        case commandLine(String)
    }

    public enum Effect: Sendable, Equatable {
        case copy(ClipItem)
        case close
        case delete(ClipItem)
        case setPinned(ClipItem, Bool)
        case wipe
        case togglePause
    }

    /// Newest first, unfiltered.
    public private(set) var all: [ClipItem]
    public private(set) var filter = Filter()
    public private(set) var visible: [ClipItem] = []
    /// Index into `visible`; 0 when it is empty.
    public private(set) var selection = 0
    public private(set) var mode = Mode.normal
    /// One line for the status bar, cleared by the next command.
    public var message: String?
    /// Rows on screen, for half-page moves.
    public var pageSize = 10

    private var lastSearch: (text: String, direction: SearchDirection)?
    private var searchOrigin: String?
    private var filterBeforeSearch = Filter()
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        items: [ClipItem],
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        all = items
        self.now = now
        self.calendar = calendar
        refilter(keeping: nil)
    }

    public var selected: ClipItem? { visible.indices.contains(selection) ? visible[selection] : nil }

    /// New items from the store; the selection stays on the same item when
    /// it is still shown.
    public mutating func replace(_ items: [ClipItem]) {
        let id = selected?.id
        all = items
        refilter(keeping: id)
    }

    /// The panel opened: back to the newest item in normal mode, filter kept.
    public mutating func reopen() {
        mode = .normal
        message = nil
        refilter(keeping: nil)
    }

    public mutating func perform(_ invocation: Invocation<Command>) -> [Effect] {
        message = nil
        let times = invocation.times
        switch invocation.command {
        case .down:
            move(by: times)
        case .up:
            move(by: -times)
        case .halfDown:
            move(by: times * max(1, pageSize / 2))
        case .halfUp:
            move(by: -times * max(1, pageSize / 2))
        case .first:
            select(invocation.count.map { $0 - 1 } ?? 0)
        case .last:
            select(invocation.count.map { $0 - 1 } ?? visible.count - 1)
        case .searchForward:
            beginSearch(.down)
        case .searchBackward:
            beginSearch(.up)
        case .searchNext:
            repeatSearch(times: times, reversed: false)
        case .searchPrevious:
            repeatSearch(times: times, reversed: true)
        case .choose:
            guard let item = selected else {
                return []
            }
            return [.copy(item), .close]
        case .pin:
            guard let item = selected else {
                return []
            }
            return [.setPinned(item, !item.pinned)]
        case .delete:
            return visible.dropFirst(selection).prefix(times).map { .delete($0) }
        case .wipe(let confirmed):
            guard confirmed else {
                message = "use :wipe! to delete the whole history, pinned items included"
                return []
            }
            return [.wipe]
        case .type(let kinds):
            filter.kinds = kinds
            refilter(keeping: nil)
        case .since(let spec):
            filter.since = spec
            refilter(keeping: nil)
        case .until(let spec):
            filter.until = spec
            refilter(keeping: nil)
        case .clear:
            filter = Filter()
            refilter(keeping: nil)
        case .commandLine:
            mode = .commandLine("")
        case .close:
            return [.close]
        case .pause:
            return [.togglePause]
        }
        return []
    }

    // MARK: search

    private mutating func beginSearch(_ direction: SearchDirection) {
        searchOrigin = selected?.id
        filterBeforeSearch = filter
        mode = .search(direction, "")
    }

    /// The search line changed: filter tokens apply at once and the
    /// selection moves to the first match (vim's incsearch).
    public mutating func updateSearch(_ text: String) {
        guard case .search(let direction, _) = mode else {
            return
        }
        mode = .search(direction, text)
        let query = Query.parse(text, over: filterBeforeSearch)
        if query.filter != filter {
            filter = query.filter
            refilter(keeping: searchOrigin)
        }
        let start = direction == .down ? 0 : visible.count - 1
        if let found = Search.find(query.text, in: visible, from: start, direction: direction, includingStart: true) {
            selection = found
        } else {
            select(visible.firstIndex { $0.id == searchOrigin } ?? 0)
        }
    }

    /// Enter on the search line: keep the match, remember the search for
    /// `n` and `N`.
    public mutating func commitSearch() {
        guard case .search(let direction, let text) = mode else {
            return
        }
        mode = .normal
        let query = Query.parse(text, over: filterBeforeSearch)
        guard !query.text.isEmpty else {
            return
        }
        lastSearch = (query.text, direction)
        if !visible.indices.contains(selection) || !Search.matches(visible[selection], query.text) {
            message = "not found: \(query.text)"
        }
    }

    private mutating func repeatSearch(
        times: Int,
        reversed: Bool
    ) {
        guard let lastSearch else {
            message = "no previous search"
            return
        }
        let direction = reversed ? lastSearch.direction.reversed : lastSearch.direction
        for _ in 0..<times {
            guard let found = Search.find(lastSearch.text, in: visible, from: selection, direction: direction, includingStart: false) else {
                message = "not found: \(lastSearch.text)"
                return
            }
            selection = found
        }
    }

    // MARK: command line

    public mutating func updateCommandLine(_ text: String) {
        guard case .commandLine = mode else {
            return
        }
        mode = .commandLine(text)
    }

    /// Enter on the `:` line: run what it says.
    public mutating func commitCommandLine() -> [Effect] {
        guard case .commandLine(let text) = mode else {
            return []
        }
        mode = .normal
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        do {
            let command = try Command.parseCommandLine(text)
            return perform(Invocation(command))
        } catch {
            message = error.description
            return []
        }
    }

    /// Esc while typing: leave the line; a search also puts back the filter
    /// and the selection it started from.
    public mutating func cancel() {
        if case .search = mode {
            filter = filterBeforeSearch
            refilter(keeping: searchOrigin)
        }
        mode = .normal
    }

    // MARK: selection

    private mutating func move(by offset: Int) {
        select(selection + offset)
    }

    private mutating func select(_ index: Int) {
        selection = max(0, min(index, visible.count - 1))
    }

    private mutating func refilter(keeping id: String?) {
        let now = now()
        visible = filter.isEmpty ? all : all.filter { filter.matches($0, now: now, calendar: calendar) }
        select(id.flatMap { id in visible.firstIndex { $0.id == id } } ?? 0)
    }
}
