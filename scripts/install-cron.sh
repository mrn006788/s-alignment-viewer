#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT_DIR/logs"
JOB="0 * * * * cd ${ROOT_DIR} && ${ROOT_DIR}/scripts/hourly-log.sh >> ${ROOT_DIR}/logs/cron-runner.log 2>&1"

tmpfile="$(mktemp)"
crontab -l 2>/dev/null | grep -v 'scripts/hourly-log.sh' > "$tmpfile" || true
echo "$JOB" >> "$tmpfile"
crontab "$tmpfile"
rm -f "$tmpfile"

echo "Installed cron job: $JOB"
