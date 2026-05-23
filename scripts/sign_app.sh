#!/usr/bin/env bash
# sign_app.sh — Apply ad-hoc code signature to AlignmentViewer.app
#
# Run this whenever AlignmentViewer.app is updated (AppleScript recompiled etc.)
# Usage:
#   bash scripts/sign_app.sh

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/AlignmentViewer.app"

if [[ ! -d "$APP" ]]; then
  echo "❌ AlignmentViewer.app not found: $APP"
  exit 1
fi

echo "Signing AlignmentViewer.app..."
codesign --force --deep --sign - "$APP"
echo "✅ Signed: $APP"
