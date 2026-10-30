import AppKit
import ImageIO
import SPasteCore

/// A panel that takes keys without activating sPaste, so the app the user
/// came from stays in front and receives the paste.
final class HistoryPanel: NSPanel {
    var allowsKey = true

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}

/// The table hands every key to the controller instead of type-select.
final class KeyTableView: NSTableView {
    var onKey: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKey?(event) != true {
            super.keyDown(with: event)
        }
    }
}

/// One row: icon or thumbnail, the preview line, a pin, the age.
final class ClipRowView: NSTableCellView {
    let icon = NSImageView()
    let title = NSTextField(labelWithString: "")
    let age = NSTextField(labelWithString: "")
    let pin = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        title.lineBreakMode = .byTruncatingTail
        title.font = .systemFont(ofSize: 13)
        age.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        age.textColor = .secondaryLabelColor
        age.alignment = .right
        icon.imageScaling = .scaleProportionallyUpOrDown
        pin.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "pinned")
        pin.contentTintColor = .secondaryLabelColor
        for view in [icon, title, age, pin] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            pin.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 6),
            pin.centerYAnchor.constraint(equalTo: centerYAnchor),
            pin.widthAnchor.constraint(equalToConstant: 12),
            age.leadingAnchor.constraint(equalTo: pin.trailingAnchor, constant: 6),
            age.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            age.centerYAnchor.constraint(equalTo: centerYAnchor),
            age.widthAnchor.constraint(equalToConstant: 72),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

/// The history panel: a table over `Browser.visible`, a status line, and a
/// line for `/`, `?` and `:` input. Keys go through the keymap into
/// `Browser`; its effects go to `onEffects`.
final class PanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private let panel: HistoryPanel
    private let table = KeyTableView()
    private let scroll = NSScrollView()
    private let prompt = NSTextField(labelWithString: "")
    private let input = NSTextField()
    private let status = NSTextField(labelWithString: "")
    private let pending = NSTextField(labelWithString: "")
    private let store: HistoryStore
    private var browser: Browser
    private var matcher: KeyMatcher
    private var flushTimer: Timer?
    private var syncing = false
    private let thumbnails = NSCache<NSString, NSImage>()
    private var imageSizes: [String: String] = [:]
    private let rowHeight: CGFloat = 36

    var onEffects: ([Browser.Effect]) -> Void = { _ in }
    /// Extra words for the right of the status line, such as `paused`.
    var statusExtra: () -> String = { "" }

    var isVisible: Bool { panel.isVisible }
    /// Smoke runs keep the panel from becoming key, so keys typed in other
    /// apps meanwhile cannot reach it.
    var takesKeys = true {
        didSet {
            panel.allowsKey = takesKeys
        }
    }

    init(store: HistoryStore) {
        self.store = store
        browser = Browser(items: store.items)
        matcher = KeyMatcher(keymap: .default)
        panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init()
        build()
    }

    private func build() {
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: 360, height: 240)
        panel.delegate = self

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        panel.contentView = background

        let column = NSTableColumn(identifier: .init("clip"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = rowHeight
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.style = .plain
        table.allowsTypeSelect = false
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClicked)
        table.onKey = { [weak self] event in
            self?.handle(event) ?? false
        }
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        prompt.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        input.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        input.isBordered = false
        input.drawsBackground = false
        input.focusRingType = .none
        input.delegate = self
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        pending.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pending.textColor = .secondaryLabelColor
        pending.alignment = .right
        let divider = NSBox()
        divider.boxType = .separator

        for view in [scroll, divider, prompt, input, status, pending] {
            view.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(view)
        }
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: background.topAnchor, constant: 28),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: divider.topAnchor),
            divider.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -30),
            prompt.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            prompt.centerYAnchor.constraint(equalTo: background.bottomAnchor, constant: -15),
            input.leadingAnchor.constraint(equalTo: prompt.trailingAnchor, constant: 2),
            input.trailingAnchor.constraint(equalTo: pending.leadingAnchor, constant: -8),
            input.centerYAnchor.constraint(equalTo: prompt.centerYAnchor),
            status.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            status.trailingAnchor.constraint(equalTo: pending.leadingAnchor, constant: -8),
            status.centerYAnchor.constraint(equalTo: prompt.centerYAnchor),
            pending.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -10),
            pending.centerYAnchor.constraint(equalTo: prompt.centerYAnchor),
            pending.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
        thumbnails.countLimit = 200
    }

    // MARK: showing

    func toggle(
        keymap: Keymap,
        message: String?
    ) {
        if panel.isVisible {
            hide()
        } else {
            show(keymap: keymap, message: message)
        }
    }

    func show(
        keymap: Keymap,
        message: String?
    ) {
        matcher = KeyMatcher(keymap: keymap)
        browser.replace(store.items)
        browser.reopen()
        browser.message = message
        place()
        if takesKeys {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        panel.makeFirstResponder(table)
        sync()
    }

    func hide() {
        flushTimer?.invalidate()
        matcher.reset()
        panel.orderOut(nil)
    }

    /// The store changed: new copies, deletes, pins.
    func refresh() {
        browser.replace(store.items)
        if panel.isVisible {
            sync()
        }
    }

    func say(_ message: String) {
        browser.message = message
        if panel.isVisible {
            sync()
        }
    }

    private func place() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            return
        }
        let area = screen.visibleFrame
        var frame = panel.frame
        frame.size.width = min(frame.width, area.width - 40)
        frame.size.height = min(frame.height, area.height - 40)
        frame.origin.x = area.midX - frame.width / 2
        frame.origin.y = area.minY + (area.height - frame.height) * 0.6
        panel.setFrame(frame, display: false)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: keys

    private func handle(_ event: NSEvent) -> Bool {
        guard let key = KeyTranslator.key(for: event) else {
            return false
        }
        feed(key)
        return true
    }

    private func feed(_ key: Key) {
        flushTimer?.invalidate()
        switch matcher.feed(key) {
        case .matched(let invocation):
            run(invocation)
        case .pending:
            flushTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
                guard let self else {
                    return
                }
                if let invocation = self.matcher.flush() {
                    self.run(invocation)
                } else {
                    self.sync()
                }
            }
        case .unmatched:
            break
        }
        sync()
    }

    private func run(_ invocation: Invocation<Command>) {
        browser.pageSize = max(2, Int(scroll.contentSize.height / rowHeight))
        let effects = browser.perform(invocation)
        sync()
        onEffects(effects)
    }

    @objc private func doubleClicked() {
        guard table.clickedRow >= 0 else {
            return
        }
        browser.select(table.clickedRow)
        run(Invocation(.choose))
    }

    // MARK: the input line

    func controlTextDidChange(_ notification: Notification) {
        inputChanged()
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitInput()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancelInput()
            return true
        case #selector(NSResponder.deleteBackward(_:)) where input.stringValue.isEmpty:
            // backspace on an empty line leaves it, as in vim
            cancelInput()
            return true
        default:
            return false
        }
    }

    private func inputChanged() {
        switch browser.mode {
        case .search:
            browser.updateSearch(input.stringValue)
        case .commandLine:
            browser.updateCommandLine(input.stringValue)
        case .normal:
            break
        }
        sync()
    }

    private func commitInput() {
        if case .search = browser.mode {
            browser.commitSearch()
            sync()
        } else {
            let effects = browser.commitCommandLine()
            sync()
            onEffects(effects)
        }
    }

    private func cancelInput() {
        browser.cancel()
        sync()
    }

    // MARK: drawing state

    private func sync() {
        syncing = true
        defer { syncing = false }
        table.reloadData()
        if browser.visible.isEmpty {
            table.deselectAll(nil)
        } else {
            table.selectRowIndexes([browser.selection], byExtendingSelection: false)
            table.scrollRowToVisible(browser.selection)
        }
        let typing: String?
        switch browser.mode {
        case .normal:
            typing = nil
        case .search(let direction, _):
            typing = direction == .down ? "/" : "?"
        case .commandLine:
            typing = ":"
        }
        prompt.stringValue = typing ?? ""
        prompt.isHidden = typing == nil
        input.isHidden = typing == nil
        status.isHidden = typing != nil
        if typing != nil, panel.firstResponder !== input.currentEditor() {
            input.stringValue = ""
            panel.makeFirstResponder(input)
        } else if typing == nil, panel.firstResponder !== table {
            panel.makeFirstResponder(table)
        }
        status.stringValue = browser.message ?? summary()
        status.textColor = browser.message == nil ? .secondaryLabelColor : .labelColor
        pending.stringValue = [matcher.display, statusExtra()].filter { !$0.isEmpty }.joined(separator: "  ")
    }

    private func summary() -> String {
        let count = browser.visible.count
        if browser.filter.isEmpty {
            return count == 1 ? "1 item" : "\(count) items"
        }
        return "\(browser.filter)  \(count) of \(browser.all.count)"
    }

    // MARK: table

    func numberOfRows(in tableView: NSTableView) -> Int {
        browser.visible.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("row")
        let view = tableView.makeView(withIdentifier: id, owner: nil) as? ClipRowView ?? ClipRowView()
        view.identifier = id
        let item = browser.visible[row]
        view.pin.isHidden = !item.pinned
        view.age.stringValue = RelativeTime.label(item.created, now: Date(), calendar: .current)
        view.icon.contentTintColor = .secondaryLabelColor
        switch item.kind {
        case .text:
            view.icon.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "text")
            view.title.stringValue = Self.line(item.preview)
        case .file:
            view.icon.image = NSImage(systemSymbolName: "doc", accessibilityDescription: "file")
            view.title.stringValue = item.preview
        case .image:
            view.icon.image = thumbnail(item, row: row) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: "image")
            view.title.stringValue = imageSizes[item.id].map { "Image \($0)" } ?? "Image"
        }
        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !syncing, table.selectedRow >= 0 else {
            return
        }
        browser.select(table.selectedRow)
        sync()
    }

    /// The first line with text, spaces collapsed.
    private static func line(_ text: String) -> String {
        let first = text.split(whereSeparator: \.isNewline).first { !$0.allSatisfy(\.isWhitespace) } ?? ""
        return String(first.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(300))
    }

    /// A cached thumbnail, or nil while one is made off the main thread.
    private func thumbnail(
        _ item: ClipItem,
        row: Int
    ) -> NSImage? {
        if let cached = thumbnails.object(forKey: item.id as NSString) {
            return cached
        }
        guard let url = store.imageURL(of: item) else {
            return nil
        }
        let id = item.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int
            let height = properties?[kCGImagePropertyPixelHeight] as? Int
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return
            }
            let thumbnail = NSImage(cgImage: image, size: NSSize(width: 28, height: 28))
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.thumbnails.setObject(thumbnail, forKey: id as NSString)
                if let width, let height {
                    self.imageSizes[id] = "\(width)x\(height)"
                }
                if let index = self.browser.visible.firstIndex(where: { $0.id == id }) {
                    self.table.reloadData(forRowIndexes: [index], columnIndexes: [0])
                }
            }
        }
        return nil
    }
}

// MARK: smoke

/// `SPASTE_SMOKE=<script>`: drives the panel without a keyboard and records
/// what it shows, for scripts/smoke.sh. One step per line: `open`,
/// `keys <sequence>`, `type <text>`, `enter`, `esc`, `state`, `shot <name>`.
extension PanelController {
    func runSmoke(
        _ steps: [String],
        keymap: Keymap,
        output: URL,
        done: @escaping () -> Void
    ) {
        guard let step = steps.first else {
            done()
            return
        }
        let word = String(step.prefix { !$0.isWhitespace })
        let rest = step.dropFirst(word.count).trimmingCharacters(in: .whitespaces)
        switch word {
        case "open":
            show(keymap: keymap, message: nil)
        case "keys":
            for key in (try? Key.parseSequence(rest)) ?? [] {
                feed(key)
            }
        case "type":
            input.stringValue = rest
            inputChanged()
        case "enter":
            commitInput()
        case "esc":
            cancelInput()
        case "state":
            append(smokeState(), to: output.appendingPathComponent("state.txt"))
        case "shot":
            shot(output.appendingPathComponent("\(rest).png"))
        default:
            append("unknown step: \(step)", to: output.appendingPathComponent("state.txt"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.runSmoke(Array(steps.dropFirst()), keymap: keymap, output: output, done: done)
        }
    }

    private func smokeState() -> String {
        let mode: String
        switch browser.mode {
        case .normal:
            mode = "normal"
        case .search(let direction, let text):
            mode = (direction == .down ? "/" : "?") + text
        case .commandLine(let text):
            mode = ":" + text
        }
        let selected = browser.selected.map { $0.kind == .image ? "image" : Self.line($0.preview) } ?? "-"
        return "\(mode) | \(selected) | \(browser.visible.count)/\(browser.all.count) | \(browser.filter) | \(browser.message ?? "")"
    }

    private func shot(_ url: URL) {
        guard let view = panel.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    private func append(
        _ line: String,
        to url: URL
    ) {
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? Data((existing + line + "\n").utf8).write(to: url)
    }
}
