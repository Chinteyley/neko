#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <neko.app> <output.dmg>" >&2
  exit 1
fi

if ! command -v npx >/dev/null; then
  echo "npx is required (Node.js 20+)" >&2
  exit 1
fi

APP_PATH=$1
OUTPUT_PATH=$2

if [[ ! -d $APP_PATH ]]; then
  echo "missing app bundle: $APP_PATH" >&2
  exit 1
fi

APP_PATH=$(cd "$APP_PATH" && pwd)
if [[ $OUTPUT_PATH != /* ]]; then
  OUTPUT_PATH=$PWD/$OUTPUT_PATH
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

npx --yes create-dmg@8.1.0 \
  --overwrite \
  --no-code-sign \
  --no-version-in-filename \
  --dmg-title=neko \
  "$APP_PATH" \
  "$STAGE"

shopt -s nullglob
produced=("$STAGE"/*.dmg)
if [[ ${#produced[@]} -ne 1 ]]; then
  echo "expected one disk image in $STAGE" >&2
  ls -la "$STAGE" >&2
  exit 1
fi

mv "${produced[0]}" "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
