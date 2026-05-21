# Supabase Setup & Data Migration

## Step 1 — Create Supabase Project
1. Go to https://supabase.com and sign in
2. Click **New Project**
3. Name it `nwfl-encounters`, choose a strong DB password, pick **US East** region
4. Wait ~2 minutes for it to provision

## Step 2 — Run the Schema
1. In Supabase dashboard → **SQL Editor** → **New query**
2. Paste the entire contents of `supabase/schema.sql`
3. Click **Run** — all 28 tables will be created

## Step 3 — Get Your Keys
In Supabase → **Settings** → **API**:
- Copy **Project URL** → this is `SUPABASE_URL`
- Copy **service_role** secret key → this is `SUPABASE_SERVICE_KEY`
- Copy **anon** public key → this is `SUPABASE_ANON_KEY`

## Step 4 — Set Up .env Locally
Create a `.env` file in the project root:
```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...  (service_role key)
SUPABASE_ANON_KEY=eyJ...     (anon key)
```

## Step 5 — Install Dependencies & Run Migration
```bash
npm install @supabase/supabase-js dotenv
node scripts/migrate-to-supabase.js
```

The script will print progress for all 28 tables and a final count.
Expected: ~10,000+ total rows across all tables.

## Step 6 — Add Keys to Railway
In Railway → your project → **Variables**:
```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...
```

## Step 7 — Verify in Supabase Table Editor
- Go to **Table Editor** in Supabase
- Check `participants` → should have ~1,535 rows
- Check `encounters` → should have ~98 rows
- Check `invoices` → should have ~4,111 rows
- Check `donations` → should have ~406 rows

## What's Next
- Wire up Supabase to the admin portal backend
- Set up Supabase Auth for admin login
- Enable Row Level Security (RLS) once auth is connected
