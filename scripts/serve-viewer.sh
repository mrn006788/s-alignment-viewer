#!/usr/bin/env bash
# serve-viewer.sh — IGV.js ビューアをローカルサーバで起動する
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT=8765
VIEWER="$ROOT_DIR/output/viewer.html"
URL="http://localhost:${PORT}/output/viewer.html"

echo "========================================"
echo " Alignment Viewer"
echo "========================================"
echo " 配信ディレクトリ : $ROOT_DIR"
echo " ポート           : $PORT"
echo " ブラウザURL      : $URL"
echo "========================================"
echo " 終了するには Ctrl+C を押してください"
echo "========================================"
echo ""

# ポートが使用中なら既存プロセスを終了
if lsof -ti tcp:$PORT &>/dev/null; then
  echo "⚠ ポート $PORT が使用中 → 既存プロセスを終了します"
  lsof -ti tcp:$PORT | xargs kill -9 2>/dev/null || true
  sleep 0.5
fi

# ブラウザを自動オープン（macOS）
if command -v open &>/dev/null; then
  sleep 1 && open "$URL" &
fi

# Python HTTP サーバ起動（BAMへのRange requestsをサポート）
cd "$ROOT_DIR"
python3 -m http.server $PORT --bind 127.0.0.1
