#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
LOGFILE="$(pwd)/logs/app_block.log"
mkdir -p "$(dirname "$LOGFILE")"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

if [[ -z "$APP_NAME" ]]; then
  echo "$(timestamp) [ERROR] No app specified" | tee -a "$LOGFILE"
  exit 1
fi

echo "$(timestamp) [INFO] Blocking application: $APP_NAME" | tee -a "$LOGFILE"

# Placeholder approach: write anchor to /etc/pf.anchors (requires sudo)
ANCHOR="/etc/pf.anchors/deepseek_block_$APP_NAME"
BINNAME="$APP_NAME"

cat > /tmp/deepseek_pf_anchor <<EOF
# deepseek block anchor for $APP_NAME
block drop out quick on en0 inet proto { tcp udp } from any to any
block drop in quick on en0 inet proto { tcp udp } from any to any
