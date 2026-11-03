const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '../app/build/web');
const types = {'.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png', '.ttf':'font/ttf', '.otf':'font/otf'};
http.createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.end(await fs.readFile(file));
  } catch { res.writeHead(404).end(); }
}).listen(8088, '127.0.0.1', () => console.log('PWA: http://127.0.0.1:8088'));
