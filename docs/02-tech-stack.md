# sPaste: tech stack

Swift 6.2, macOS 26, AppKit, Carbon for the hotkey, CryptoKit for content digests, scommon. No other dependencies.

## Layers

- SCommon: `Key`, `Keymap`, `KeyMatcher`, `KeyValueParser`, `KeyValueSettings`, `ConfigPaths`, `LineIssue`. Re-exported by SPasteCore.
- SPasteCore, pure Swift with strict concurrency, no AppKit:
  - `ClipItem`, `ClipKind`, `ClipContent`: what is stored and what is copied back.
  - `HistoryStore`: the history folder, its `index` file, dedupe by digest, pins, prune and wipe.
  - `TimeSpec`, `Filter`, `Query`: the filters and the `type:` `since:` `until:` tokens.
  - `Search`: vim search over the visible items, both directions, smartcase, wrap.
  - `Command`, `Keymap` defaults, `Config`.
  - `Browser`: the panel's state (items, filter, selection, mode, message) and the only place keys turn into changes; it returns `Effect`s the app carries out.
- sPaste, the app:
  - `PasteboardWatcher`: reads the pasteboard into `ClipContent` and writes an item back.
  - `HotKey`: Carbon registration of the configured key.
  - `PanelController`: the `NSPanel`, its rows and status line, key events into `KeyMatcher` and `Browser`.
  - `AppDelegate`: status item menu, config loading, launch at login with `SMAppService`, `Paster` for the opt-in Cmd+V.

## Smoke

`SPASTE_SMOKE=<steps>` runs a script of panel steps (`open`, `keys`, `type`, `enter`, `esc`, `state`, `shot`) with capture paused, no hotkey and the history in `SPASTE_HISTORY_DIR`, then quits; `scripts/smoke.sh` seeds that history and compares the `state` lines. The panel cannot become key during a smoke run: a non-activating panel that can is the key window system-wide, and keys typed in other apps would land in it.

## Measured in the PoC (2026-10-30, macOS 27.0.1, Apple Silicon)

- A pasteboard read of text, a file or a 1024 px PNG took 0 to 3 ms, with no privacy prompt for an ad hoc signed bundle launched on its own.
- Idle at a 0.5 s poll: 0.05 s CPU in 30 s, 41 MB resident.
- Panel shown 11 to 31 ms after the toggle.
