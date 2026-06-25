/**
 * Lightweight HTTP API for the backup-sftp service.
 * Exposes file listing, single download, multi-file zip, and delete.
 * Protected by SFTP_API_KEY env var.
 *
 * Endpoints:
 *   GET  /files          → JSON list of files with size + timestamps
 *   GET  /files/:name    → download single file
 *   POST /files/zip      → { files: ['a.sql','b.sql'] } → zip download
 *   DELETE /files/:name  → delete file
 */

const http     = require('http');
const fs       = require('fs');
const path     = require('path');
const archiver = require('archiver');

const UPLOAD_DIR = process.env.UPLOAD_DIR || '/uploads/incoming';
const PORT       = process.env.HTTP_PORT  || 3001;
const API_KEY    = process.env.SFTP_API_KEY || '';

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

function unauthorized(res) {
  res.writeHead(401, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Unauthorized' }));
}

function notFound(res) {
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
}

function checkAuth(req) {
  if (!API_KEY) return true; // no key configured — open (internal network only)
  const auth = req.headers['authorization'] || '';
  return auth === `Bearer ${API_KEY}`;
}

function safeName(name) {
  // Prevent path traversal
  return path.basename(name);
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');

  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  if (!checkAuth(req)) return unauthorized(res);

  const url = req.url.split('?')[0];

  // GET /files — list all files
  if (req.method === 'GET' && url === '/files') {
    try {
      const entries = fs.readdirSync(UPLOAD_DIR)
        .map(name => {
          try {
            const stat = fs.statSync(path.join(UPLOAD_DIR, name));
            return {
              name,
              size: stat.size,
              modified: stat.mtime.toISOString(),
              created: stat.birthtime.toISOString(),
            };
          } catch { return null; }
        })
        .filter(Boolean)
        .sort((a, b) => new Date(b.modified) - new Date(a.modified));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(entries));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // POST /files/zip — download multiple files as zip
  if (req.method === 'POST' && url === '/files/zip') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      let files;
      try { files = JSON.parse(body).files; } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
        return;
      }
      if (!Array.isArray(files) || files.length === 0) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'No files specified' }));
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'application/zip',
        'Content-Disposition': 'attachment; filename="backups.zip"',
      });
      const archive = archiver('zip', { zlib: { level: 6 } });
      archive.pipe(res);
      for (const name of files) {
        const safe = safeName(name);
        const filePath = path.join(UPLOAD_DIR, safe);
        if (fs.existsSync(filePath)) archive.file(filePath, { name: safe });
      }
      archive.finalize();
    });
    return;
  }

  // GET /files/:name — download single file
  if (req.method === 'GET' && url.startsWith('/files/')) {
    const name = safeName(decodeURIComponent(url.slice(7)));
    const filePath = path.join(UPLOAD_DIR, name);
    if (!fs.existsSync(filePath)) return notFound(res);
    const stat = fs.statSync(filePath);
    res.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${name}"`,
      'Content-Length': stat.size,
    });
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  // DELETE /files/:name — delete a file
  if (req.method === 'DELETE' && url.startsWith('/files/')) {
    const name = safeName(decodeURIComponent(url.slice(7)));
    const filePath = path.join(UPLOAD_DIR, name);
    if (!fs.existsSync(filePath)) return notFound(res);
    try {
      fs.unlinkSync(filePath);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  notFound(res);
});

server.listen(PORT, () => {
  console.log(`[http-server] Listening on port ${PORT}`);
});
