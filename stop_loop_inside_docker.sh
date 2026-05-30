#!/usr/bin/env bash
set -euo pipefail
CONTAINER_NAME="${CONTAINER_NAME:-joko-terminal-data-v5}"

docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME" || {
  echo "Container $CONTAINER_NAME belum running."
  exit 1
}

docker exec -d "$CONTAINER_NAME" bash -lc '
  DATA_DIR="${DATA_DIR:-${BASE_DIR:-/joko-app/data}}"
  rm -f "$DATA_DIR/.loop_enabled.flag" "$DATA_DIR/loop.pid" 2>/dev/null || true
  pkill -f "[l]oop.py" >/dev/null 2>&1 || true
  pkill -f chromedriver >/dev/null 2>&1 || true
  pkill -f chrome >/dev/null 2>&1 || true
  pkill -f chromium >/dev/null 2>&1 || true
  pkill -f Xvfb >/dev/null 2>&1 || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOOP DISABLED + STOPPED by host command" >> "$DATA_DIR/bot_log.txt"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOOP DISABLED + STOPPED by host command" >> "$DATA_DIR/loop_log.txt"
'
echo "Loop dimatikan dan keeper dinonaktifkan."
