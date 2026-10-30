import Foundation

/// The three kinds of history item; the file extension says which.
public enum ClipKind: String, Sendable, Hashable, CaseIterable {
    case text
    case image
    case file

    /// `text`, `image` or `file`, singular or plural.
    public static func parse(_ word: String) -> ClipKind? {
        let lower = word.lowercased()
        return ClipKind(rawValue: lower.hasSuffix("s") ? String(lower.dropLast()) : lower)
    }
}

/// The image formats kept as they came from the pasteboard.
public enum ImageType: String, Sendable, Hashable {
    case png
    case tiff
}

/// One copy's content, read from the pasteboard or from the history folder.
public enum ClipContent: Sendable, Equatable {
    /// Plain text, with the rich text that came with it.
    case text(String, rtf: Data?)
    case image(Data, type: ImageType)
    /// POSIX paths, in pasteboard order.
    case files([String])

    public var kind: ClipKind {
        switch self {
        case .text:
            return .text
        case .image:
            return .image
        case .files:
            return .file
        }
    }
}

/// One history entry as the panel lists it. The content stays on disk until
/// it is copied back.
public struct ClipItem: Sendable, Equatable, Identifiable {
    /// `yyyy-MM-dd-HHmmss-nnn`, the file name stem, local time.
    public let id: String
    public let kind: ClipKind
    public let created: Date
    /// Bundle id of the app that was frontmost when it was copied.
    public var app: String?
    public var pinned: Bool
    /// Identifies the content, so a second copy of it moves the first up.
    public var digest: String
    /// What search looks at and the row shows: the text (its first
    /// `previewLimit` characters) or the file names.
    public var preview: String

    public static let previewLimit = 65_536

    public init(
        id: String,
        kind: ClipKind,
        created: Date,
        app: String? = nil,
        pinned: Bool = false,
        digest: String,
        preview: String
    ) {
        self.id = id
        self.kind = kind
        self.created = created
        self.app = app
        self.pinned = pinned
        self.digest = digest
        self.preview = preview
    }
}
