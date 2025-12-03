#!/bin/bash
# run.sh — Robust launcher for DeepSeek Electron App

set -e  # Exit immediately if a command fails
set -o pipefail  # Catch failures in piped commands

APP_NAME="DeepSeek Electron App Blocker"
DEV_SERVER_URL="http://localhost:5173"

echo "=== Booting $APP_NAME ==="

# Check Node and NPM
if ! command -v node >/dev/null 2>&1; then
  echo "[ERROR] Node.js is not installed. Please install it first."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[ERROR] npm is not installed. Please install it first."
  exit 1
fi

# Install dependencies if node_modules is missing
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Determine mode: development or production
MODE=${1:-development}  # default to development if no argument provided

if [ "$MODE" = "development" ]; then
  echo "[INFO] Running in development mode (with HMR)..."
  # Start Vite dev server in background
  npm run dev &
  VITE_PID=$!

  # Wait for Vite dev server to start
  echo "Waiting for Vite dev server..."
  while ! curl --output /dev/null --silent --head --fail "$DEV_SERVER_URL"; do
    sleep 1
  done

  # Launch Electron
  echo "[INFO] Starting Electron..."
  NODE_ENV=development npm run electron

  # Cleanup
  echo "[INFO] Stopping Vite dev server..."
  kill $VITE_PID

else
  echo "[INFO] Running in production mode..."
  echo "[INFO] Building frontend..."
  npm run build

  echo "[INFO] Launching Electron..."
  NODE_ENV=production npm run electron
fi

echo "=== $APP_NAME terminated ==="
