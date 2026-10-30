# sPaste: keys

The panel opens in normal mode: keys are commands, as in vim. A number before a key repeats it (`5j`). Every binding can be changed in `~/.config/spaste/keymap`, one `<keys> <command> [args]` per line, with `<keys> nop` to remove a default.

| Keys | Command | What |
| --- | --- | --- |
| `j` `down` | `down` | next (older) item |
| `k` `up` | `up` | previous (newer) item |
| `ctrl-d` `ctrl-u` | `half-down` `half-up` | half a panel down or up |
| `gg` `G` | `first` `last` | newest, oldest |
| `/` | `search-forward` | search from the newest item down |
| `?` | `search-backward` | search from the oldest item up |
| `n` `N` | `search-next` `search-previous` | repeat the search, same or other direction |
| `enter` | `choose` | copy the item back (and paste, with `paste_on_enter yes`) |
| `m` | `pin` | pin or unpin; pinned items are never pruned |
| `dd` | `delete` | delete the item and its file |
| `ft` `fi` `ff` `fa` | `type text` `type image` `type file` `type all` | show only text, images, files, or everything |
| `:` | `command-line` | the command line |
| `q` `esc` | `close` | close the panel (Esc first leaves a search or the command line) |

## Command line

- `:type image file` shows only those types; `:type` or `:type all` shows all.
- `:since 2h`, `:since today`, `:until yesterday`, `:since 2026-10-29`. Units are `m`, `h`, `d` and `w`. `:since` alone clears it.
- `:clear` removes every filter.
- `:pause` stops or resumes capture.
- `:settings` opens the Settings window.
- `:export` writes config and keymap to a dated zip on the Desktop; `:export ~/backup/spaste.zip` puts it where you say.
- `:wipe!` deletes the whole history, pinned items included.
- `:q` closes the panel.

## Filter tokens in a search

A search line may carry the same filters as tokens: `/type:image since:1h` or `?invoice type:file`. Tokens set the filter; the rest of the line is the search text. A token that is not complete or not known, such as `type:fi`, stays part of the search text.
