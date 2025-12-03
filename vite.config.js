import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"

export default defineConfig({
  plugins: [react()],
  root: "./",
  publicDir: "public",
  base: "",               // ensures Electron can load files from dist correctly
  build: {
    outDir: "dist",
    emptyOutDir: true,    // clears old builds
  },
})