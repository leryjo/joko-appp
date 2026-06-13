#!/usr/bin/env bash
set -e

CONTAINER_NAME="${CONTAINER_NAME:-joko-terminal-data-v5}"

echo "[1] Cek container..."
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME" || {
  echo "Container $CONTAINER_NAME belum running."
  echo "Jalankan dulu: bash run"
  exit 1
}

echo "[2] Jalankan login.py..."

docker exec -it "$CONTAINER_NAME" bash -lc '
cd /joko-app
xvfb-run -a --server-args="-screen 0 1280x720x24" python3 -u login.py
'
