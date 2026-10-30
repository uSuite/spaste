import SCommon

/// sPaste's keymap and matcher: the shared generic ones over `Command`.
public typealias Keymap = SCommon.Keymap<Command>
public typealias KeyMatcher = SCommon.KeyMatcher<Command>

extension Command: KeymapCommand {}

extension SCommon.Keymap where C == Command {
    /// The shipped bindings, copied to the config directory on first run as
    /// documentation.
    public static var defaultText: String { DefaultKeymap.text }

    public static var `default`: Keymap { DefaultKeymap.keymap }

    /// The user's keymap file applied over the shipped defaults.
    public static func overlaid(_ userText: String) -> (keymap: Keymap, issues: [LineIssue]) {
        overlaid(userText, over: .default)
    }
}

/// Stored once: static stored properties cannot live in an extension of a
/// generic type.
enum DefaultKeymap {
    static let keymap = Keymap.parse(text).keymap

    static let text = """
        # sPaste keymap. One binding per line: <keys> <command> [args]
        # Lines here apply over the built-in defaults; `<keys> nop` unbinds one.
        # Keys are characters (case matters) or named keys: space enter tab esc
        # backspace delete left right up down home end pageup pagedown f1..f12
        # hash lt gt, with cmd- ctrl- alt- shift- modifiers. Use <name> inside a
        # sequence, e.g. g<space>. A number before a key repeats it: 5j, 3dd.

        # moving: down is older, up is newer
        j down
        k up
        down down
        up up
        ctrl-d half-down
        ctrl-u half-up
        pagedown half-down
        pageup half-up
        gg first
        G last
        home first
        end last

        # searching: / from the newest item, ? from the oldest
        / search-forward
        ? search-backward
        n search-next
        N search-previous

        # items
        enter choose
        m pin
        dd delete

        # filters
        ft type text
        fi type image
        ff type file
        fa type all

        # panel
        : command-line
        q close
        esc close
        """
}
