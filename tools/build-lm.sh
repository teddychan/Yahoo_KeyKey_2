#!/bin/bash
# Build the McBopomofo language model (data.txt) and copy it to Resources/.
# Requires: git, python3, make. Produces ./Resources/data.txt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.lm-build"

# Pinned upstream revision for the bundled language-model data (supply-chain
# safety). REVIEW AND UPDATE THIS DELIBERATELY: bump it only after inspecting
# the upstream changes, since the resulting data.txt ships inside the app.
# Resolve the current HEAD with:
#   git ls-remote https://github.com/openvanilla/McBopomofo HEAD
MCBOPOMOFO_SHA="040097ebc32a6287e6c4d36ceab7c32fd1e1c2a2"

mkdir -p "$WORK" "$ROOT/Resources"
if [ ! -d "$WORK/McBopomofo" ]; then
  git clone --depth 1 https://github.com/openvanilla/McBopomofo "$WORK/McBopomofo"
fi
git -C "$WORK/McBopomofo" fetch --depth 1 origin "$MCBOPOMOFO_SHA"
git -C "$WORK/McBopomofo" checkout --detach "$MCBOPOMOFO_SHA"
HEAD_SHA="$(git -C "$WORK/McBopomofo" rev-parse HEAD)"
if [ "$HEAD_SHA" != "$MCBOPOMOFO_SHA" ]; then
  echo "ERROR: McBopomofo checkout is $HEAD_SHA, expected pinned $MCBOPOMOFO_SHA" >&2
  exit 1
fi
cd "$WORK/McBopomofo/Source/Data"
make            # runs main_compiler.py -> data.txt
[ -s data.txt ] || { echo "ERROR: make produced no data.txt (empty or missing)" >&2; exit 1; }
cp data.txt "$ROOT/Resources/data.txt"
echo "Wrote $ROOT/Resources/data.txt ($(wc -l < "$ROOT/Resources/data.txt") lines)"
