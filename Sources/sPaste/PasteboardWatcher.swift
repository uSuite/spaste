import AppKit
import SPasteCore

/// Polls the general pasteboard and hands new copies over as `ClipContent`;
/// writes an item back for Enter.
final class PasteboardWatcher {
    var paused = false
    var ignoreNext = false
    var config = Config()
    private var timer: Timer?
    private var lastCount = NSPasteboard.general.changeCount
    private let onCopy: (ClipContent, String?) -> Void
    private let onSkip: (String) -> Void

    private static let imageTypes: [(NSPasteboard.PasteboardType, ImageType)] = [
        (.png, .png),
        (.tiff, .tiff),
    ]

    init(
        onCopy: @escaping (ClipContent, String?) -> Void,
        onSkip: @escaping (String) -> Void
    ) {
        self.onCopy = onCopy
        self.onSkip = onSkip
    }

    func start() {
        let interval = Double(config.pollMilliseconds) / 1000
        if let timer, timer.timeInterval == interval {
            return
        }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = interval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastCount else {
            return
        }
        lastCount = count
        if paused {
            return
        }
        if ignoreNext {
            ignoreNext = false
            onSkip("ignored one copy")
            return
        }
        let types = board.types ?? []
        let names = Set(types.map(\.rawValue))
        if !names.isDisjoint(with: Config.skippedTypes) || !names.isDisjoint(with: config.ignoreTypes) {
            return
        }
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let app, config.ignoreApps.contains(app) {
            return
        }
        guard let content = read(board, types: types) else {
            return
        }
        onCopy(content, app)
    }

    /// Files first (Finder also puts names and icons beside them), then
    /// whichever of text or image the writer listed first.
    private func read(
        _ board: NSPasteboard,
        types: [NSPasteboard.PasteboardType]
    ) -> ClipContent? {
        if types.contains(.fileURL),
            let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            !urls.isEmpty
        {
            return .files(urls.map(\.path))
        }
        let textAt = types.firstIndex(of: .string)
        let image = types.enumerated().lazy.compactMap { offset, type in
            Self.imageTypes.first { $0.0 == type }.map { (offset, $0) }
        }.first
        if let image, textAt.map({ image.0 < $0 }) ?? true {
            guard let data = board.data(forType: image.1.0) else {
                return nil
            }
            guard data.count <= config.maxImageMB * 1_048_576 else {
                onSkip("image over \(config.maxImageMB) MB not stored")
                return nil
            }
            return .image(data, type: image.1.1)
        }
        guard let text = board.string(forType: .string), !text.isEmpty else {
            return nil
        }
        return .text(text, rtf: board.data(forType: .rtf))
    }

    /// Puts an item back on the pasteboard with what it was stored with.
    func write(_ content: ClipContent) {
        let board = NSPasteboard.general
        board.clearContents()
        switch content {
        case .text(let text, let rtf):
            if let rtf {
                board.setData(rtf, forType: .rtf)
            }
            board.setString(text, forType: .string)
        case .image(let data, let type):
            board.setData(data, forType: type == .png ? .png : .tiff)
        case .files(let paths):
            board.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        }
    }
}
