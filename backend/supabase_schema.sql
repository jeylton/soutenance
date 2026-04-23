-- Users created via mobile app; admins may exist via web
create extension if not exists pgcrypto;
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  full_name text,
  profile_type text check (profile_type in ('etudiant','medecin','interne','autre')),
  origin text check (origin in ('mobile','web')) default 'mobile',
  created_at timestamp with time zone default now()
);

create table if not exists specialties (
  id bigint generated always as identity primary key,
  name text not null unique
);

create table if not exists clinics (
  id bigint generated always as identity primary key,
  name text not null unique
);

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

create table if not exists case_exams (
  id bigint generated always as identity primary key,
  case_id bigint references cases(id) on delete cascade,
  name text not null,
  result text
);

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

create table if not exists sessions (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  case_id bigint references cases(id) on delete cascade,
  progress jsonb,
  score int,
  feedback text,
  created_at timestamp with time zone default now()
);

-- Notifications table
create table if not exists notifications (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  title text not null,
  body text,
  type text check (type in ('feedback','badge','xp','exam','system')) default 'system',
  read boolean default false,
  created_at timestamp with time zone default now()
);

-- Enable Supabase Realtime on notifications table
alter publication supabase_realtime add table notifications;
