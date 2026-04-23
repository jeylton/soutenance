-- =============================================
-- DICA CLINIC — Complete Database Schema v2
-- =============================================

create extension if not exists pgcrypto;

-- ─── Users ───
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  password_hash text,
  full_name text,
  profile_type text check (profile_type in ('etudiant','medecin','interne','autre')),
  role text check (role in ('student','teacher','admin')) default 'student',
  origin text check (origin in ('mobile','web')) default 'mobile',
  phone text,
  institution text,
  specialty text,
  locale text default 'fr',
  created_at timestamp with time zone default now()
);

-- Add columns that may be missing if users table already existed
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS role text default 'student';
ALTER TABLE users ADD COLUMN IF NOT EXISTS origin text default 'mobile';
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS institution text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS specialty text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locale text default 'fr';

-- ─── Specialties ───
create table if not exists specialties (
  id bigint generated always as identity primary key,
  name text not null unique
);

-- ─── Clinics ───
create table if not exists clinics (
  id bigint generated always as identity primary key,
  name text not null unique
);

-- ─── Cases ───
create table if not exists cases (
  id bigint generated always as identity primary key,
  patient_id text,
  patient_name text not null,
  avatar text,
  consultation_reason text not null,
  initial_symptoms text,
  medical_history jsonb,
  prompt_patient text,
  prompt_tuteur text,
  logic_medicale text,
  difficulty int check (difficulty between 1 and 5) default 1,
  disease_id text,
  status text check (status in ('draft','active','archived')) default 'draft',
  updated_at timestamp with time zone default now()
);

-- ─── Case Exams ───
create table if not exists case_exams (
  id bigint generated always as identity primary key,
  case_id bigint references cases(id) on delete cascade,
  name text not null,
  result text
);

-- ─── Courses ───
create table if not exists courses (
  id bigint generated always as identity primary key,
  title text not null,
  content text,
  pdf_url text,
  case_id bigint references cases(id) on delete set null,
  status text check (status in ('draft','published')) default 'draft',
  specialty_id bigint references specialties(id) on delete set null,
  created_at timestamp with time zone default now()
);

-- ─── Sessions ───
create table if not exists sessions (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  case_id bigint references cases(id) on delete cascade,
  progress jsonb,
  score int,
  feedback text,
  time_spent int,
  is_exam boolean default false,
  exam_assignment_id bigint,
  created_at timestamp with time zone default now()
);

-- Add columns that may be missing if sessions table already existed
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS time_spent int;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS is_exam boolean default false;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS exam_assignment_id bigint;

-- ─── Chat Messages ───
create table if not exists chat_messages (
  id bigint generated always as identity primary key,
  session_id bigint references sessions(id) on delete cascade,
  role text check (role in ('doctor','patient')) not null,
  content text not null,
  created_at timestamp with time zone default now()
);

-- ─── User XP ───
create table if not exists user_xp (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade unique,
  xp int default 0,
  level int default 1,
  updated_at timestamp with time zone default now()
);

-- ─── Badges ───
create table if not exists badges (
  id bigint generated always as identity primary key,
  name text not null unique,
  description text,
  icon text,
  condition_type text,
  condition_value int default 1
);

-- ─── User Badges ───
create table if not exists user_badges (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  badge_id bigint references badges(id) on delete cascade,
  earned_at timestamp with time zone default now(),
  unique(user_id, badge_id)
);

-- ─── Notifications ───
create table if not exists notifications (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  title text not null,
  body text,
  type text check (type in ('new_case','reminder','feedback','badge','exam')),
  read boolean default false,
  created_at timestamp with time zone default now()
);

-- ─── Exam Assignments ───
create table if not exists exam_assignments (
  id bigint generated always as identity primary key,
  case_id bigint references cases(id) on delete cascade,
  assigned_by uuid references users(id),
  time_limit int,
  due_date timestamp with time zone,
  group_name text,
  created_at timestamp with time zone default now()
);

-- ─── Session Annotations ───
create table if not exists session_annotations (
  id bigint generated always as identity primary key,
  session_id bigint references sessions(id) on delete cascade,
  author_id uuid references users(id),
  content text not null,
  created_at timestamp with time zone default now()
);

-- ─── App Settings ───
create table if not exists app_settings (
  key text primary key,
  value text,
  updated_at timestamp with time zone default now()
);

-- ─── Seed Badges ───
INSERT INTO badges (name, description, icon, condition_type, condition_value) VALUES
  ('Premier Pas', 'Terminer votre première simulation', 'trophy', 'cases_completed', 1),
  ('Apprenti Clinicien', 'Terminer 5 simulations', 'award', 'cases_completed', 5),
  ('Clinicien Confirmé', 'Terminer 10 simulations', 'medal', 'cases_completed', 10),
  ('Expert Médical', 'Terminer 25 simulations', 'star', 'cases_completed', 25),
  ('Diagnostic Précis', 'Obtenir un score ≥14 sur un cas', 'target', 'correct_diagnoses', 1),
  ('Maître Diagnosticien', 'Obtenir 10 diagnostics corrects (≥14/20)', 'crosshair', 'correct_diagnoses', 10)
ON CONFLICT (name) DO NOTHING;

INSERT INTO app_settings (key, value) VALUES
  ('site_title', 'Dica Clinic Administration'),
  ('maintenance_mode', 'false'),
  ('ollama_url', 'http://localhost:11434'),
  ('llm_model', 'MedLlama-2 (13b)'),
  ('session_timeout', '30'),
  ('password_policy', 'strict')
ON CONFLICT (key) DO NOTHING;

INSERT INTO users (email, password_hash, full_name, profile_type, role, origin) VALUES
  ('semporejeriel@gmail.com', '$2b$10$euwEndEHWQ3sAfz8C4llCOZCYTC13rRSlRbI66MpMnJ.XqP.E5dZu', 'Jeriel Semporé', 'medecin', 'admin', 'web')
ON CONFLICT (email) DO NOTHING;
