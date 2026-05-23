#!/bin/bash
# AlignmentViewer.command
# Double-click to launch the viewer

DATA_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DATA_DIR"

echo "========================================"
echo "  🧬 Alignment Viewer"
echo "========================================"

# Stop any existing server on port 8765
if lsof -ti tcp:8765 &>/dev/null; then
  echo "  Stopping existing server..."
  lsof -ti tcp:8765 | xargs kill -9 2>/dev/null || true
  sleep 0.5
fi

# Start server
echo "  Starting server..."
python3 scripts/range_server.py &
SERVER_PID=$!

# Wait for server to be ready
sleep 2

# Open browser
echo "  Opening browser..."
open "http://localhost:8765/igv.html"

echo ""
echo "  ✅ Ready"
echo "  URL: http://localhost:8765/igv.html"
echo "  Press Ctrl+C to stop"
echo "========================================"

# Wait for server process
wait $SERVER_PID
