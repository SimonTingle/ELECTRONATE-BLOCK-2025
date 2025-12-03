import { app, BrowserWindow, ipcMain } from 'electron'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

let win

// --------------------------------------------------
// IPC HANDLER: return installed applications
// --------------------------------------------------
ipcMain.handle('get-applications', async () => {
  try {
    const appDirs = [
      '/Applications',
      path.join(process.env.HOME, 'Applications')
    ]

    let apps = []

    for (const dir of appDirs) {
      if (!fs.existsSync(dir)) continue
      const files = fs.readdirSync(dir).filter(f => f.endsWith('.app'))
      apps.push(...files)
    }

    apps.sort()
    return apps

  } catch (err) {
    console.error('IPC get-applications error:', err)
    return []
  }
})

// --------------------------------------------------

function createWindow() {
  win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  if (process.env.NODE_ENV === 'development') {
    win.loadURL('http://localhost:5173')
    win.webContents.openDevTools()
  } else {
    win.loadFile(path.join(__dirname, '../dist/index.html'))
  }
}

app.whenReady().then(() => {
  if (process.env.NODE_ENV === 'development') {
    process.env.VITE_DEV_SERVER_URL = 'http://localhost:5173'
  }
  createWindow()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})