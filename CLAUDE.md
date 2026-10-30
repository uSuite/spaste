# sPaste

macOS-native, keyboard-first clipboard history (Maccy spirit, vim keys, filters by type and time). Swift 6, AppKit menu bar agent, zero dependencies besides scommon. Read docs/02-tech-stack.md for the architecture and docs/01-backlog.md for the work items (SP-xxx). docs/DECISIONS.md is the source of truth for decisions; docs/local/STATUS.md (untracked) says where we are.

## Commands

- `make gen`    regenerate sPaste.xcodeproj from project.yml (XcodeGen)
- `make test`   scommon's tests when `../scommon` is checked out, then swift test on SPasteCore
- `make app`    build sPaste.app into build/
- `make run`    build and launch it
- `make icon`   Resources/AppIcon.icns and brand/spaste-1024.png from the brand SVGs
- `make release` universal ad hoc signed sPaste.app and zip in build/release/
- `make smoke`  drive the panel against a seeded throwaway history (SPASTE_SMOKE), check 16 states, renders in build/smoke/; the panel never takes key status there

## Layers

Shared (the scommon package, the sibling ../scommon when present, else `uSuite/scommon` from GitHub; re-exported by SPasteCore) -> Core (Sources/SPasteCore, pure Swift, strict concurrency, fully unit tested) -> App (Sources/sPaste, AppKit: pasteboard watcher, hotkey, panel, menu). Dependencies point down only. Every user action is a `Command` case; keys, menus and `:` all dispatch Commands through `Browser`.

## Rules

- Plan, get approval, then implement. PoC in scratch/ when unsure.
- One logical change per commit; the message says why. Default git identity, no trailers.
- make test before every commit; make app before UI commits. Never commit red.
- No third-party packages without a DECISIONS.md entry.
- Shared code changes in ../scommon first, test first, with a tag per change set; never edit scommon's files through this checkout.
- Multi-line calls: one argument per line. No banner comment lines.
- Plain text, no em-dash character, no horizontal rules in markdown, one paragraph per line.
- Config files are plain `key value` text; the parser is ours.
- The history never leaves the Mac and never stores concealed or transient pasteboard items.
- git-flow: branch feature/<name> off develop, merge back with --no-ff; master only via release/X.Y.Z, tagged vX.Y.Z. Semver lives in VERSION.
- Update docs/local/STATUS.md at the end of every session.
