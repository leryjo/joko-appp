#!/usr/bin/env bash
set -euo pipefail

CODE_DIR="${CODE_DIR:-/joko-app}"
BASE_DIR="${BASE_DIR:-/joko-app/data}"
DATA_DIR="${DATA_DIR:-$BASE_DIR}"
PROFILES_ROOT="${PROFILES_ROOT:-$DATA_DIR/chrome_profiles}"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python || echo python3)}"
SCREEN_LOOP="${SCREEN_LOOP:-1300x800x24}"
LOOP_KEEPER_SECONDS="${LOOP_KEEPER_SECONDS:-20}"

export CODE_DIR BASE_DIR DATA_DIR PROFILES_ROOT PYTHONUNBUFFERED=1

BOT_LOG="$DATA_DIR/bot_log.txt"
LOOP_LOG="$DATA_DIR/loop_log.txt"
LOOP_PID="$DATA_DIR/loop.pid"
LOOP_ENABLED_FLAG="$DATA_DIR/.loop_enabled.flag"

mkdir -p "$DATA_DIR/chrome_profiles" "$DATA_DIR/screenshots" "$DATA_DIR/snapshots" "$DATA_DIR/notif_markers"
touch "$DATA_DIR/email.txt" "$DATA_DIR/emailshare.txt" "$DATA_DIR/mapping_profil.txt" \
      "$DATA_DIR/bot_log.txt" "$DATA_DIR/login_log.txt" "$DATA_DIR/loop_log.txt" \
      "$DATA_DIR/hasil.txt" "$DATA_DIR/akun_bermasalah.txt" "$DATA_DIR/loop_status.json"
[ -s "$DATA_DIR/loop_status.json" ] || echo '{}' > "$DATA_DIR/loop_status.json"

now(){ date '+%Y-%m-%d %H:%M:%S'; }
log(){ printf '[%s] %s\n' "$(now)" "$*" | tee -a "$BOT_LOG"; }

tg_send(){
  local text="$1"
  local token="${TG_TOKEN:-}"
  local chat="${TG_CHAT_ID:-}"
  [ -n "$token" ] && [ -n "$chat" ] || return 0
  curl -fsS -m 15 -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat}" --data-urlencode "text=${text}" >/dev/null 2>&1 || true
}

safe_recovery(){
  log "RECOVERY cleaning stale Chrome/Xvfb locks/cache"
  pkill -f chromedriver >/dev/null 2>&1 || true
  pkill -f google-chrome >/dev/null 2>&1 || true
  pkill -f chrome >/dev/null 2>&1 || true
  pkill -f chromium >/dev/null 2>&1 || true
  pkill -f Xvfb >/dev/null 2>&1 || true
  if [ -d "$PROFILES_ROOT" ]; then
    find "$PROFILES_ROOT" -name 'Singleton*' -delete 2>/dev/null || true
    find "$PROFILES_ROOT" -name '*.lock' -delete 2>/dev/null || true
    find "$PROFILES_ROOT" -name 'Crashpad' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROFILES_ROOT" -path '*/Cache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROFILES_ROOT" -path '*/Code Cache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROFILES_ROOT" -path '*/GPUCache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROFILES_ROOT" -path '*/DawnCache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROFILES_ROOT" -path '*/GrShaderCache' -type d -exec rm -rf {} + 2>/dev/null || true
  fi
  rm -f /tmp/.X99-lock /tmp/.X*-lock 2>/dev/null || true
}

has_profiles(){
  find "$PROFILES_ROOT" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex '.*/joko[0-9]+' 2>/dev/null | grep -q .
}

proc_running(){ pgrep -af "$1" >/dev/null 2>&1; }

start_loop_detached(){
  [ -f "$CODE_DIR/loop.py" ] || { log "loop.py tidak ditemukan: $CODE_DIR/loop.py"; return 1; }
  if proc_running '[l]oop.py'; then return 0; fi
  if ! has_profiles; then
    log "Loop belum start: belum ada profile jokoX. Jalankan login dulu sampai sukses."
    tg_send "⚠️ LOOP BELUM START\nBelum ada profile jokoX. Jalankan login dulu sampai sukses.\nTime: $(now)"
    return 1
  fi
  log "START loop.py detached + Docker keeper"
  tg_send "▶️ LOOP STARTED\nMode: Docker detached + keeper aktif\nTime: $(now)"
  printf '[%s] ===== DOCKER START loop detached =====\n' "$(now)" >> "$LOOP_LOG"
  cd "$CODE_DIR"
  setsid nohup xvfb-run -a --server-args="-screen 0 ${SCREEN_LOOP}" \
    "$PYTHON_BIN" -u "$CODE_DIR/loop.py" >> "$LOOP_LOG" 2>&1 < /dev/null &
  echo $! > "$LOOP_PID"
  disown || true
}

loop_keeper(){
  log "Container aktif. Tidak ada panel/menu. Login dan loop tidak auto-run."
  log "Loop keeper standby, aktif setelah start_loop_inside_docker.sh membuat flag: $LOOP_ENABLED_FLAG"
  local was_running=0
  while true; do
    if [ -f "$LOOP_ENABLED_FLAG" ]; then
      if proc_running '[l]oop.py'; then
        was_running=1
      else
        if [ "$was_running" = "1" ]; then
          log "LOOP CRASH/STOP terdeteksi. Keeper auto restart loop.py"
          tg_send "❌ LOOP CRASH / STOP TERDETEKSI\nAction: Docker keeper auto restart loop.py\nTime: $(now)"
        fi
        if start_loop_detached; then
          if [ "$was_running" = "1" ]; then
            tg_send "🔄 LOOP RESTARTED\nReason: process loop.py tidak ditemukan\nTime: $(now)"
          fi
          was_running=1
        fi
      fi
    else
      was_running=0
    fi
    sleep "$LOOP_KEEPER_SECONDS"
  done
}

echo '=================================================='
echo ' JOKO FULL DOCKER - NO PANEL '
echo " CODE_DIR      : $CODE_DIR"
echo " DATA_DIR      : $DATA_DIR"
echo " PROFILES_ROOT : $PROFILES_ROOT"
echo ' MODE          : READY / LOGIN MANUAL / LOOP MANUAL + KEEPER'
echo '=================================================='

safe_recovery
tg_send "🚀 DOCKER STARTED\nContainer: ${HOSTNAME:-joko-terminal-data-v5}\nMode: NO PANEL / MANUAL LOGIN / MANUAL LOOP\nTime: $(now)"
loop_keeper &

echo "Container aktif."
echo "Start login : bash login"
echo "Start loop  : bash startloop"
echo "Stop loop   : bash stoploop"
echo "Docker logs : docker logs -f <container>"
tail -f /dev/null
