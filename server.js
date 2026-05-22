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

// ── Participants — full list with encounter history ───────────
app.get('/api/admin/participants', requireAdmin, async (req, res) => {
  const { gender, search } = req.query;
  let q = supabase.from('participants')
    .select('participant_id,first_name,last_name,city,state,postal,email,phone,status_code,gender,birth_date,date_created')
    .order('last_name').limit(1000);
  if (gender) q = q.eq('gender', gender);
  if (search) q = q.or(`first_name.ilike.%${search}%,last_name.ilike.%${search}%,email.ilike.%${search}%,city.ilike.%${search}%`);
  const { data: participants, error } = await q;
  if (error) return res.status(500).json({ error: error.message });

  if (!participants?.length) return res.json([]);

  // Get encounter history for these participants
  const ids = participants.map(p => p.participant_id);
  const [{ data: peData }, { data: encounters }] = await Promise.all([
    supabase.from('participants_encounters')
      .select('participants_encounter_id,participant_id,encounter_id,type,attended,status_code')
      .in('participant_id', ids),
    supabase.from('encounters')
      .select('encounter_id,short_name,start_date,type')
  ]);

  const encMap = {};
  for (const e of (encounters || [])) encMap[e.encounter_id] = e;

  const peByPart = {};
  for (const pe of (peData || [])) {
    if (!peByPart[pe.participant_id]) peByPart[pe.participant_id] = [];
    peByPart[pe.participant_id].push({ ...pe, encounter: encMap[pe.encounter_id] });
  }

  res.json(participants.map(p => ({
    ...p,
    encounters: (peByPart[p.participant_id] || [])
      .sort((a,b) => new Date(b.encounter?.start_date||0) - new Date(a.encounter?.start_date||0))
  })));
});

// ── Participant detail (single) ───────────────────────────────
app.get('/api/admin/participants/:id', requireAdmin, async (req, res) => {
  const [{ data: p }, { data: peData }] = await Promise.all([
    supabase.from('participants').select('*').eq('participant_id', req.params.id).single(),
    supabase.from('participants_encounters')
      .select('participants_encounter_id,encounter_id,type,attended,status_code,position,cabin')
      .eq('participant_id', req.params.id).order('date_created', { ascending: false })
  ]);
  if (!p) return res.status(404).json({ error: 'Not found' });

  const encIds = [...new Set((peData||[]).map(pe=>pe.encounter_id))];
  let encounters = [];
  if (encIds.length) {
    const { data } = await supabase.from('encounters')
      .select('encounter_id,short_name,start_date,end_date,encounter_location,type')
      .in('encounter_id', encIds);
    encounters = data || [];
  }
  const encMap = {};
  for (const e of encounters) encMap[e.encounter_id] = e;

  // Get invoice data per PE
  const peIds = (peData||[]).map(pe=>pe.participants_encounter_id);
  let invMap = {};
  if (peIds.length) {
    const { data: invs } = await supabase.from('invoices')
      .select('invoice_id,participants_encounter_id,status_code,total_amount,payments_amount')
      .in('participants_encounter_id', peIds);
    for (const inv of (invs||[])) invMap[inv.participants_encounter_id] = inv;
  }

  res.json({
    ...p,
    encounter_history: (peData||[]).map(pe => ({
      ...pe,
      encounter: encMap[pe.encounter_id] || null,
      invoice: invMap[pe.participants_encounter_id] || null
    }))
  });
});

// ── Update participant ────────────────────────────────────────
app.put('/api/admin/participants/:id', requireAdmin, async (req, res) => {
  const allowed = ['first_name','last_name','nick_name','address1','address2','city','state','postal',
    'country','phone','email','status_code','gender','birth_date','marital_status',
    'special_personal_needs','special_dietary_needs','referred_by','emergency_name',
    'emergency_phone','emergency_relation','shirt_size','username','send_text_messages'];
  const updates = {};
  for (const k of allowed) if (req.body[k] !== undefined) updates[k] = req.body[k];
  updates.date_modified = new Date().toISOString();
  const { error } = await supabase.from('participants').update(updates).eq('participant_id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

// ── Delete participant ────────────────────────────────────────
app.delete('/api/admin/participants/:id', requireAdmin, async (req, res) => {
  const { error } = await supabase.from('participants').delete().eq('participant_id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
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
