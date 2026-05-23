#!/usr/bin/env bash
# build_app.sh — Rebuild AlignmentViewer.app from source
#
# Run this after editing igv_launcher_v3.applescript or any bundled script.
# Usage:
#   bash scripts/build_app.sh

set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
APP="$ROOT_DIR/AlignmentViewer.app"
APPLESCRIPT="$ROOT_DIR/igv_launcher_v3.applescript"

echo "========================================"
echo " Building AlignmentViewer.app"
echo "========================================"

# ── 1. AppleScript source check ───────────────────────────────────
if [[ ! -f "$APPLESCRIPT" ]]; then
  echo "❌ Source script not found: $APPLESCRIPT"
  exit 1
fi

# ── 2. App bundle check ───────────────────────────────────────────
if [[ ! -d "$APP" ]]; then
  echo "❌ AlignmentViewer.app not found: $APP"
  echo "   Please place an existing droplet-type .app bundle there first."
  exit 1
fi

# ── 3. Compile AppleScript → main.scpt ───────────────────────────
echo ""
echo "Step 1/4: Compiling AppleScript..."
SCPT="$APP/Contents/Resources/Scripts/main.scpt"
osacompile -o "$SCPT" "$APPLESCRIPT"
echo "   → $SCPT"

# ── 4. Bundle scripts into app ────────────────────────────────────
echo ""
echo "Step 2/4: Bundling scripts into app..."
BUNDLE_SCRIPTS="$APP/Contents/Resources/scripts"
mkdir -p "$BUNDLE_SCRIPTS"
for f in setup_viewer.sh make_jsons.py range_server.py; do
  cp "$SCRIPTS_DIR/$f" "$BUNDLE_SCRIPTS/$f"
  echo "   → $f"
done
chmod +x "$BUNDLE_SCRIPTS/setup_viewer.sh"

# ── 5. Bundle igv.html template ───────────────────────────────────
echo ""
echo "Step 3/4: Bundling igv.html template..."
cp "$ROOT_DIR/igv.html" "$APP/Contents/Resources/igv.html"
echo "   → igv.html"

# ── 6. Sign ──────────────────────────────────────────────────────
echo ""
echo "Step 4/4: Signing app..."
codesign --force --deep --sign - "$APP"
echo "   → Signed"

echo ""
echo "========================================"
echo " ✅ Build complete!"
echo " $APP"
echo "========================================"
