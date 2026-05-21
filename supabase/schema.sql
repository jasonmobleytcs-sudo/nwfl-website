-- ============================================================
-- NWFL Encounters — Supabase (PostgreSQL) Schema
-- Migrated from MySQL nwflme_backup.2026.05.13.sql
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── countries ───────────────────────────────────────────────
CREATE TABLE countries (
  country_id    SERIAL PRIMARY KEY,
  country_code  VARCHAR(5)   NOT NULL DEFAULT '',
  name          VARCHAR(50)  NOT NULL DEFAULT '',
  active        SMALLINT     NOT NULL DEFAULT 1,
  sort_order    SMALLINT     NOT NULL DEFAULT 50,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_countries_code ON countries (country_code);

-- ── states ──────────────────────────────────────────────────
CREATE TABLE states (
  state_id      SERIAL PRIMARY KEY,
  country_code  VARCHAR(5)   NOT NULL DEFAULT 'US',
  code          VARCHAR(50)  NOT NULL DEFAULT '',
  name          VARCHAR(50)  NOT NULL DEFAULT '',
  sort_order    SMALLINT     NOT NULL DEFAULT 50,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_states_code ON states (code);
CREATE INDEX idx_states_country ON states (country_code);

-- ── groups ──────────────────────────────────────────────────
CREATE TABLE groups (
  group_id      SERIAL PRIMARY KEY,
  code          VARCHAR(20)  NOT NULL DEFAULT '',
  description   TEXT         NOT NULL DEFAULT '',
  mgmt_level    SMALLINT     NOT NULL DEFAULT 0,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── permissions ─────────────────────────────────────────────
CREATE TABLE permissions (
  permission_id INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  area          VARCHAR(50)  NOT NULL DEFAULT '',
  description   VARCHAR(50)  NOT NULL DEFAULT '',
  active        SMALLINT     NOT NULL DEFAULT 1,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── groups_permissions ──────────────────────────────────────
CREATE TABLE groups_permissions (
  groups_permission_id INTEGER  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id             INTEGER  NOT NULL,
  permission_id        INTEGER  NOT NULL,
  active               SMALLINT NOT NULL DEFAULT 1,
  user_modified        INTEGER  NOT NULL DEFAULT 1,
  date_modified        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_created         INTEGER  NOT NULL DEFAULT 1,
  date_created         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── users (admin) ───────────────────────────────────────────
CREATE TABLE users (
  user_id       SERIAL PRIMARY KEY,
  username      VARCHAR(120) NOT NULL DEFAULT '',
  password      VARCHAR(100) NOT NULL DEFAULT '',  -- will store bcrypt hash
  first_name    VARCHAR(30)  NOT NULL DEFAULT '',
  last_name     VARCHAR(30)  NOT NULL DEFAULT '',
  email         VARCHAR(120) NOT NULL DEFAULT '',
  phone         VARCHAR(15)  NOT NULL DEFAULT '',
  group_id      INTEGER      NOT NULL DEFAULT 0,
  active        SMALLINT     NOT NULL DEFAULT 1,
  user_inactive INTEGER      NOT NULL DEFAULT 0,
  date_inactive TIMESTAMPTZ,
  auth_id       UUID,                              -- links to Supabase auth.users
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_users_username ON users (username);

-- ── settings ────────────────────────────────────────────────
CREATE TABLE settings (
  setting_id    SERIAL PRIMARY KEY,
  name          VARCHAR(45)  NOT NULL DEFAULT '',
  value         TEXT         NOT NULL DEFAULT '',
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (name)
);

-- ── settings_positions ──────────────────────────────────────
CREATE TABLE settings_positions (
  settings_position_id SERIAL PRIMARY KEY,
  name          VARCHAR(100) NOT NULL DEFAULT '',
  description   TEXT         NOT NULL DEFAULT '',
  active        SMALLINT     NOT NULL DEFAULT 1,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (name)
);

-- ── settings_sessions ───────────────────────────────────────
CREATE TABLE settings_sessions (
  settings_session_id SERIAL PRIMARY KEY,
  name          VARCHAR(100) NOT NULL DEFAULT '',
  description   TEXT         NOT NULL DEFAULT '',
  active        SMALLINT     NOT NULL DEFAULT 1,
  sort_order    INTEGER      NOT NULL DEFAULT 0,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (name)
);

-- ── products ────────────────────────────────────────────────
CREATE TABLE products (
  product_id    SERIAL PRIMARY KEY,
  code          VARCHAR(20)  NOT NULL DEFAULT '',
  short_desc    VARCHAR(50)  NOT NULL DEFAULT '',
  description   TEXT         NOT NULL DEFAULT '',
  active        SMALLINT     NOT NULL DEFAULT 1,
  admin_only    SMALLINT     NOT NULL DEFAULT 0,
  type          CHAR(1)      NOT NULL DEFAULT '',
  gender        CHAR(1)      NOT NULL DEFAULT '',
  part_srvr     VARCHAR(10)  NOT NULL DEFAULT '',
  quantity      INTEGER      NOT NULL DEFAULT 0,
  uom           VARCHAR(10)  NOT NULL DEFAULT '',
  cost          NUMERIC(9,2) NOT NULL DEFAULT 0,
  price         NUMERIC(9,2) NOT NULL DEFAULT 0,
  sizes         VARCHAR(50)  NOT NULL DEFAULT '',
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── encounters ──────────────────────────────────────────────
CREATE TABLE encounters (
  encounter_id                    SERIAL PRIMARY KEY,
  type                            CHAR(1)      NOT NULL DEFAULT 'M',
  short_name                      VARCHAR(50)  NOT NULL DEFAULT '',
  description                     TEXT         NOT NULL DEFAULT '',
  status_code                     VARCHAR(2)   NOT NULL DEFAULT '',
  encounter_location              VARCHAR(300) NOT NULL DEFAULT '',
  dropoff_location                VARCHAR(300) NOT NULL DEFAULT '',
  address1                        VARCHAR(40)  NOT NULL DEFAULT '',
  address2                        VARCHAR(40)  NOT NULL DEFAULT '',
  city                            VARCHAR(40)  NOT NULL DEFAULT '',
  state                           VARCHAR(5)   NOT NULL DEFAULT '',
  postal                          VARCHAR(10)  NOT NULL DEFAULT '',
  country                         VARCHAR(5)   NOT NULL DEFAULT '',
  phone                           VARCHAR(15)  NOT NULL DEFAULT '',
  start_date                      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  end_date                        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  dropoff_message                 TEXT         NOT NULL DEFAULT '',
  post_message                    TEXT         NOT NULL DEFAULT '',
  register_form                   VARCHAR(100) NOT NULL DEFAULT '',
  product_participant             INTEGER      NOT NULL DEFAULT 0,
  product_server                  INTEGER      NOT NULL DEFAULT 0,
  halt_participant_registration   SMALLINT     NOT NULL DEFAULT 0,
  halt_server_registration        SMALLINT     NOT NULL DEFAULT 0,
  max_participants                INTEGER      NOT NULL DEFAULT 0,
  max_servers                     INTEGER      NOT NULL DEFAULT 0,
  user_modified                   INTEGER      NOT NULL DEFAULT 1,
  date_modified                   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created                    INTEGER      NOT NULL DEFAULT 1,
  date_created                    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── encounters_positions ────────────────────────────────────
CREATE TABLE encounters_positions (
  encounters_position_id SERIAL PRIMARY KEY,
  encounter_id  INTEGER      NOT NULL,
  position_id   INTEGER      NOT NULL,
  server_name   TEXT         NOT NULL DEFAULT '',
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_enc_pos_encounter ON encounters_positions (encounter_id);

-- ── encounters_sessions ─────────────────────────────────────
CREATE TABLE encounters_sessions (
  encounters_session_id SERIAL PRIMARY KEY,
  encounter_id  INTEGER      NOT NULL,
  session_id    INTEGER      NOT NULL,
  server_name   TEXT         NOT NULL DEFAULT '',
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_enc_sess_encounter ON encounters_sessions (encounter_id);

-- ── encounters_receipts ─────────────────────────────────────
CREATE TABLE encounters_receipts (
  encounters_receipt_id SERIAL PRIMARY KEY,
  encounter_id    INTEGER      NOT NULL,
  payment_method  VARCHAR(10)  NOT NULL DEFAULT '',
  amount          NUMERIC(10,2) NOT NULL DEFAULT 0,
  note            TEXT         NOT NULL DEFAULT '',
  user_modified   INTEGER      NOT NULL DEFAULT 0,
  date_modified   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created    INTEGER      NOT NULL DEFAULT 0,
  date_created    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_enc_rcpt_encounter ON encounters_receipts (encounter_id, payment_method);

-- ── participants ─────────────────────────────────────────────
CREATE TABLE participants (
  participant_id          SERIAL PRIMARY KEY,
  first_name              VARCHAR(40)  NOT NULL DEFAULT '',
  last_name               VARCHAR(45)  NOT NULL DEFAULT '',
  nick_name               VARCHAR(50)  NOT NULL DEFAULT '',
  address1                VARCHAR(45)  NOT NULL DEFAULT '',
  address2                VARCHAR(45)  NOT NULL DEFAULT '',
  city                    VARCHAR(45)  NOT NULL DEFAULT '',
  state                   VARCHAR(5)   NOT NULL DEFAULT '',
  postal                  VARCHAR(10)  NOT NULL DEFAULT '',
  country                 VARCHAR(5)   NOT NULL DEFAULT '',
  phone                   VARCHAR(15)  NOT NULL DEFAULT '',
  email                   VARCHAR(120) NOT NULL DEFAULT '',
  status_code             VARCHAR(2)   NOT NULL DEFAULT '',
  gender                  CHAR(1)      NOT NULL DEFAULT '',
  birth_date              DATE,
  marital_status          VARCHAR(2)   NOT NULL DEFAULT '',
  special_personal_needs  TEXT         NOT NULL DEFAULT '',
  special_dietary_needs   TEXT         NOT NULL DEFAULT '',
  referred_by             VARCHAR(45)  NOT NULL DEFAULT '',
  emergency_name          VARCHAR(45)  NOT NULL DEFAULT '',
  emergency_phone         VARCHAR(15)  NOT NULL DEFAULT '',
  emergency_relation      VARCHAR(20)  NOT NULL DEFAULT '',
  shirt_size              VARCHAR(5)   NOT NULL DEFAULT '',
  username                VARCHAR(120) NOT NULL DEFAULT '',
  password                VARCHAR(100) NOT NULL DEFAULT '',
  send_text_messages      SMALLINT     NOT NULL DEFAULT 1,
  song_request1           VARCHAR(50)  NOT NULL DEFAULT '',
  song_request2           VARCHAR(50)  NOT NULL DEFAULT '',
  song_request3           VARCHAR(50)  NOT NULL DEFAULT '',
  song_request4           VARCHAR(50)  NOT NULL DEFAULT '',
  song_request5           VARCHAR(50)  NOT NULL DEFAULT '',
  user_modified           INTEGER      NOT NULL DEFAULT 1,
  date_modified           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created            INTEGER      NOT NULL DEFAULT 1,
  date_created            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── participants_encounters ──────────────────────────────────
CREATE TABLE participants_encounters (
  participants_encounter_id SERIAL PRIMARY KEY,
  participant_id      INTEGER      NOT NULL,
  encounter_id        INTEGER      NOT NULL,
  invoice_id          INTEGER      NOT NULL DEFAULT 0,
  status_code         VARCHAR(5)   NOT NULL DEFAULT '',
  first_name          VARCHAR(45)  NOT NULL DEFAULT '',
  last_name           VARCHAR(45)  NOT NULL DEFAULT '',
  nick_name           VARCHAR(45)  NOT NULL DEFAULT '',
  address1            VARCHAR(45)  NOT NULL DEFAULT '',
  city                VARCHAR(45)  NOT NULL DEFAULT '',
  state               VARCHAR(5)   NOT NULL DEFAULT '',
  postal              VARCHAR(10)  NOT NULL DEFAULT '',
  country             VARCHAR(5)   NOT NULL DEFAULT '',
  phone               VARCHAR(15)  NOT NULL DEFAULT '',
  email               VARCHAR(120) NOT NULL DEFAULT '',
  marital_status      VARCHAR(2)   NOT NULL DEFAULT '',
  birth_date          DATE,
  emergency_name      VARCHAR(45)  NOT NULL DEFAULT '',
  emergency_relation  VARCHAR(20)  NOT NULL DEFAULT '',
  emergency_phone     VARCHAR(15)  NOT NULL DEFAULT '',
  referred_by         VARCHAR(50)  NOT NULL DEFAULT '',
  type                VARCHAR(10)  NOT NULL DEFAULT '',
  special_personal_needs TEXT      NOT NULL DEFAULT '',
  special_dietary_needs  TEXT      NOT NULL DEFAULT '',
  payment_type        VARCHAR(10)  NOT NULL DEFAULT '',
  card_nbr            VARCHAR(20)  NOT NULL DEFAULT '',
  exp_mo              VARCHAR(5)   NOT NULL DEFAULT '',
  exp_yr              VARCHAR(5)   NOT NULL DEFAULT '',
  sec_code            VARCHAR(5)   NOT NULL DEFAULT '',
  check_nbr           VARCHAR(20)  NOT NULL DEFAULT '',
  authnet_txn_id      VARCHAR(25)  NOT NULL DEFAULT '',
  authnet_confirm_code VARCHAR(25) NOT NULL DEFAULT '',
  attended            SMALLINT     NOT NULL DEFAULT 0,
  position            VARCHAR(50)  NOT NULL DEFAULT '',
  cabin               SMALLINT     NOT NULL DEFAULT 0,
  top_or_bottom       CHAR(1)      NOT NULL DEFAULT 'B',
  checked_in          SMALLINT     NOT NULL DEFAULT 0,
  send_text_messages  SMALLINT     NOT NULL DEFAULT 1,
  song_request1       VARCHAR(50)  NOT NULL DEFAULT '',
  song_request2       VARCHAR(50)  NOT NULL DEFAULT '',
  song_request3       VARCHAR(50)  NOT NULL DEFAULT '',
  song_request4       VARCHAR(50)  NOT NULL DEFAULT '',
  song_request5       VARCHAR(50)  NOT NULL DEFAULT '',
  user_modified       INTEGER      NOT NULL DEFAULT 1,
  date_modified       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created        INTEGER      NOT NULL DEFAULT 1,
  date_created        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_pe_participant  ON participants_encounters (participant_id);
CREATE INDEX idx_pe_encounter    ON participants_encounters (encounter_id);

-- ── invoices ─────────────────────────────────────────────────
CREATE TABLE invoices (
  invoice_id                  SERIAL PRIMARY KEY,
  participants_encounter_id   INTEGER       NOT NULL DEFAULT 0,
  events_registration_id      INTEGER       NOT NULL DEFAULT 0,
  status_code                 CHAR(1)       NOT NULL DEFAULT 'N',
  invoice_date                TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  date_paid                   TIMESTAMPTZ,
  encounters_amount           NUMERIC(11,2) NOT NULL DEFAULT 0,
  products_amount             NUMERIC(11,2) NOT NULL DEFAULT 0,
  fees_amount                 NUMERIC(11,2) NOT NULL DEFAULT 0,
  payments_amount             NUMERIC(11,2) NOT NULL DEFAULT 0,
  discount_amount             NUMERIC(11,2) NOT NULL DEFAULT 0,
  credits_amount              NUMERIC(11,2) NOT NULL DEFAULT 0,
  taxable_amount              NUMERIC(11,2) NOT NULL DEFAULT 0,
  sales_tax_amount            NUMERIC(11,2) NOT NULL DEFAULT 0,
  total_amount                NUMERIC(11,2) NOT NULL DEFAULT 0,
  payment_method              VARCHAR(10)   NOT NULL DEFAULT '',
  authnet_txn_id              VARCHAR(15)   NOT NULL DEFAULT '',
  confirmation_code           VARCHAR(15)   NOT NULL DEFAULT '',
  billing_first_name          VARCHAR(64)   NOT NULL DEFAULT '',
  billing_last_name           VARCHAR(64)   NOT NULL DEFAULT '',
  billing_address1            VARCHAR(64)   NOT NULL DEFAULT '',
  billing_address2            VARCHAR(64)   NOT NULL DEFAULT '',
  billing_city                VARCHAR(64)   NOT NULL DEFAULT '',
  billing_state               VARCHAR(5)    NOT NULL DEFAULT '',
  billing_postal              VARCHAR(10)   NOT NULL DEFAULT '',
  billing_postal_plus         VARCHAR(10)   NOT NULL DEFAULT '',
  billing_country             CHAR(2)       NOT NULL DEFAULT '',
  billing_county              VARCHAR(20)   NOT NULL DEFAULT '',
  ref_number                  VARCHAR(50)   NOT NULL DEFAULT '',
  ref_exp_date                VARCHAR(7)    NOT NULL DEFAULT '',
  ref_sec_code                VARCHAR(5)    NOT NULL DEFAULT '',
  cardpay_code                VARCHAR(8)    NOT NULL DEFAULT '',
  user_modified               INTEGER       NOT NULL DEFAULT 0,
  date_modified               TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  user_created                INTEGER       NOT NULL DEFAULT 0,
  date_created                TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_inv_pe     ON invoices (participants_encounter_id);
CREATE INDEX idx_inv_event  ON invoices (events_registration_id);

-- ── invoices_details ─────────────────────────────────────────
CREATE TABLE invoices_details (
  invoices_detail_id  SERIAL PRIMARY KEY,
  invoice_id          INTEGER       NOT NULL,
  product_id          INTEGER       NOT NULL DEFAULT 0,
  description         VARCHAR(100)  NOT NULL DEFAULT '',
  quantity            INTEGER       NOT NULL DEFAULT 0,
  size                VARCHAR(5)    NOT NULL DEFAULT '',
  cost                NUMERIC(11,2) NOT NULL DEFAULT 0,
  amount              NUMERIC(11,2) NOT NULL DEFAULT 0,
  total_amount        NUMERIC(11,2) NOT NULL DEFAULT 0,
  taxable             SMALLINT      NOT NULL DEFAULT 0,
  date_used           TIMESTAMPTZ,
  user_modified       INTEGER       NOT NULL DEFAULT 0,
  date_modified       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  user_created        INTEGER       NOT NULL DEFAULT 0,
  date_created        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_invd_invoice ON invoices_details (invoice_id);

-- ── invoices_payments ────────────────────────────────────────
CREATE TABLE invoices_payments (
  invoices_payments_id  SERIAL PRIMARY KEY,
  invoice_id            INTEGER       NOT NULL,
  date_paid             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  payment_amount        NUMERIC(11,2) NOT NULL DEFAULT 0,
  payment_method        VARCHAR(10)   NOT NULL DEFAULT '',
  authnet_txn_id        VARCHAR(15)   NOT NULL DEFAULT '',
  confirmation_code     VARCHAR(15)   NOT NULL DEFAULT '',
  billing_first_name    VARCHAR(64)   NOT NULL DEFAULT '',
  billing_last_name     VARCHAR(64)   NOT NULL DEFAULT '',
  billing_address1      VARCHAR(64)   NOT NULL DEFAULT '',
  billing_address2      VARCHAR(64)   NOT NULL DEFAULT '',
  billing_city          VARCHAR(64)   NOT NULL DEFAULT '',
  billing_state         VARCHAR(5)    NOT NULL DEFAULT '',
  billing_postal        VARCHAR(10)   NOT NULL DEFAULT '',
  billing_postal_plus   VARCHAR(10)   NOT NULL DEFAULT '',
  billing_country       CHAR(2)       NOT NULL DEFAULT '',
  billing_county        VARCHAR(20)   NOT NULL DEFAULT '',
  ref_number            VARCHAR(50)   NOT NULL DEFAULT '',
  ref_exp_date          VARCHAR(7)    NOT NULL DEFAULT '',
  ref_sec_code          VARCHAR(5)    NOT NULL DEFAULT '',
  stripe_fee_amt        NUMERIC(7,2)  NOT NULL DEFAULT 0,
  user_modified         INTEGER       NOT NULL DEFAULT 0,
  date_modified         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  user_created          INTEGER       NOT NULL DEFAULT 0,
  date_created          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_invp_invoice ON invoices_payments (invoice_id);

-- ── donations ────────────────────────────────────────────────
CREATE TABLE donations (
  donation_id       SERIAL PRIMARY KEY,
  type              VARCHAR(30)   NOT NULL DEFAULT '',
  date_paid         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  amount            NUMERIC(11,2) NOT NULL DEFAULT 0,
  payment_method    VARCHAR(10)   NOT NULL DEFAULT '',
  authnet_txn_id    VARCHAR(15)   NOT NULL DEFAULT '',
  confirmation_code VARCHAR(15)   NOT NULL DEFAULT '',
  full_name         VARCHAR(64)   NOT NULL DEFAULT '',
  reason            TEXT          NOT NULL DEFAULT '',
  stripe_fee_amt    NUMERIC(7,2)  NOT NULL DEFAULT 0,
  user_modified     INTEGER       NOT NULL DEFAULT 0,
  date_modified     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  user_created      INTEGER       NOT NULL DEFAULT 0,
  date_created      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ── notes ────────────────────────────────────────────────────
CREATE TABLE notes (
  note_id           SERIAL PRIMARY KEY,
  participant_id    INTEGER  NOT NULL,
  encounter_id      INTEGER  NOT NULL,
  importance_code   VARCHAR(10) NOT NULL DEFAULT '',
  category_code     VARCHAR(10) NOT NULL DEFAULT '',
  note              TEXT        NOT NULL DEFAULT '',
  user_modified     INTEGER     NOT NULL DEFAULT 0,
  date_modified     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_created      INTEGER     NOT NULL DEFAULT 0,
  date_created      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_notes_participant ON notes (participant_id);
CREATE INDEX idx_notes_encounter   ON notes (encounter_id);

-- ── testimonies ──────────────────────────────────────────────
CREATE TABLE testimonies (
  testimony_id    SERIAL PRIMARY KEY,
  encounter_id    INTEGER      NOT NULL DEFAULT 0,
  encounter_yr_mo VARCHAR(7)   NOT NULL DEFAULT '',
  person_name     VARCHAR(50)  NOT NULL DEFAULT '',
  testimony       TEXT         NOT NULL DEFAULT '',
  video_name      VARCHAR(120) NOT NULL DEFAULT '',
  user_modified   INTEGER      NOT NULL DEFAULT 1,
  date_modified   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created    INTEGER      NOT NULL DEFAULT 1,
  date_created    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── events ───────────────────────────────────────────────────
CREATE TABLE events (
  id            SERIAL PRIMARY KEY,
  event_code    VARCHAR(20)  NOT NULL DEFAULT '',
  name          VARCHAR(100) NOT NULL DEFAULT '',
  status_code   VARCHAR(2)   NOT NULL DEFAULT '',
  start_date    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  end_date      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  "where"       TEXT         NOT NULL DEFAULT '',
  "when"        VARCHAR(50)  NOT NULL DEFAULT '',
  price         NUMERIC(7,2) NOT NULL DEFAULT 0,
  user_modified INTEGER      NOT NULL DEFAULT 1,
  date_modified TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created  INTEGER      NOT NULL DEFAULT 1,
  date_created  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_events_code ON events (event_code);

-- ── events_registrations ────────────────────────────────────
CREATE TABLE events_registrations (
  id               SERIAL PRIMARY KEY,
  event_id         INTEGER      NOT NULL,
  first_name       VARCHAR(50)  NOT NULL DEFAULT '',
  last_name        VARCHAR(50)  NOT NULL DEFAULT '',
  phone            VARCHAR(15)  NOT NULL DEFAULT '',
  email            VARCHAR(120) NOT NULL DEFAULT '',
  tot_in_group     SMALLINT     NOT NULL DEFAULT 1,
  donation_amount  NUMERIC(7,2) NOT NULL DEFAULT 0,
  shirts_amount    NUMERIC(7,2) NOT NULL DEFAULT 0,
  total_amount     NUMERIC(7,2) NOT NULL DEFAULT 0,
  total_paid       NUMERIC(7,2) NOT NULL DEFAULT 0,
  txn_id           VARCHAR(20)  NOT NULL DEFAULT '',
  conf_code        VARCHAR(20)  NOT NULL DEFAULT '',
  stripe_fee_amt   NUMERIC(7,2) NOT NULL DEFAULT 0,
  last4            VARCHAR(15)  NOT NULL DEFAULT '',
  expires          VARCHAR(15)  NOT NULL DEFAULT '',
  preorder_shirts  SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_sm    SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_md    SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_lg    SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_xl    SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_2xl   SMALLINT     NOT NULL DEFAULT 0,
  men_shirts_3xl   SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_sm  SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_md  SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_lg  SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_xl  SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_2xl SMALLINT     NOT NULL DEFAULT 0,
  women_shirts_3xl SMALLINT     NOT NULL DEFAULT 0,
  user_modified    INTEGER      NOT NULL DEFAULT 1,
  date_modified    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created     INTEGER      NOT NULL DEFAULT 1,
  date_created     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_evtreg_event ON events_registrations (event_id);

-- ── fellowships ──────────────────────────────────────────────
CREATE TABLE fellowships (
  fellowship_id   SERIAL PRIMARY KEY,
  fellowship_code VARCHAR(10)  NOT NULL DEFAULT '',
  first_name      VARCHAR(40)  NOT NULL DEFAULT '',
  last_name       VARCHAR(45)  NOT NULL DEFAULT '',
  phone           VARCHAR(15)  NOT NULL DEFAULT '',
  email           VARCHAR(120) NOT NULL DEFAULT '',
  status_code     VARCHAR(2)   NOT NULL DEFAULT '',
  reserve_bunk1   SMALLINT     NOT NULL DEFAULT 0,
  reserve_bunk2   SMALLINT     NOT NULL DEFAULT 0,
  reserve_bunk3   SMALLINT     NOT NULL DEFAULT 0,
  reserve_bunk4   SMALLINT     NOT NULL DEFAULT 0,
  reserve_bunk5   SMALLINT     NOT NULL DEFAULT 0,
  total_due       NUMERIC(7,2) NOT NULL DEFAULT 0,
  amt_paid        NUMERIC(7,2) NOT NULL DEFAULT 0,
  date_lst_pmt    DATE,
  user_modified   INTEGER      NOT NULL DEFAULT 1,
  date_modified   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created    INTEGER      NOT NULL DEFAULT 1,
  date_created    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_fellowships_code ON fellowships (fellowship_code);

-- ── freedom_affiliates ───────────────────────────────────────
CREATE TABLE freedom_affiliates (
  freedom_affiliate_id SERIAL PRIMARY KEY,
  name                 VARCHAR(120) NOT NULL DEFAULT '',
  status_code          VARCHAR(2)   NOT NULL DEFAULT '',
  with_encounters      INTEGER      NOT NULL DEFAULT 0,
  user_modified        INTEGER      NOT NULL DEFAULT 1,
  date_modified        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created         INTEGER      NOT NULL DEFAULT 1,
  date_created         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── freedom_profiles ─────────────────────────────────────────
CREATE TABLE freedom_profiles (
  freedom_profile_id SERIAL PRIMARY KEY,
  email              VARCHAR(120) NOT NULL DEFAULT '',
  passcode           SMALLINT     NOT NULL DEFAULT 0,
  status_code        VARCHAR(2)   NOT NULL DEFAULT '',
  first_name         VARCHAR(45)  NOT NULL DEFAULT '',
  last_name          VARCHAR(45)  NOT NULL DEFAULT '',
  display_name       VARCHAR(50)  NOT NULL DEFAULT '',
  state              VARCHAR(5)   NOT NULL DEFAULT '',
  country            VARCHAR(5)   NOT NULL DEFAULT '',
  phone              VARCHAR(15)  NOT NULL DEFAULT '',
  birth_date_mm      SMALLINT     NOT NULL DEFAULT 0,
  birth_date_dd      SMALLINT     NOT NULL DEFAULT 0,
  affiliate_id       INTEGER      NOT NULL DEFAULT 0,
  user_modified      INTEGER      NOT NULL DEFAULT 1,
  date_modified      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  user_created       INTEGER      NOT NULL DEFAULT 1,
  date_created       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── sms_messages ─────────────────────────────────────────────
CREATE TABLE sms_messages (
  sms_message_id SERIAL PRIMARY KEY,
  msg            TEXT        NOT NULL DEFAULT '',
  user_created   INTEGER     NOT NULL DEFAULT 0,
  date_created   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Reset sequences to match MySQL AUTO_INCREMENT values
-- ============================================================
SELECT setval('countries_country_id_seq',       4);
SELECT setval('donations_donation_id_seq',       407);
SELECT setval('encounters_encounter_id_seq',     99);
SELECT setval('encounters_positions_encounters_position_id_seq', 85);
SELECT setval('encounters_sessions_encounters_session_id_seq',   106);
SELECT setval('events_id_seq',                   3);
SELECT setval('events_registrations_id_seq',     56);
SELECT setval('fellowships_fellowship_id_seq',   121);
SELECT setval('freedom_affiliates_freedom_affiliate_id_seq', 3);
SELECT setval('freedom_profiles_freedom_profile_id_seq',     2);
SELECT setval('invoices_invoice_id_seq',         4112);
SELECT setval('invoices_details_invoices_detail_id_seq',     4651);
SELECT setval('invoices_payments_invoices_payments_id_seq',  3934);
SELECT setval('notes_note_id_seq',               5);
SELECT setval('participants_participant_id_seq', 1536);
SELECT setval('participants_encounters_participants_encounter_id_seq', 4099);
SELECT setval('products_product_id_seq',         21);
SELECT setval('settings_setting_id_seq',         13);
SELECT setval('settings_positions_settings_position_id_seq', 13);
SELECT setval('settings_sessions_settings_session_id_seq',   16);
SELECT setval('sms_messages_sms_message_id_seq', 236);
SELECT setval('states_state_id_seq',             62);
SELECT setval('testimonies_testimony_id_seq',    33);
SELECT setval('users_user_id_seq',               8);
