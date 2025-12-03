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
