/**
 * NWFL Encounters — MySQL → Supabase Migration Script
 *
 * Usage:
 *   1. Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env
 *   2. npm install @supabase/supabase-js dotenv
 *   3. node scripts/migrate-to-supabase.js
 *
 * This script parses the MySQL backup SQL file and inserts all data
 * into Supabase using the service role key (bypasses RLS).
 */

require('dotenv').config();
const fs   = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// ── Config ────────────────────────────────────────────────────
const BACKUP_FILE = path.join(
  process.env.HOME,
  'Library/CloudStorage/Dropbox/Encounter/Website Redesign/root/backups/nwflme_backup.2026.05.13.sql'
);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY  // service role — bypasses RLS
);

// Tables to migrate (in dependency order)
const TABLE_ORDER = [
  'countries', 'states', 'groups', 'permissions', 'groups_permissions',
  'users', 'settings', 'settings_positions', 'settings_sessions',
  'products', 'encounters', 'encounters_positions', 'encounters_sessions',
  'encounters_receipts', 'participants', 'participants_encounters',
  'invoices', 'invoices_details', 'invoices_payments',
  'donations', 'notes', 'testimonies',
  'events', 'events_registrations', 'fellowships',
  'freedom_affiliates', 'freedom_profiles', 'sms_messages'
];

// MySQL column name → PostgreSQL column name overrides
const COLUMN_OVERRIDES = {
  events: { where: '"where"', when: '"when"' }
};

// ── Parser ────────────────────────────────────────────────────

function parseInsertStatements(sql, tableName) {
  const rows = [];
  // Match: INSERT INTO `tableName` VALUES (...),(...),...;
  // or:    INSERT INTO `tableName` (`col`,...) VALUES (...);
  const tableEscaped = tableName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const insertReg = new RegExp(
    `INSERT INTO \`${tableEscaped}\`(?:\\s*\\([^)]+\\))?\\s+VALUES\\s*([\\s\\S]*?);`,
    'g'
  );

  let match;
  while ((match = insertReg.exec(sql)) !== null) {
    const valueBlock = match[1].trim();
    // Split individual row tuples
    const tuples = splitTuples(valueBlock);
    for (const tuple of tuples) {
      const values = parseTuple(tuple);
      rows.push(values);
    }
  }
  return rows;
}

function splitTuples(block) {
  // Split by ),( accounting for strings containing commas/parens
  const tuples = [];
  let depth = 0, inStr = false, escape = false, start = 0;
  for (let i = 0; i < block.length; i++) {
    const ch = block[i];
    if (escape) { escape = false; continue; }
    if (ch === '\\') { escape = true; continue; }
    if (ch === "'") { inStr = !inStr; continue; }
    if (inStr) continue;
    if (ch === '(') { if (depth === 0) start = i; depth++; }
    else if (ch === ')') {
      depth--;
      if (depth === 0) tuples.push(block.slice(start + 1, i));
    }
  }
  return tuples;
}

function parseTuple(tuple) {
  // Parse comma-separated values, respecting quoted strings
  const values = [];
  let cur = '', inStr = false, escape = false;
  for (let i = 0; i < tuple.length; i++) {
    const ch = tuple[i];
    if (escape) { cur += ch; escape = false; continue; }
    if (ch === '\\') { escape = true; cur += ch; continue; }
    if (ch === "'" && !inStr) { inStr = true; continue; }
    if (ch === "'" && inStr) {
      if (tuple[i+1] === "'") { cur += "'"; i++; } // escaped single quote
      else inStr = false;
      continue;
    }
    if (!inStr && ch === ',') { values.push(convertValue(cur)); cur = ''; continue; }
    cur += ch;
  }
  values.push(convertValue(cur));
  return values;
}

function convertValue(raw) {
  const v = raw.trim();
  if (v === 'NULL') return null;
  if (v === "''" || v === '') return '';
  const decoded = v.replace(/\\'/g, "'").replace(/\\n/g, '\n').replace(/\\r/g, '\r').replace(/\\\\/g, '\\');
  // Convert MySQL zero dates to null
  if (decoded === '0000-00-00' || decoded === '0000-00-00 00:00:00') return null;
  return decoded;
}

// Get column names from CREATE TABLE statement
function getColumns(sql, tableName) {
  const tableEscaped = tableName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const createReg = new RegExp(`CREATE TABLE \`${tableEscaped}\`[\\s\\S]*?\\(([\\s\\S]*?)\\)\\s*ENGINE`, 'i');
  const match = createReg.exec(sql);
  if (!match) return null;

  const lines = match[1].split('\n');
  const cols = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('PRIMARY') || trimmed.startsWith('KEY') || trimmed.startsWith('UNIQUE')) continue;
    const colMatch = trimmed.match(/^`([^`]+)`/);
    if (colMatch) cols.push(colMatch[1]);
  }
  return cols;
}

// ── Main ──────────────────────────────────────────────────────

async function migrate() {
  console.log('📖 Reading MySQL backup...');
  const sql = fs.readFileSync(BACKUP_FILE, 'utf8');
  console.log(`   File size: ${(Buffer.byteLength(sql,'utf8')/1024/1024).toFixed(1)} MB\n`);

  let totalInserted = 0;
  let totalErrors   = 0;

  for (const table of TABLE_ORDER) {
    process.stdout.write(`⏳  ${table.padEnd(35)}`);

    const columns = getColumns(sql, table);
    if (!columns) {
      console.log('⚠️  CREATE TABLE not found, skipping');
      continue;
    }

    const rows = parseInsertStatements(sql, table);
    if (rows.length === 0) {
      console.log('—  (no data)');
      continue;
    }

    // Build array of objects
    const overrides = COLUMN_OVERRIDES[table] || {};
    const FALLBACK_TS = '1970-01-01T00:00:00Z';
    const objects = rows.map(values => {
      const obj = {};
      columns.forEach((col, i) => {
        const pgCol = overrides[col] ? overrides[col].replace(/"/g,'') : col;
        let val = values[i] !== undefined ? values[i] : null;
        // Zero dates became null — use fallback for NOT NULL date/timestamp columns
        if (val === null && /date|created|modified|paid|inactive|used|lst_pmt/i.test(col)) {
          val = FALLBACK_TS;
        }
        obj[pgCol] = val;
      });
      return obj;
    });

    // Insert in batches of 500
    const BATCH = 500;
    let inserted = 0, errors = 0;
    for (let i = 0; i < objects.length; i += BATCH) {
      const batch = objects.slice(i, i + BATCH);
      const { error } = await supabase
        .from(table)
        .upsert(batch, { onConflict: getPK(table) });

      if (error) {
        errors++;
        if (errors <= 3) console.log(`\n   ⚠️  Batch error: ${error.message}`);
      } else {
        inserted += batch.length;
      }
    }

    totalInserted += inserted;
    totalErrors   += errors;
    console.log(`✅  ${inserted.toString().padStart(6)} rows${errors ? `  ⚠️  ${errors} batch error(s)` : ''}`);
  }

  console.log(`\n${'─'.repeat(55)}`);
  console.log(`✅  Migration complete: ${totalInserted.toLocaleString()} total rows inserted`);
  if (totalErrors) console.log(`⚠️  ${totalErrors} batch errors — check output above`);
  console.log('\n🔐 Next steps:');
  console.log('   1. Set admin user passwords via Supabase Auth');
  console.log('   2. Enable RLS policies in supabase/rls.sql');
  console.log('   3. Set SUPABASE_URL + SUPABASE_SERVICE_KEY in Railway env vars');
}

function getPK(table) {
  const PKs = {
    countries:                 'country_id',
    states:                    'state_id',
    groups:                    'group_id',
    permissions:               'permission_id',
    groups_permissions:        'groups_permission_id',
    users:                     'user_id',
    settings:                  'setting_id',
    settings_positions:        'settings_position_id',
    settings_sessions:         'settings_session_id',
    products:                  'product_id',
    encounters:                'encounter_id',
    encounters_positions:      'encounters_position_id',
    encounters_sessions:       'encounters_session_id',
    encounters_receipts:       'encounters_receipt_id',
    participants:              'participant_id',
    participants_encounters:   'participants_encounter_id',
    invoices:                  'invoice_id',
    invoices_details:          'invoices_detail_id',
    invoices_payments:         'invoices_payments_id',
    donations:                 'donation_id',
    notes:                     'note_id',
    testimonies:               'testimony_id',
    events:                    'id',
    events_registrations:      'id',
    fellowships:               'fellowship_id',
    freedom_affiliates:        'freedom_affiliate_id',
    freedom_profiles:          'freedom_profile_id',
    sms_messages:              'sms_message_id',
  };
  return PKs[table] || 'id';
}

migrate().catch(err => {
  console.error('\n❌ Fatal error:', err.message);
  process.exit(1);
});
