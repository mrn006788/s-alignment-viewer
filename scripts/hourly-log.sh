#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TZ_VALUE="${TZ:-Asia/Tokyo}"
STAMP="$(TZ="$TZ_VALUE" date +%Y%m%d_%H%M%S)"
HUMAN_TIME="$(TZ="$TZ_VALUE" date '+%Y-%m-%d %H:%M:%S %Z')"
LOG_DIR="logs"
OUT_DIR="output"
ARCHIVE_DIR="archive"
LOG_FILE="${LOG_DIR}/${STAMP}.log"

mkdir -p "$LOG_DIR" "$OUT_DIR" "$ARCHIVE_DIR"

archive_existing_outputs() {
  shopt -s nullglob
  for f in "$OUT_DIR"/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    mv "$f" "$ARCHIVE_DIR/${STAMP}_${base}"
  done
  shopt -u nullglob
}

{
  echo "timestamp=${HUMAN_TIME}"
  echo "cwd=${ROOT_DIR}"
  echo "hostname=$(hostname 2>/dev/null || true)"
  echo "user=$(whoami 2>/dev/null || true)"
  echo "--- git status ---"
  git status --short 2>/dev/null || true
  echo "--- docker compose ps ---"
  docker compose ps 2>/dev/null || true
  echo "--- docker ps ---"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || true
} >> "$LOG_FILE"

archive_existing_outputs

echo "hourly log saved: $LOG_FILE"
