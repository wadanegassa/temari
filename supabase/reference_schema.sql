-- Reference schema for Temari (extend with updated_at columns for LWW sync if needed).
-- Run in Supabase SQL editor. Enable RLS and policies per product spec.

create table if not exists profiles (
  id uuid references auth.users primary key,
  display_name text,
  preferred_language text default 'en',
  created_at timestamptz default now()
);

create table if not exists subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  color text not null,
  icon text not null,
  created_at timestamptz default now()
);

create table if not exists notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  subject_id uuid references subjects(id) on delete cascade,
  title text,
  content text,
  type text not null,
  file_url text,
  ai_summary text,
  ai_explanation text,
  language text default 'en',
  created_at timestamptz default now()
);

create table if not exists flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  note_id uuid references notes(id) on delete cascade,
  subject_id uuid references subjects(id) on delete cascade,
  question text not null,
  answer text not null,
  difficulty int default 0,
  next_review timestamptz default now(),
  review_count int default 0,
  created_at timestamptz default now()
);

create table if not exists exam_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  subject_id uuid references subjects(id) on delete cascade,
  exam_date timestamptz,
  total_cards int default 0,
  correct_count int default 0,
  created_at timestamptz default now()
);

-- Storage bucket: temari-files (create in dashboard)
