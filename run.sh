#!/bin/bash
set -e

echo "=== Booting DeepSeek Electron App Blocker ==="

# Kill old dev servers
pkill -f "vite" >/dev/null 2>&1 || true
pkill -f "electron" >/dev/null 2>&1 || true

echo "[INFO] Starting Vite dev server..."
npm run dev > .vite.log 2>&1 &

echo "[INFO] Waiting for Vite to become ready..."

timeout=20
elapsed=0
while ! grep -q "Local:" .vite.log; do
    sleep 1
    elapsed=$((elapsed+1))

    if [ $elapsed -gt $timeout ]; then
        echo "[ERROR] Vite failed to start or took too long."
        echo "------ Vite Log ------"
        cat .vite.log
        exit 1
    fi
done

echo "[INFO] Vite is ready. Starting Electron..."

export VITE_DEV_SERVER_URL="http://localhost:5173"

npm run electron