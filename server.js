require('dotenv').config();
const express  = require('express');
const path     = require('path');
const crypto   = require('crypto');
const session  = require('express-session');
const { createClient } = require('@supabase/supabase-js');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Supabase ─────────────────────────────────────────────────
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// ── Middleware ───────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(session({
  secret: process.env.SESSION_SECRET || 'nwfl-encounters-secret-2026',
  resave: false,
  saveUninitialized: false,
  cookie: { secure: false, maxAge: 8 * 60 * 60 * 1000 }
}));
app.use(express.static(path.join(__dirname, 'public')));

// ── Auth guard ───────────────────────────────────────────────
function requireAdmin(req, res, next) {
  if (req.session && req.session.adminUser) return next();
  res.status(401).json({ error: 'Unauthorized' });
}

// ── Login / Logout ───────────────────────────────────────────
app.post('/api/admin/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'Missing credentials' });

  const { data: users } = await supabase
    .from('users')
    .select('user_id,username,first_name,last_name,group_id,active,password')
    .eq('username', username)
    .eq('active', 1)
    .limit(1);

  if (!users || !users.length) return res.status(401).json({ error: 'Invalid credentials' });
  const user = users[0];

  // Old system stored SHA1 passwords
  const sha1 = crypto.createHash('sha1').update(password).digest('hex');
  const md5  = crypto.createHash('md5').update(password).digest('hex');
  if (password !== user.password && sha1 !== user.password && md5 !== user.password) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  req.session.adminUser = {
    user_id: user.user_id,
    username: user.username,
    name: `${user.first_name} ${user.last_name}`.trim(),
    group_id: user.group_id
  };
  res.json({ ok: true, user: req.session.adminUser });
});

app.post('/api/admin/logout', (req, res) => {
  req.session.destroy();
  res.json({ ok: true });
});

app.get('/api/admin/me', (req, res) => {
  if (req.session?.adminUser) return res.json(req.session.adminUser);
  res.status(401).json({ error: 'Not logged in' });
});

// ── Dashboard ────────────────────────────────────────────────
app.get('/api/admin/dashboard', requireAdmin, async (req, res) => {
  try {
    // Separate queries — no FK constraints so no embedded joins
    const [{ data: encounters }, { data: peList }, { data: invoices }] = await Promise.all([
      supabase.from('encounters')
        .select('encounter_id,short_name,type,status_code,start_date,end_date')
        .order('start_date', { ascending: false }),
      supabase.from('participants_encounters')
        .select('participants_encounter_id,encounter_id,type'),
      supabase.from('invoices')
        .select('invoice_id,participants_encounter_id,status_code,payments_amount,total_amount')
    ]);

    // Invoice lookup by participants_encounter_id
    const invMap = {};
    for (const inv of (invoices || [])) {
      invMap[inv.participants_encounter_id] = inv;
    }

    // Build encounter aggregation map
    const map = {};
    for (const e of (encounters || [])) {
      map[e.encounter_id] = { ...e,
        p_paid_count:0, p_paid_amt:0, p_unpaid_count:0, p_unpaid_amt:0,
        s_paid_count:0, s_paid_amt:0, s_unpaid_count:0, s_unpaid_amt:0 };
    }

    for (const pe of (peList || [])) {
      const enc = map[pe.encounter_id];
      if (!enc) continue;
      const inv    = invMap[pe.participants_encounter_id];
      const total  = parseFloat(inv?.total_amount  || 0);
      const paid   = parseFloat(inv?.payments_amount || 0);
      const bal    = parseFloat((total - paid).toFixed(2));
      const isPart = pe.type === 'PART';

      if (isPart) {
        if (bal <= 0.01) { enc.p_paid_count++;   enc.p_paid_amt   += paid; }
        else             { enc.p_unpaid_count++; enc.p_unpaid_amt += bal;  }
      } else {
        if (bal <= 0.01) { enc.s_paid_count++;   enc.s_paid_amt   += paid; }
        else             { enc.s_unpaid_count++; enc.s_unpaid_amt += bal;  }
      }
    }

    const all = Object.values(map);
    // AC = actively running, C = completed, N = upcoming/new
    const active    = all.filter(e => e.status_code === 'AC');
    const completed = all.filter(e => e.status_code === 'C' &&
      (e.p_unpaid_count > 0 || e.s_unpaid_count > 0));

    const stats = {
      total_participants: all.reduce((s,e) => s + e.p_paid_count + e.p_unpaid_count, 0),
      total_collected:    all.reduce((s,e) => s + e.p_paid_amt + e.s_paid_amt, 0).toFixed(2),
      total_unpaid:       all.reduce((s,e) => s + e.p_unpaid_amt + e.s_unpaid_amt, 0).toFixed(2),
      total_encounters:   encounters?.length || 0
    };
    res.json({ stats, active, completed });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Participants ─────────────────────────────────────────────
app.get('/api/admin/participants', requireAdmin, async (req, res) => {
  const { gender, encounter_id } = req.query;
  let q = supabase
    .from('participants_encounters')
    .select('participants_encounter_id,participant_id,encounter_id,type,first_name,last_name,city,state,email,phone,checked_in,invoices(invoice_id,status_code,total_amount,payments_amount)')
    .order('last_name').limit(500);
  if (encounter_id) q = q.eq('encounter_id', encounter_id);
  if (gender === 'M') q = q.ilike('type', '%part%');
  if (gender === 'F') q = q.ilike('type', '%serv%');
  const { data, error } = await q;
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

// ── Encounters ───────────────────────────────────────────────
app.get('/api/admin/encounters', requireAdmin, async (req, res) => {
  const { data, error } = await supabase
    .from('encounters').select('*').order('start_date', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

// ── Unpaid invoices ──────────────────────────────────────────
app.get('/api/admin/invoices/unpaid', requireAdmin, async (req, res) => {
  const { data, error } = await supabase
    .from('invoices')
    .select('invoice_id,status_code,total_amount,payments_amount,invoice_date,billing_first_name,billing_last_name,participants_encounters(type,first_name,last_name,city,state,email,encounters(short_name,start_date))')
    .neq('status_code','P')
    .order('invoice_date', { ascending: false })
    .limit(300);
  if (error) return res.status(500).json({ error: error.message });
  const unpaid = (data||[]).filter(i => parseFloat(i.total_amount) - parseFloat(i.payments_amount) > 0.01);
  res.json(unpaid);
});

// ── Donations ────────────────────────────────────────────────
app.get('/api/admin/donations', requireAdmin, async (req, res) => {
  const { data, error } = await supabase
    .from('donations').select('*').order('date_paid', { ascending: false }).limit(200);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

// ── Testimonies ──────────────────────────────────────────────
app.get('/api/admin/testimonies', requireAdmin, async (req, res) => {
  const { data, error } = await supabase
    .from('testimonies').select('*,encounters(short_name,start_date,type)').order('encounter_yr_mo', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

// ── Check-in ─────────────────────────────────────────────────
app.get('/api/admin/checkin/:encounter_id', requireAdmin, async (req, res) => {
  const { data, error } = await supabase
    .from('participants_encounters')
    .select('participants_encounter_id,first_name,last_name,type,checked_in,cabin,position')
    .eq('encounter_id', req.params.encounter_id)
    .order('last_name');
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.patch('/api/admin/checkin/:pe_id', requireAdmin, async (req, res) => {
  const { error } = await supabase
    .from('participants_encounters')
    .update({ checked_in: req.body.checked_in ? 1 : 0 })
    .eq('participants_encounter_id', req.params.pe_id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// ── Catch-all ─────────────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`NWFL site running on port ${PORT}`));
