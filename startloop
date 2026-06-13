#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-joko-terminal-data-v5}"

echo "[1] Cek container..."
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME" || {
  echo "Container $CONTAINER_NAME belum running. Jalankan dulu: bash run"
  exit 1
}

echo "[2] Cleanup log/lock/flag lama sebelum loop start..."
docker exec "$CONTAINER_NAME" bash -lc '
  DATA_DIR="${DATA_DIR:-${BASE_DIR:-/joko-app/data}}"
  mkdir -p "$DATA_DIR"

  : > "$DATA_DIR/bot_log.txt" || true
  : > "$DATA_DIR/loop_log.txt" || true
  : > "$DATA_DIR/login_log.txt" || true
  : > "$DATA_DIR/akun_bermasalah.txt" || true
  : > "$DATA_DIR/hasil.txt" || true
  echo "{}" > "$DATA_DIR/loop_status.json" || true

  find "$DATA_DIR" -maxdepth 1 -type f -name ".lock_*" -delete 2>/dev/null || true
  find "$DATA_DIR" -maxdepth 1 -type f -name ".lock_joko-app_data_chrome_profiles_joko*.pid" -delete 2>/dev/null || true
  rm -f "$DATA_DIR/loop.pid" "$DATA_DIR/.loop_enabled.flag" 2>/dev/null || true

  echo "CLEANUP DONE"
'

echo "[3] Aktifkan loop keeper + start loop.py detached di Docker..."
docker exec -d "$CONTAINER_NAME" bash -lc '
  CODE_DIR="${CODE_DIR:-/joko-app}"
  DATA_DIR="${DATA_DIR:-${BASE_DIR:-/joko-app/data}}"
  PROFILES_ROOT="${PROFILES_ROOT:-$DATA_DIR/chrome_profiles}"
  SCREEN_LOOP="${SCREEN_LOOP:-1300x800x24}"
  mkdir -p "$DATA_DIR"
  touch "$DATA_DIR/.loop_enabled.flag" "$DATA_DIR/loop_log.txt" "$DATA_DIR/bot_log.txt"

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] LOOP ENABLED by host command" >> "$DATA_DIR/bot_log.txt"

  token="${TG_TOKEN:-}"
  chat="${TG_CHAT_ID:-}"
  if [ -n "$token" ] && [ -n "$chat" ]; then
    curl -fsS -m 15 -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      -d "chat_id=${chat}" \
      --data-urlencode "text=▶️ LOOP START COMMAND
Loop keeper diaktifkan.
Time: $(date "+%Y-%m-%d %H:%M:%S")" >/dev/null 2>&1 || true
  fi

  if pgrep -af "[l]oop.py" >/dev/null 2>&1; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] loop.py already running" >> "$DATA_DIR/loop_log.txt"
    exit 0
  fi

  if ! find "$PROFILES_ROOT" -mindepth 1 -maxdepth 1 -type d -name "joko*" 2>/dev/null | grep -q .; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] LOOP BELUM START: belum ada folder profile jokoX. Jalankan login dulu." | tee -a "$DATA_DIR/loop_log.txt" "$DATA_DIR/bot_log.txt"
    exit 0
  fi

  cd "$CODE_DIR"
  setsid nohup xvfb-run -a --server-args="-screen 0 ${SCREEN_LOOP}" \
    python3 -u "$CODE_DIR/loop.py" >> "$DATA_DIR/loop_log.txt" 2>&1 < /dev/null &
  echo $! > "$DATA_DIR/loop.pid"
  disown || true
'

sleep 2
echo "[4] Cek proses loop..."
docker exec -it "$CONTAINER_NAME" bash -lc 'pgrep -af loop.py || true'

echo "[5] Sesi loop muncul di bawah ini. Tekan CTRL+C hanya untuk keluar dari tampilan log, loop tetap jalan."
echo "================================================================================"
docker exec -it "$CONTAINER_NAME" bash -lc 'tail -n 100 -f /joko-app/data/loop_log.txt'
