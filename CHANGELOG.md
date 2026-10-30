# Changelog

Versions follow semver. Each release lists what a user notices; docs/DECISIONS.md has the reasoning.

## Unreleased

- The search and command line fills the width of the panel and scrolls a long query instead of wrapping it out of sight; it showed about four characters before.

## 0.1.0 (2026-10-30)

- Clipboard history in a panel on Shift+Cmd+C: text with its formatting, images and file lists, newest first, with a thumbnail and an age per row.
- Vim keys with counts: `j k`, `gg G`, `ctrl-d ctrl-u`, `/` from the newest item, `?` from the oldest, `n N`, `m` to pin, `dd` to delete, `:` commands.
- Filters by type (`ft fi ff fa`, `:type`) and time (`:since 2h`, `:until yesterday`), also as `type:` `since:` `until:` tokens in a search.
- Enter copies the item back; `paste_on_enter yes` pastes it too once Accessibility is granted.
- The history is a folder only you can read, one file per item; deleting and pruning remove the files. Concealed and transient items (password managers) are never stored.
- Menu: pause capture, ignore the next copy, launch at login, open the config and history folders.
- Settings… (menu or `:settings`): record the hotkey, paste on Enter with the Accessibility state, launch at login, history size and image limit, check interval, ignored apps and pasteboard types, the history folder with Wipe History, and Import Config, Export Config and Open Config Folder; each control writes one line of config and applies at once. Problems in the files are listed there too.
- `:export [path]` writes config and keymap to a zip, dated on the Desktop by default; Import Config keeps the replaced files as `.bak`.
