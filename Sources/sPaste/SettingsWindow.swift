import AppKit
import ServiceManagement
import SPasteCore
import SwiftUI
import UniformTypeIdentifiers

/// What the Settings window shows. The config file stays the truth: each
/// control writes its key's line (or lines, for the repeating keys), and
/// the reload that follows applies it to the app and comes back here.
@MainActor
@Observable
final class SettingsModel {
    var config = Config()
    var issues: [String] = []
    var historyCount = 0
    var launchAtLogin = false
    var accessibility = false
    /// The last thing an action did, under the buttons that did it.
    var status = ""
    @ObservationIgnored let paths: ConfigPaths
    @ObservationIgnored let historyDirectory: URL
    /// The app's config, its problems and the number of items, as loaded.
    @ObservationIgnored var current: () -> (config: Config, issues: [String], items: Int) = { (Config(), [], 0) }
    /// Reloads the files into the app after a write.
    @ObservationIgnored var onWrite: () -> Void = {}
    @ObservationIgnored var onWipe: () -> Void = {}

    init(
        paths: ConfigPaths,
        historyDirectory: URL
    ) {
        self.paths = paths
        self.historyDirectory = historyDirectory
    }

    func refresh() {
        let now = current()
        config = now.config
        issues = now.issues
        historyCount = now.items
        launchAtLogin = SMAppService.mainApp.status == .enabled
        accessibility = Paster.isTrusted(prompt: false)
    }

    /// Writes `key` when `change` gives it another value.
    func change(
        _ key: String,
        _ change: (inout Config) -> Void
    ) {
        var changed = config
        change(&changed)
        guard let text = changed.text(for: key), text != config.text(for: key) else {
            return
        }
        do {
            try paths.persist(key, text, as: Config.self)
            status = "\(key) \(text)"
            onWrite()
        } catch {
            status = "\(error)"
        }
        refresh()
    }

    /// Rewrites every line of a repeating key.
    func setList(
        _ key: String,
        _ values: [String]
    ) {
        let text = (try? String(contentsOf: paths.config, encoding: .utf8)) ?? Config.defaultText
        do {
            try Data(Config.setting(list: key, to: values, in: text).utf8).write(to: paths.config, options: .atomic)
            status = values.isEmpty ? "no \(key) lines" : "\(key) \(values.joined(separator: ", "))"
            onWrite()
        } catch {
            status = "\(error)"
        }
        refresh()
    }

    func binding<Value>(
        _ key: String,
        _ path: WritableKeyPath<Config, Value>
    ) -> Binding<Value> {
        Binding(
            get: { self.config[keyPath: path] },
            set: { value in
                self.change(key) { $0[keyPath: path] = value }
            }
        )
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            status = "launch at login: \(error.localizedDescription)"
        }
        refresh()
    }
}

/// sPaste > Settings…: one window, every config option as a control.
@MainActor
final class SettingsWindowController: NSWindowController {
    let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "sPaste Settings"
        window.setFrameAutosaveName("Settings")
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    func show() {
        model.refresh()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let model: SettingsModel
    @State private var newType = ""

    var body: some View {
        Form {
            Section("Panel") {
                LabeledContent("Open and close") {
                    HotkeyRecorder(model: model)
                }
                Toggle("Enter also pastes into the app you came from", isOn: model.binding("paste_on_enter", \.pasteOnEnter))
                if model.config.pasteOnEnter && !model.accessibility {
                    HStack {
                        Text("Pasting needs sPaste in Accessibility.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Allow…") {
                            _ = Paster.isTrusted(prompt: true)
                            model.refresh()
                        }
                    }
                    Text("After an update, System Settings can show sPaste switched on while macOS still holds the old version's entry. Quit sPaste, run tccutil reset Accessibility io.github.usuite.spaste in Terminal, then reopen it and allow it again.")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
            Section("History") {
                LabeledContent("Keep") {
                    number("max_items", \.maxItems, range: 10...100_000, step: 100, unit: "unpinned items")
                }
                LabeledContent("Skip images over") {
                    number("max_image_mb", \.maxImageMB, range: 1...500, step: 5, unit: "MB")
                }
                Picker("Check the clipboard every", selection: model.binding("poll_ms", \.pollMilliseconds)) {
                    Text("0.25 s").tag(250)
                    Text("0.5 s").tag(500)
                    Text("1 s").tag(1000)
                    Text("2 s").tag(2000)
                    if ![250, 500, 1000, 2000].contains(model.config.pollMilliseconds) {
                        Text("\(model.config.pollMilliseconds) ms").tag(model.config.pollMilliseconds)
                    }
                }
                LabeledContent("Folder") {
                    Text("\(model.historyCount) items in \(Self.tilde(model.historyDirectory))")
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Open History Folder") {
                        NSWorkspace.shared.open(model.historyDirectory)
                    }
                    Spacer()
                    Button("Wipe History…", role: .destructive) {
                        wipe()
                    }
                }
            }
            Section {
                ForEach(model.config.ignoreApps, id: \.self) { bundleID in
                    HStack {
                        Text(Self.appName(bundleID))
                        Text(bundleID)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Remove", systemImage: "minus.circle") {
                            model.setList("ignore_app", model.config.ignoreApps.filter { $0 != bundleID })
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add App…") {
                    addApp()
                }
            } header: {
                Text("Never store copies made in")
            }
            Section {
                ForEach(model.config.ignoreTypes, id: \.self) { type in
                    HStack {
                        Text(type)
                            .font(.body.monospaced())
                        Spacer()
                        Button("Remove", systemImage: "minus.circle") {
                            model.setList("ignore_type", model.config.ignoreTypes.filter { $0 != type })
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("Pasteboard type", text: $newType, prompt: Text("com.example.secret"))
                        .labelsHidden()
                        .onSubmit(addType)
                    Button("Add", action: addType)
                        .disabled(newType.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Never store copies carrying")
            } footer: {
                Text("Items marked concealed, transient or auto-generated, as password managers mark them, are always skipped.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Folder") {
                    Text(Self.tilde(model.paths.directory))
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Import Config…") {
                        ConfigPanels.importConfig(model)
                    }
                    Button("Export Config…") {
                        ConfigPanels.exportConfig(model)
                    }
                    Spacer()
                    Button("Open Config Folder") {
                        NSWorkspace.shared.open(model.paths.directory)
                    }
                }
                if !model.status.isEmpty {
                    Text(model.status)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Config files")
            } footer: {
                Text("config and keymap are plain text; keys live in keymap, and every change here is a line of config.")
                    .foregroundStyle(.secondary)
            }
            Section("Problems in the files") {
                if model.issues.isEmpty {
                    Text("No problems")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.issues, id: \.self) { issue in
                        Text(issue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 720)
    }

    private func number(
        _ key: String,
        _ path: WritableKeyPath<Config, Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        HStack(spacing: 4) {
            TextField(
                key,
                value: model.binding(key, path),
                format: .number.grouping(.never)
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .frame(width: 72)
            Stepper(
                key,
                value: model.binding(key, path),
                in: range,
                step: step
            )
            .labelsHidden()
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func addType() {
        let type = newType.trimmingCharacters(in: .whitespaces)
        guard !type.isEmpty, !type.contains(where: \.isWhitespace), !model.config.ignoreTypes.contains(type) else {
            return
        }
        model.setList("ignore_type", model.config.ignoreTypes + [type])
        newType = ""
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Copies made while these apps are in front are never stored"
        guard panel.runModal() == .OK else {
            return
        }
        let added = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            .filter { !model.config.ignoreApps.contains($0) }
        guard !added.isEmpty else {
            return
        }
        model.setList("ignore_app", model.config.ignoreApps + added)
    }

    private func wipe() {
        let alert = NSAlert()
        alert.messageText = "Delete all \(model.historyCount) items, pinned ones included?"
        alert.informativeText = "Their files are deleted from the history folder. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        model.onWipe()
        model.status = "history wiped"
        model.refresh()
    }

    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func tilde(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

/// Click Record, press the new key combination; Esc cancels. A combination
/// without cmd, ctrl or alt is refused, as the config file refuses it.
struct HotkeyRecorder: View {
    let model: SettingsModel
    @State private var recording = false
    @State private var monitor: Any?
    @State private var refused = ""

    var body: some View {
        HStack {
            Text(recording ? "Press keys…" : Self.symbols(model.config.hotkey))
                .font(.body.monospaced())
                .foregroundStyle(recording ? .secondary : .primary)
            if !refused.isEmpty {
                Text(refused)
                    .foregroundStyle(.secondary)
            }
            Button(recording ? "Cancel" : "Record") {
                recording ? stop() : start()
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        refused = ""
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stop()
                return nil
            }
            var parts: [String] = []
            let flags = event.modifierFlags
            for (flag, name) in [(NSEvent.ModifierFlags.command, "cmd"), (.control, "ctrl"), (.option, "alt"), (.shift, "shift")] where flags.contains(flag) {
                parts.append(name)
            }
            let base = KeyTranslator.named[event.keyCode] ?? event.charactersIgnoringModifiers?.lowercased() ?? ""
            parts.append(base)
            if let hotkey = Hotkey.parse(parts.joined(separator: "-")) {
                model.change("hotkey") { $0.hotkey = hotkey }
            } else {
                refused = "needs cmd, ctrl or alt"
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = false
    }

    /// `⇧⌘C`, as menus write it.
    static func symbols(_ hotkey: Hotkey) -> String {
        var text = ""
        for (modifier, symbol) in [(Key.Modifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")] where hotkey.modifiers.contains(modifier) {
            text += symbol
        }
        return text + (hotkey.key.count == 1 ? hotkey.key.uppercased() : hotkey.key.capitalized)
    }
}

/// Import Config… and Export Config…, with the shared `ConfigArchive`.
@MainActor
enum ConfigPanels {
    /// The zip is read and checked first; the files it replaces are named,
    /// with their problems, before anything changes.
    static func importConfig(_ model: SettingsModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.message = "Choose a config zip made by Export Config or :export"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        Task {
            let files: [ConfigArchive.File]
            do {
                files = try await ConfigArchive.spaste.inspect(url, check: ConfigArchive.spasteIssues)
            } catch {
                model.status = "\(error)"
                return
            }
            let names = files.map(\.name)
            let alert = NSAlert()
            alert.messageText = "Replace \(names.joined(separator: " and ")) with the ones in \(url.lastPathComponent)?"
            var info = "The current files are kept as \(names.map { $0 + ".bak" }.joined(separator: " and ")) in the config folder."
            for file in files where !file.issues.isEmpty {
                info += "\n\n\(file.name):\n" + file.issues.prefix(5).joined(separator: "\n")
                if file.issues.count > 5 {
                    info += "\n(+\(file.issues.count - 5) more)"
                }
            }
            alert.informativeText = info
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
            do {
                let written = try ConfigArchive.apply(files, to: model.paths.directory)
                model.status = "Imported \(written.joined(separator: " and ")); the old files are kept as .bak"
                model.onWrite()
            } catch {
                model.status = "\(error)"
            }
            model.refresh()
        }
    }

    static func exportConfig(_ model: SettingsModel) {
        let suggested = ConfigArchive.spaste.destination(for: "", folder: nil)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.directoryURL = suggested.deletingLastPathComponent()
        panel.nameFieldStringValue = suggested.lastPathComponent
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let paths = model.paths
        Task {
            do {
                let names = try await ConfigArchive.spaste.export(from: paths, to: url)
                model.status = "Exported \(names.count) files to \(url.lastPathComponent)"
            } catch {
                model.status = "\(error)"
            }
        }
    }
}
