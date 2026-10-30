# Changelog

Versions follow semver. Each release lists what a user notices; docs/DECISIONS.md has the reasoning.

## Unreleased

- Clipboard history in a panel on Shift+Cmd+C: text with its formatting, images and file lists, newest first, with a thumbnail and an age per row.
- Vim keys with counts: `j k`, `gg G`, `ctrl-d ctrl-u`, `/` from the newest item, `?` from the oldest, `n N`, `m` to pin, `dd` to delete, `:` commands.
- Filters by type (`ft fi ff fa`, `:type`) and time (`:since 2h`, `:until yesterday`), also as `type:` `since:` `until:` tokens in a search.
- Enter copies the item back; `paste_on_enter yes` pastes it too once Accessibility is granted.
- The history is a folder only you can read, one file per item; deleting and pruning remove the files. Concealed and transient items (password managers) are never stored.
- Menu: pause capture, ignore the next copy, launch at login, open the config and history folders.
