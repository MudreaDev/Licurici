// Curcubeu — proces principal Electron.
// Deschide o fereastră care încarcă aplicația locală (src/index.html).
const { app, BrowserWindow, Menu, shell } = require('electron');
const path = require('path');

// Un singur exemplar al aplicației.
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
}

let mainWindow = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1180,
    height: 820,
    minWidth: 900,
    minHeight: 680,
    backgroundColor: '#eaf4f4', // fundal calm cât se încarcă (fără flash alb)
    title: 'Licurici',
    icon: path.join(__dirname, 'assets', process.platform === 'win32' ? 'icon.ico' : 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      spellcheck: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));

  // Linkurile externe se deschid în browser, nu în aplicație.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// Meniu minimalist (fără distrageri). Doar esențialul + fullscreen.
function buildMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: 'Aplicație',
      submenu: [
        { role: 'togglefullscreen', label: 'Ecran complet' },
        { type: 'separator' },
        isMac ? { role: 'close', label: 'Închide' } : { role: 'quit', label: 'Ieșire' }
      ]
    },
    {
      label: 'Ajutor',
      submenu: [
        {
          label: 'Despre Licurici',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('nav', 'despre');
          }
        }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// Pornim serverul Paper Aquarium în fundal
try {
  require(path.join(__dirname, 'paper-aquarium', 'server.js'));
} catch (e) {
  console.error('Pornire paper-aquarium:', e.message);
}

app.whenReady().then(() => {
  const { session } = require('electron');
  session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
    if (permission === 'media' || permission === 'camera') {
      callback(true);
    } else {
      callback(false);
    }
  });

  buildMenu();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
