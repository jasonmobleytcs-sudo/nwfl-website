/**
 * Watches /uploads/incoming/ for new .sql backup files and
 * auto-triggers the migration for the matching location.
 *
 * File naming convention: {loc}me_backup*.sql
 *   alme_backup.sql  → location AL
 *   msme_backup.sql  → location MS
 *   kyme_backup.sql  → location KY
 *   ksme_backup.sql  → location KS
 *   ohme_backup.sql  → location OH
 *   nwflme_backup.sql → location FL
 */

const fs      = require('fs');
const path    = require('path');
const { execFile } = require('child_process');

const WATCH_DIR    = '/uploads/incoming';
const SCRIPTS_DIR  = '/app/scripts';
const PROCESSED_DIR = '/uploads/processed';

const LOCATION_MAP = {
  nwfl: 'FL',
  al:   'AL',
  ms:   'MS',
  ky:   'KY',
  ks:   'KS',
  oh:   'OH',
};

fs.mkdirSync(PROCESSED_DIR, { recursive: true });

function detectLocation(filename) {
  const lower = filename.toLowerCase();
  for (const [prefix, code] of Object.entries(LOCATION_MAP)) {
    if (lower.startsWith(prefix)) return code;
  }
  return null;
}

function runMigration(filePath, location) {
  console.log(`[watcher] Starting migration: ${filePath} → ${location}`);
  const scriptPath = path.join(SCRIPTS_DIR, 'migrate-to-supabase.js');
  const args = ['--all', `--location=${location}`, `--file=${filePath}`];

  const child = execFile('node', [scriptPath, ...args], {
    env: { ...process.env },
    maxBuffer: 10 * 1024 * 1024,
  }, (err, stdout, stderr) => {
    if (err) {
      console.error(`[watcher] Migration failed for ${location}:`, err.message);
      console.error(stderr);
      return;
    }
    console.log(`[watcher] Migration complete for ${location}:\n${stdout}`);
    // Move to processed
    const dest = path.join(PROCESSED_DIR, path.basename(filePath));
    fs.renameSync(filePath, dest);
    console.log(`[watcher] Moved to processed: ${dest}`);
  });

  child.stdout?.on('data', d => process.stdout.write(d));
  child.stderr?.on('data', d => process.stderr.write(d));
}

// Track in-progress files to avoid double-triggering
const processing = new Set();

function handleFile(filename) {
  if (!filename.endsWith('.sql')) return;
  if (processing.has(filename)) return;

  const location = detectLocation(filename);
  if (!location) {
    console.warn(`[watcher] Unknown location prefix for: ${filename} — skipping`);
    return;
  }

  const filePath = path.join(WATCH_DIR, filename);

  // Wait briefly for the upload to finish before reading
  setTimeout(() => {
    if (!fs.existsSync(filePath)) return;
    processing.add(filename);
    runMigration(filePath, location);
    processing.delete(filename);
  }, 5000);
}

console.log(`[watcher] SFTP server ready. Files uploaded to ${WATCH_DIR} will NOT auto-migrate.`);
console.log(`[watcher] To run a migration manually, use the admin portal or run the migration script directly.`);
