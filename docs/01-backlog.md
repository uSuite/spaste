# sPaste: backlog

sPaste ("super-fast paste") is a clipboard history in a panel on a hotkey, driven from the keyboard like vim. Priorities: P0 is the 0.1 that replaces Maccy for daily use, P1 makes it better, P2 is nice to have, P3 is parked. IDs are stable.

## Non-goals

- No sync, no cloud, no accounts, no network access at all.
- No editing of items beyond deleting and pinning; no snippets or templates.
- No Windows or Linux build.

## E1 Capture (P0)

- SP-101 Poll the general pasteboard's change count every `poll_ms` and store text (with rich text beside it), images and file lists.
- SP-102 Skip concealed, transient and auto-generated items, `ignore_type` types and copies made while an `ignore_app` app is frontmost; skip images over `max_image_mb`.
- SP-103 Copying the same content again moves the existing item to the top.
- SP-104 Keep at most `max_items` unpinned items; the oldest go first and their files are deleted.
- SP-105 Pause capture and ignore the next copy from the menu.

## E2 Panel and keys (P0)

- SP-201 Shift+Cmd+C (`hotkey`) opens and closes a non-activating panel on the screen with the mouse, in normal mode.
- SP-202 `j k` with counts, `gg G`, `ctrl-d ctrl-u` half pages.
- SP-203 `/` from the newest item, `?` from the oldest, incremental, smartcase, `n N` repeat with wrap.
- SP-204 Filters: `ft fi ff fa`, `:type`, `:since`, `:until`, `:clear`, and `type:` `since:` `until:` tokens in a search.
- SP-205 Enter copies the item back with all its stored types and closes the panel; `paste_on_enter yes` also sends Cmd+V to the previous app.
- SP-206 `m` pins, `dd` deletes, `:wipe!` deletes the whole history.
- SP-207 Rows show a text preview, an image thumbnail or file names, and a relative time; a status line shows filter, pending keys and messages.

## E3 Settings (P0)

- SP-301 `~/.config/spaste/config` and `keymap`, written with comments on first run; problems shown in the status line.
- SP-302 Launch at login from the menu.

## E4 Later (P1 to P3)

- SP-401 (P1) Search image text with Vision OCR.
- SP-402 (P1) Paste as plain text.
- SP-403 (P2) Edit a text item before pasting.
- SP-404 (P2) A `make bench` target as in sView (open time, idle CPU); `make smoke` exists.
- SP-405 (P3) Several pasteboards, sync between Macs.
