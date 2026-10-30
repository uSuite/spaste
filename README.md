# sPaste

<img src="brand/spaste-1024.png" alt="sPaste icon" width="128">

A keyboard-first clipboard history for macOS, in the spirit of Ditto on Windows, Maccy on macOS and Parcellite on Linux, with vim keys and filters by type and time.

## Why another clipboard manager

Maccy is very good, and sPaste borrows its idea: a small panel on a hotkey, nothing else. Two things are missing there for a keyboard user:

- A normal mode. In sPaste the panel opens with `j` and `k` moving the selection, counts (`5j`), `gg` and `G`, `/` searching from the newest item, `?` from the oldest, and `n` and `N` repeating the search. In Maccy every key types into the search field.
- Filters by type and time. `fi` shows only images, `ff` only files, `ft` only text, and `:since 2h` or `:until yesterday` narrow the list by time.

The history is a plain folder: one file per item and a text index, so pruning or deleting an item removes its file and nothing stays readable on disk.

## Part of uSuite

sPaste is a utility of the [uSuite](https://github.com/uSuite) organization, built to the same rules as the sSuite tools: one job, plain text config, keyboard first, Swift and Apple frameworks only, nothing uploaded. It shares the keymap grammar and config code of [scommon](https://github.com/uSuite/scommon).

## Install

Requires macOS 26 or newer, on Apple silicon or Intel. Download `sPaste-<version>.zip` from the [latest release](https://github.com/uSuite/spaste/releases/latest), open it, and move `sPaste.app` to Applications. sPaste lives in the menu bar; choose Launch at Login in its menu or Settings to keep it running.

### The first open: sPaste Not Opened

The release is signed ad hoc, not with a paid Apple Developer ID, so Apple has not notarised it. The first time you open a downloaded copy, macOS stops it with "Apple could not verify sPaste is free of malware". Choose Done, then allow it once, either way:

- System Settings > Privacy & Security, scroll down to Security, and next to the line saying sPaste was blocked to protect your Mac, choose Open Anyway, confirm with your password or Touch ID, then Open.
- Or in Terminal, remove the download flag macOS checks: `xattr -dr com.apple.quarantine /Applications/sPaste.app`

From then on that copy opens like any app; each new version you download asks once more. A copy you build yourself never carries the download flag.

If you turn on paste on Enter, macOS asks to add sPaste under Privacy & Security > Accessibility. A new version is a new signature to macOS, so after an update switch sPaste off and on there; Settings tells you when it is needed.

## Use

Shift+Cmd+C opens and closes the panel (`hotkey` in the config). Enter copies the selected item back to the clipboard and closes the panel; press Cmd+V where you want it. `paste_on_enter yes` pastes for you, which needs Accessibility access. The full key list is in `docs/keys.md`.

Settings are in `~/.config/spaste/config` and keys in `~/.config/spaste/keymap`, both plain `key value` text written with comments on first run. The history lives in `~/Library/Application Support/sPaste/history/`, readable only by you.

Passwords copied from a password manager are not stored: items marked concealed or transient on the pasteboard are skipped, and `ignore_app` skips any app you name.

## Build

`make test`, `make app`, `make run`. Swift 6.2 and macOS 26 or newer. MIT licence.
