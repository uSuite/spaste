import AppKit
import ServiceManagement
import SPasteCore
import os

private let log = Logger(subsystem: "io.github.usuite.spaste", category: "app")

/// The menu bar agent: loads config and history, runs the watcher and the
/// hotkey, and carries out what the panel decides.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let environment = ProcessInfo.processInfo.environment
    private let paths = ConfigPaths(app: "spaste")
    /// `SPASTE_HISTORY_DIR` points the history elsewhere, for the smoke test.
    private lazy var store = HistoryStore(
        directory: environment["SPASTE_HISTORY_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? HistoryStore.defaultDirectory
    )
    private var config = Config()
    private var keymap = Keymap.default
    private var problems: [String] = []
    private var statusItem: NSStatusItem!
    private var watcher: PasteboardWatcher!
    private var panel: PanelController!
    private var hotKey: HotKey!
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try store.load()
        } catch {
            problems.append("history: \(error.localizedDescription)")
            log.error("history load failed: \(error.localizedDescription, privacy: .public)")
        }
        watcher = PasteboardWatcher(
            onCopy: { [weak self] content, app in
                self?.capture(content, app: app)
            },
            onSkip: { [weak self] reason in
                self?.panel.say(reason)
            }
        )
        panel = PanelController(store: store)
        panel.onEffects = { [weak self] effects in
            self?.apply(effects)
        }
        panel.statusExtra = { [weak self] in
            self?.watcher.paused == true ? "paused" : ""
        }
        hotKey = HotKey { [weak self] in
            self?.togglePanel()
        }
        if let script = environment["SPASTE_SMOKE"] {
            smoke(script)
            return
        }
        loadSettings()
        _ = try? store.prune(keeping: config.maxItems)
        buildStatusItem()
    }

    /// Runs a smoke script against the history in `SPASTE_HISTORY_DIR`,
    /// with capture paused and no hotkey, then quits.
    private func smoke(_ script: String) {
        watcher.paused = true
        panel.takesKeys = false
        let steps = ((try? String(contentsOfFile: script, encoding: .utf8)) ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        let output = URL(fileURLWithPath: environment["SPASTE_SMOKE_OUT"] ?? ".", isDirectory: true)
        panel.runSmoke(steps, keymap: .default, output: output) {
            NSApp.terminate(nil)
        }
    }

    // MARK: settings

    /// Reads config and keymap; called at launch and each time the panel
    /// opens, so edits apply without a restart.
    private func loadSettings() {
        problems.removeAll { $0.hasPrefix("config") || $0.hasPrefix("keymap") || $0.hasPrefix("hotkey") }
        do {
            try paths.ensureDefaults(
                config: Config.defaultText,
                keymap: Keymap.defaultText
            )
        } catch {
            problems.append("config: \(error.localizedDescription)")
        }
        let loaded = paths.load(Config.self)
        config = loaded.config
        problems += loaded.issues.map { "config \($0)" }
        let keymapText = (try? String(contentsOf: paths.keymap, encoding: .utf8)) ?? ""
        let overlaid = Keymap.overlaid(keymapText)
        keymap = overlaid.keymap
        problems += overlaid.issues.map { "keymap \($0)" }
        watcher.config = config
        watcher.start()
        if environment["SPASTE_SMOKE"] == nil, !hotKey.register(config.hotkey) {
            problems.append("hotkey \(config.hotkey) could not be registered")
        }
    }

    // MARK: capture

    private func capture(
        _ content: ClipContent,
        app: String?
    ) {
        do {
            try store.add(content, app: app)
            try store.prune(keeping: config.maxItems)
        } catch {
            log.error("store failed: \(error.localizedDescription, privacy: .public)")
            panel.say("could not store the copy: \(error.localizedDescription)")
        }
        panel.refresh()
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.hide()
            return
        }
        loadSettings()
        panel.show(keymap: keymap, message: problems.first)
    }

    private func apply(_ effects: [Browser.Effect]) {
        var paste = false
        for effect in effects {
            do {
                switch effect {
                case .copy(let item):
                    watcher.write(try store.content(of: item))
                    paste = config.pasteOnEnter
                case .close:
                    panel.hide()
                case .delete(let item):
                    try store.delete(item.id)
                case .setPinned(let item, let pinned):
                    try store.setPinned(item.id, pinned)
                case .wipe:
                    try store.wipe()
                case .togglePause:
                    togglePause()
                case .openSettings:
                    openSettings()
                case .export(let path):
                    export(to: path)
                }
            } catch {
                panel.say("\(error)")
            }
        }
        panel.refresh()
        if paste {
            guard Paster.isTrusted(prompt: true) else {
                return
            }
            // the panel has gone; give the app below it a moment to take keys
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                Paster.paste()
            }
        }
    }

    // MARK: menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "sPaste")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let hotkey = hotKey.registered.map { "  (\($0))" } ?? "  (no hotkey)"
        menu.addItem(item("Open sPaste" + hotkey, #selector(openPanel)))
        menu.addItem(.separator())
        menu.addItem(item("Pause Capture", #selector(pauseFromMenu), on: watcher.paused))
        menu.addItem(item("Ignore Next Copy", #selector(ignoreNext), on: watcher.ignoreNext))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings)))
        menu.addItem(item("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(item("Open Config Folder", #selector(openConfig)))
        menu.addItem(item("Open History Folder", #selector(openHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Quit sPaste", #selector(NSApplication.terminate(_:)), target: NSApp))
    }

    private func item(
        _ title: String,
        _ action: Selector,
        on: Bool = false,
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target ?? self
        item.state = on ? .on : .off
        return item
    }

    @objc private func openPanel() {
        if !panel.isVisible {
            togglePanel()
        }
    }

    @objc private func pauseFromMenu() {
        togglePause()
    }

    private func togglePause() {
        watcher.paused.toggle()
        statusItem.button?.appearsDisabled = watcher.paused
        panel.say(watcher.paused ? "capture paused" : "capture resumed")
    }

    @objc private func ignoreNext() {
        watcher.ignoreNext.toggle()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func openSettings() {
        if settings == nil {
            let model = SettingsModel(
                paths: paths,
                historyDirectory: store.directory
            )
            model.current = { [weak self] in
                guard let self else {
                    return (Config(), [], 0)
                }
                return (self.config, self.problems, self.store.items.count)
            }
            model.onWrite = { [weak self] in
                self?.loadSettings()
            }
            model.onWipe = { [weak self] in
                self?.apply([.wipe])
            }
            settings = SettingsWindowController(model: model)
        }
        loadSettings()
        settings?.show()
    }

    /// `:export [path]`: the config zip, dated on the Desktop by default.
    private func export(to path: String) {
        let destination = ConfigArchive.spaste.destination(for: path, folder: nil)
        let paths = paths
        Task { @MainActor in
            do {
                let names = try await ConfigArchive.spaste.export(from: paths, to: destination)
                panel.say("exported \(names.count) files to \(destination.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
            } catch {
                panel.say("\(error)")
            }
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(paths.directory)
    }

    @objc private func openHistory() {
        NSWorkspace.shared.open(store.directory)
    }
}
