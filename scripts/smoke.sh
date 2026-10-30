#!/bin/sh
# Drive the built app through SPASTE_SMOKE against a seeded throwaway
# history: keys, search, filters, pin and delete. Checks the recorded state
# lines and leaves panel renders in build/smoke/. Never touches the real
# history, config or clipboard.
set -eu

APP=build/sPaste.app/Contents/MacOS/sPaste
OUT=$(pwd)/build/smoke
WORK=$(mktemp -d "${TMPDIR:-/tmp}/spaste-smoke.XXXXXX")
HISTORY=$WORK/history
trap 'rm -rf "$WORK"' EXIT

rm -rf "$OUT"
mkdir -p "$OUT" "$HISTORY"
chmod 700 "$HISTORY"

stamp() {
    date -v-"$1"M +%Y-%m-%d-%H%M%S
}

printf 'deploy script' > "$HISTORY/$(stamp 1)-001.txt"
sips -s format png -Z 64 \
    /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns \
    --out "$HISTORY/$(stamp 5)-001.png" >/dev/null
printf 'invoice 42' > "$HISTORY/$(stamp 30)-001.txt"
printf '/tmp/invoice.pdf\n' > "$HISTORY/$(stamp 90)-001.files"
printf 'Invoice 7\nsecond line' > "$HISTORY/$(stamp 2880)-001.txt"

cat > "$WORK/steps" <<'EOF'
open
state
shot 01-open
keys 3j
state
keys gg
keys /
type inv
state
enter
keys n
state
keys n
state
keys N
state
keys ?
type invoice
state
shot 02-search
esc
state
keys fi
state
shot 03-images
keys fa
keys :
type since 1h
enter
state
keys :
type type text
enter
state
shot 04-filtered
keys :
type clear
enter
keys /
type type:file
state
esc
state
keys G
keys m
state
shot 05-pinned
keys dd
state
keys :
type wipe
enter
state
keys q
EOF

cat > "$WORK/expected" <<'EOF'
normal | deploy script | 5/5 |  |
normal | invoice.pdf | 5/5 |  |
/inv | invoice 42 | 5/5 |  |
normal | invoice.pdf | 5/5 |  |
normal | Invoice 7 | 5/5 |  |
normal | invoice.pdf | 5/5 |  |
?invoice | Invoice 7 | 5/5 |  |
normal | invoice.pdf | 5/5 |  |
normal | image | 1/5 | image |
normal | deploy script | 3/5 | since 1h |
normal | deploy script | 2/5 | text since 1h |
/type:file | invoice.pdf | 1/5 | file |
normal | deploy script | 5/5 |  |
normal | Invoice 7 | 5/5 |  |
normal | deploy script | 4/4 |  |
normal | deploy script | 4/4 |  | use :wipe! to delete the whole history, pinned items included
EOF

SPASTE_SMOKE="$WORK/steps" \
SPASTE_SMOKE_OUT="$OUT" \
SPASTE_HISTORY_DIR="$HISTORY" \
XDG_CONFIG_HOME="$WORK/config" \
    "$APP"

cp "$HISTORY/index" "$OUT/index.txt"
sed 's/ *$//' "$OUT/state.txt" > "$WORK/actual"
if diff -u "$WORK/expected" "$WORK/actual"; then
    echo "smoke: $(wc -l < "$OUT/state.txt" | tr -d ' ') states as expected, renders in $OUT"
else
    echo "smoke: state differs from expected" >&2
    exit 1
fi
if [ "$(ls "$HISTORY" | grep -c '\.txt$')" -ne 2 ]; then
    echo "smoke: dd did not delete the item's file" >&2
    exit 1
fi
