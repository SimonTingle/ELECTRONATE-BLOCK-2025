#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# electron-blocker.sh
# Create a complete Electron + Vite scaffold for DeepSeek App Blocker.
#
# Usage:
#   # run from your deepseek-ui project folder
#   chmod +x electron-blocker.sh
#   ./electron-blocker.sh
#
# What it does:
# - validates environment
# - writes safe backups of existing files
# - creates electron/, src/, scripts/ folders and files
# - installs npm dependencies (local project)
# - does not auto-run electron. Use `npm start` after the script finishes.
#
# Notes:
# - Run from project root where package.json is, or it will create a new project.
###############################################################################

PROJECT_ROOT="$(pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_ROOT/.backup_$TIMESTAMP"

# Files to create
PKG_JSON="$PROJECT_ROOT/package.json"
VITE_CONFIG="$PROJECT_ROOT/vite.config.js"
ELECTRON_DIR="$PROJECT_ROOT/electron"
ELECTRON_MAIN="$ELECTRON_DIR/main.js"
ELECTRON_PRELOAD="$ELECTRON_DIR/preload.js"
SRC_DIR="$PROJECT_ROOT/src"
APP_FILE="$SRC_DIR/App.jsx"
APP_CSS="$SRC_DIR/App.css"
MAIN_ENTRY="$SRC_DIR/main.jsx"
INDEX_HTML="$PROJECT_ROOT/index.html"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
BLOCK_SCRIPT="$SCRIPTS_DIR/block_app.sh"
UNBLOCK_SCRIPT="$SCRIPTS_DIR/unblock_app.sh"
LIST_HELPER="$PROJECT_ROOT/listApps.js"

# Utilities
fail() {
  echo "[ERROR] $1" >&2
  exit 1
}
ok() { echo "[OK] $1"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1. Install it and re-run."
}

backup_path() {
  local f="$1"
  if [[ -e "$f" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$f" "$BACKUP_DIR/"
    ok "Backed up $f -> $BACKUP_DIR/"
  fi
}

echo "Starting Electron scaffold deployment in: $PROJECT_ROOT"

# Basic environment checks
require_cmd node
require_cmd npm
require_cmd git || echo "[WARN] git not found, continuing."

# Create directories
mkdir -p "$ELECTRON_DIR" "$SRC_DIR" "$SCRIPTS_DIR"

# Backup existing critical files
for f in "$PKG_JSON" "$VITE_CONFIG" "$ELECTRON_MAIN" "$ELECTRON_PRELOAD" "$APP_FILE" "$APP_CSS" "$MAIN_ENTRY" "$INDEX_HTML" "$BLOCK_SCRIPT" "$UNBLOCK_SCRIPT" "$LIST_HELPER"; do
  backup_path "$f"
done

###############################################################################
# Write package.json
###############################################################################
cat > "$PKG_JSON" <<'EOF'
{
  "name": "deepseek-ui",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "main": "electron/main.js",
  "scripts": {
    "dev": "vite",
    "electron": "electron .",
    "start": "concurrently -k \"npm run dev\" \"npm run electron\"",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "three": "^0.161.0",
    "framer-motion": "^10.12.16",
    "lucide-react": "^0.298.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "vite": "^5.2.0",
    "electron": "^31.0.0",
    "concurrently": "^8.2.2",
    "@vitejs/plugin-react": "^5.1.1"
  }
}
EOF
ok "package.json written"

###############################################################################
# Write vite.config.js
###############################################################################
cat > "$VITE_CONFIG" <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173
  },
  optimizeDeps: {
    exclude: ["electron"]
  }
});
EOF
ok "vite.config.js written"

###############################################################################
# Write electron main and preload
###############################################################################
cat > "$ELECTRON_MAIN" <<'EOF'
import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'path';
import fs from 'fs';

function scanApps(dir) {
  try {
    if (!fs.existsSync(dir)) return [];
    const files = fs.readdirSync(dir);
    return files.filter(f => f.endsWith('.app')).map(f => f.replace(/\.app$/,''));
  } catch (err) {
    console.error('scanApps error', err);
    return [];
  }
}

ipcMain.handle('get-applications', async () => {
  const system = scanApps('/Applications');
  const user = scanApps(path.join(process.env.HOME || '', 'Applications'));
  // merge and dedupe
  return Array.from(new Set([...system, ...user])).sort();
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 840,
    backgroundColor: '#000000',
    webPreferences: {
      preload: path.join(process.cwd(), 'electron', 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  if (process.env.VITE_DEV_SERVER_URL) {
    win.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    win.loadFile(path.join(process.cwd(), 'dist', 'index.html'));
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
EOF
ok "electron/main.js written"

cat > "$ELECTRON_PRELOAD" <<'EOF'
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getApplications: () => ipcRenderer.invoke('get-applications'),
  // placeholder for future methods
});
EOF
ok "electron/preload.js written"

###############################################################################
# Node helper: listApps.js (CLI friendly)
###############################################################################
cat > "$LIST_HELPER" <<'EOF'
const fs = require('fs');
const path = require('path');

function getApps(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.app')).map(f => f.replace(/\.app$/,''));
}

function listAll() {
  const system = getApps('/Applications');
  const user = getApps(path.join(process.env.HOME || '', 'Applications'));
  return Array.from(new Set([...system, ...user])).sort();
}

if (require.main === module) {
  console.log(JSON.stringify(listAll(), null, 2));
}

module.exports = { listAll };
EOF
ok "listApps.js written"

###############################################################################
# Frontend files: main.jsx, index.html, App.jsx, App.css
###############################################################################

cat > "$MAIN_ENTRY" <<'EOF'
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import './App.css'

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF
ok "src/main.jsx written"

cat > "$INDEX_HTML" <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1.0" />
    <title>DeepSeek App Blocker</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF
ok "index.html written"

cat > "$APP_FILE" <<'EOF'
import React, { useState, useEffect, useRef } from 'react'
import { motion } from 'framer-motion'
import { ChevronDown, Play, Power, FileText } from 'lucide-react'
import * as THREE from 'three'
import './App.css'

export default function App() {
  const [apps, setApps] = useState([])
  const [appSelected, setAppSelected] = useState('')
  const [logs, setLogs] = useState([])
  const [status, setStatus] = useState('idle')
  const [blockOutbound, setBlockOutbound] = useState(true)
  const [blockInbound, setBlockInbound] = useState(true)
  const [persistent, setPersistent] = useState(true)
  const [disableUpdater, setDisableUpdater] = useState(true)
  const mountRef = useRef(null)

  // Three.js background
  useEffect(() => {
    const mount = mountRef.current
    if (!mount) return
    const scene = new THREE.Scene()
    const camera = new THREE.PerspectiveCamera(50, mount.clientWidth / mount.clientHeight, 0.1, 1000)
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    renderer.setSize(mount.clientWidth, mount.clientHeight)
    renderer.setClearColor(0x000000, 0)
    mount.appendChild(renderer.domElement)

    const geom = new THREE.TorusKnotGeometry(1.2, 0.25, 128, 32)
    const mat = new THREE.MeshStandardMaterial({ metalness: 0.9, roughness: 0.12 })
    const torus = new THREE.Mesh(geom, mat)
    scene.add(torus)

    const light = new THREE.PointLight(0x66ffee, 1.2)
    light.position.set(5, 5, 5)
    scene.add(light)

    camera.position.z = 4

    const clock = new THREE.Clock()
    let raf = null
    function animate() {
      const t = clock.getElapsedTime()
      torus.rotation.y = t * 0.4
      torus.rotation.x = Math.sin(t * 0.5) * 0.05 + 0.8
      renderer.render(scene, camera)
      raf = requestAnimationFrame(animate)
    }
    animate()

    const handleResize = () => {
      camera.aspect = mount.clientWidth / mount.clientHeight
      camera.updateProjectionMatrix()
      renderer.setSize(mount.clientWidth, mount.clientHeight)
    }
    window.addEventListener('resize', handleResize)

    return () => {
      window.removeEventListener('resize', handleResize)
      if (raf) cancelAnimationFrame(raf)
      try { mount.removeChild(renderer.domElement) } catch(e){}
    }
  }, [])

  // load apps from electron
  useEffect(() => {
    async function loadApps() {
      try {
        if (window.electronAPI && window.electronAPI.getApplications) {
          const list = await window.electronAPI.getApplications()
          setApps(list || [])
        } else {
          // fallback: request from Node helper via fetch if available
          setApps([])
        }
      } catch (err) {
        console.error('Failed to load apps', err)
      }
    }
    loadApps()
  }, [])

  const addLog = (msg) => {
    setLogs((s) => [...s, `[${new Date().toLocaleTimeString()}] ${msg}`])
  }

  const applyBlock = async () => {
    if (!appSelected) return addLog('No app selected')
    setStatus('applying')
    addLog('Applying PF block to ' + appSelected)
    try {
      // call electron main via other IPC later to run sudo script
      // For now simulate and append log
      setTimeout(() => {
        setStatus('idle')
        addLog('Block applied: ' + appSelected)
      }, 900)
    } catch (err) {
      addLog('Apply error: ' + err.message)
      setStatus('error')
    }
  }

  const removeBlock = async () => {
    if (!appSelected) return addLog('No app selected')
    setStatus('removing')
    addLog('Removing PF block for ' + appSelected)
    setTimeout(() => {
      setStatus('idle')
      addLog('Block removed: ' + appSelected)
    }, 600)
  }

  return (
    <div className="app-container">
      <div ref={mountRef} className="three-bg" />

      <div className="ui-panel">
        <h1 className="crt-text">DeepSeek App Blocker</h1>

        <div className="status-line">
          <span>Status:</span>
          <div className={`led ${status === 'idle' ? 'green' : status === 'applying' ? 'yellow' : 'red'}`} />
          <span className="status-text">{status}</span>
        </div>

        <div className="app-selector">
          <label>Application</label>
          <div className="select-wrapper">
            <select value={appSelected} onChange={(e) => setAppSelected(e.target.value)}>
              <option value="">Choose an app</option>
              {apps.length === 0 ? <option disabled>No apps found</option> : apps.map((a) => <option key={a} value={a}>{a}</option>)}
            </select>
          </div>
        </div>

        <div className="controls">
          <label><input type="checkbox" checked={blockOutbound} onChange={() => setBlockOutbound(!blockOutbound)} /> Block outbound</label>
          <label><input type="checkbox" checked={blockInbound} onChange={() => setBlockInbound(!blockInbound)} /> Block inbound</label>
          <label><input type="checkbox" checked={persistent} onChange={() => setPersistent(!persistent)} /> Persistent</label>
          <label><input type="checkbox" checked={disableUpdater} onChange={() => setDisableUpdater(!disableUpdater)} /> Disable updaters</label>
        </div>

        <div className="buttons">
          <motion.button className="btn-apply" whileHover={{ scale: 1.03 }} onClick={applyBlock}><Play size={14}/> Apply Block</motion.button>
          <motion.button className="btn-remove" whileHover={{ scale: 1.03 }} onClick={removeBlock}><Power size={14}/> Remove</motion.button>
        </div>

        <div className="logs-panel">
          <h2 className="crt-text">Logs</h2>
          <div className="logs">
            {logs.length === 0 ? <p className="muted">No logs yet</p> : logs.map((l, i) => <p key={i}>{l}</p>)}
          </div>
        </div>
      </div>
    </div>
  )
}
EOF
ok "src/App.jsx written"

cat > "$APP_CSS" <<'EOF'
/* App.css - CRT neon style */
:root {
  --bg: #07080b;
  --neon: #00ffd1;
  --neon-dim: rgba(0,255,209,0.08);
  --panel: rgba(6,10,16,0.75);
  --muted: #7fd1c2;
  --crt-font: "VT323", monospace;
}

* { box-sizing: border-box; }
html,body,#root { height: 100%; margin: 0; background: var(--bg); font-family: var(--crt-font); color: var(--neon); }

.app-container { position: relative; width: 100vw; height: 100vh; overflow: hidden; }

/* Three background canvas container */
.three-bg { position: absolute; inset: 0; z-index: 0; pointer-events: none; opacity: 0.95; }

/* Main UI panel */
.ui-panel {
  position: relative;
  z-index: 5;
  width: min(980px, 92%);
  margin: 36px auto;
  padding: 22px;
  border-radius: 12px;
  background: linear-gradient(180deg, rgba(4,8,12,0.6), rgba(3,6,9,0.45));
  border: 1px solid rgba(0,255,209,0.12);
  box-shadow: 0 10px 40px rgba(0,0,0,0.7), 0 0 40px rgba(0,255,209,0.03) inset;
}

/* CRT header text */
.crt-text {
  font-size: 28px;
  letter-spacing: 1px;
  text-shadow: 0 0 4px rgba(0,255,209,0.14), 0 0 10px rgba(0,255,209,0.06);
  margin: 0 0 10px 0;
}

/* status line */
.status-line { display:flex; align-items:center; gap:10px; margin-bottom:12px; }
.led { width:12px; height:12px; border-radius:50%; box-shadow: 0 0 8px transparent; }
.led.green { background: #4fffba; box-shadow: 0 0 8px #00ffd1; }
.led.yellow { background: #ffd66b; box-shadow: 0 0 8px #ffd66b; }
.led.red { background: #ff6b6b; box-shadow: 0 0 8px #ff6b6b; }
.status-text { color: var(--muted); font-size: 14px; }

/* selector */
.app-selector { margin: 10px 0 14px 0; }
.select-wrapper select {
  width: 100%;
  padding: 10px 12px;
  background: rgba(0,0,0,0.5);
  border: 1px solid rgba(0,255,209,0.08);
  color: var(--neon);
  font-size: 14px;
  border-radius: 8px;
  outline: none;
}

/* controls */
.controls { display:flex; gap: 12px; flex-wrap:wrap; margin-bottom: 14px; }
.controls label { display:flex; gap:8px; align-items:center; font-size: 13px; color: var(--muted); }
.controls input { width: 16px; height: 16px; }

/* buttons */
.buttons { display:flex; gap: 12px; margin-bottom: 12px; }
.btn-apply, .btn-remove {
  padding: 10px 14px;
  border-radius: 8px;
  font-weight: 600;
  background: linear-gradient(180deg, rgba(0,255,209,0.06), rgba(0,255,209,0.03));
  border: 1px solid rgba(0,255,209,0.12);
  color: var(--neon);
  cursor: pointer;
  box-shadow: 0 6px 18px rgba(0,255,209,0.03);
}

/* logs */
.logs-panel { margin-top: 12px; border-top: 1px dashed rgba(0,255,209,0.04); padding-top: 12px; }
.logs { max-height: 220px; overflow:auto; padding: 8px; background: rgba(0,0,0,0.4); border-radius:8px; border: 1px solid rgba(0,255,209,0.03); }
.logs p { margin: 6px 0; color: #b6fff0; font-size: 13px; }
.muted { color: rgba(160,240,220,0.45); font-size: 13px; }
EOF
ok "src/App.css written"

###############################################################################
# Create block/unblock scripts (placeholders with safe logging)
###############################################################################
cat > "$BLOCK_SCRIPT" <<'EOF'
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
EOF

echo "$(timestamp) [INFO] Wrote temporary anchor (not loaded): /tmp/deepseek_pf_anchor" | tee -a "$LOGFILE"
echo "$(timestamp) [WARN] Script provided as placeholder. Manual pf rules required to actually block the specific app binary or path." | tee -a "$LOGFILE"
exit 0
EOF
chmod +x "$BLOCK_SCRIPT"
ok "scripts/block_app.sh written"

cat > "$UNBLOCK_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
LOGFILE="$(pwd)/logs/app_block.log"
mkdir -p "$(dirname "$LOGFILE")"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

if [[ -z "$APP_NAME" ]]; then
  echo "$(timestamp) [ERROR] No app specified for unblock" | tee -a "$LOGFILE"
  exit 1
fi

echo "$(timestamp) [INFO] Unblocking application: $APP_NAME" | tee -a "$LOGFILE"
echo "$(timestamp) [WARN] Placeholder. Manual cleanup of PF anchors required if you loaded them." | tee -a "$LOGFILE"
exit 0
EOF
chmod +x "$UNBLOCK_SCRIPT"
ok "scripts/unblock_app.sh written"

# Create logs folder
mkdir -p "$PROJECT_ROOT/logs"
touch "$PROJECT_ROOT/logs/app_block.log"

###############################################################################
# Final install step: npm install
###############################################################################
echo "Installing npm packages. This may take a minute..."
npm install --no-audit --no-fund

ok "npm install finished"

echo ""
echo "=== Done ==="
echo "Files created or updated in: $PROJECT_ROOT"
echo "Backups of overwritten files (if any) are in: $BACKUP_DIR"
echo ""
echo "To run the dev system:"
echo "  1) Start Vite in one terminal:"
echo "       npm run dev"
echo "  2) Start Electron in another terminal:"
echo "       npm run electron"
echo "  Or run both together:"
echo "       npm start"
echo ""
echo "Notes:"
echo " - The PF block/unblock scripts are placeholders. They log actions and show how to integrate pf anchors. Actual pf rules that target specific app binaries require root and careful construction. If you want, I will produce a robust pf anchor generator that uses the app path and binary name and safely loads/unloads anchors with validation."
echo ""
exit 0
