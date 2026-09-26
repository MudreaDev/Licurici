// Punte minimă și sigură între procesul principal și interfață.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('licurici', {
  // Meniul poate cere navigarea (ex: „Despre").
  onNav: (callback) => ipcRenderer.on('nav', (_event, dest) => callback(dest)),
  platform: process.platform,
  isElectron: true
});
