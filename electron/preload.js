const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getApplications: () => ipcRenderer.invoke('get-applications'),
  // placeholder for future methods
});
