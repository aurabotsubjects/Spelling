-- ═══════════════════════════════════════════════════════════════
--  SpellingHub / WordLab — migration for the Years 5–6 additions
--
--  Run this ONCE in Supabase: Dashboard → SQL Editor → New query →
--  paste the whole file → Run. It only CREATEs new tables; it does
--  not touch students, word_progress, weekly_lists, history_snapshots
--  or archives, so existing results cannot be affected.
--
--  Until this is run, every feature below still works — it just
--  saves to one device only, and the browser console logs a quiet
--  "optional sync skipped" note. Nothing breaks and no test result
--  is ever at risk.
--
--  IMPORTANT — about the policies at the bottom:
--  This app is used by Trusted Testers and relievers who are NOT
--  logged in as the teacher (they reach Supabase with the anonymous
--  key), so the policies below allow the anon role, exactly as your
--  existing tables must already do for testing to work at all.
--  Before running, open Authentication → Policies and compare these
--  with the policies on your existing `word_progress` table. If
--  yours are stricter, tighten these to match.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Error analysis ─────────────────────────────────────────
-- One row per classified spelling error. Not a counter: the log is
-- what makes "7 of 11 misses are vowel digraphs" possible.
create table if not exists public.spelling_errors (
  id          bigserial primary key,
  student_id  bigint not null references public.students(id) on delete cascade,
  week_index  integer,
  word        text not null,
  category    text not null,
  logged_date text,
  created_at  timestamptz not null default now()
);
create index if not exists spelling_errors_student_idx on public.spelling_errors(student_id);

-- ── 2. Spelling journal ───────────────────────────────────────
create table if not exists public.journal_entries (
  id          bigserial primary key,
  student_id  bigint not null references public.students(id) on delete cascade,
  position    integer not null default 0,
  word        text not null,
  note        text,
  added_date  text,
  created_at  timestamptz not null default now()
);
create index if not exists journal_entries_student_idx on public.journal_entries(student_id);

-- ── 3. Word Inquiry Study charts ──────────────────────────────
-- One row per student per word. The reserved word '__current' holds
-- which word that student is currently working on.
create table if not exists public.word_inquiries (
  student_id  bigint not null references public.students(id) on delete cascade,
  word        text not null,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  primary key (student_id, word)
);

-- ── 4. Placement pre-tests ────────────────────────────────────
create table if not exists public.pretests (
  student_id  bigint primary key references public.students(id) on delete cascade,
  tested_date text,
  marks       jsonb not null default '{}'::jsonb,
  suggested   integer,
  extension   boolean not null default false,
  updated_at  timestamptz not null default now()
);

-- ── 5. Word Grids ─────────────────────────────────────────────
-- Teacher-scoped, not student-scoped: the grid is modelled on the
-- board for the whole class, keyed by chart cycle / week / day.
create table if not exists public.word_grids (
  teacher_id  uuid not null,
  cycle       integer not null,
  week_index  integer not null,
  day         integer not null,
  rows        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  primary key (teacher_id, cycle, week_index, day)
);

-- ── 6. Teacher settings ───────────────────────────────────────
-- Chart cycle (Y5 or Y6 this year) and each student's year group on
-- the roll, which is kept separate from their spelling level.
create table if not exists public.teacher_settings (
  teacher_id  uuid primary key,
  settings    jsonb not null default '{}'::jsonb,
  enrolment   jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- ── Row Level Security ────────────────────────────────────────
alter table public.spelling_errors  enable row level security;
alter table public.journal_entries  enable row level security;
alter table public.word_inquiries   enable row level security;
alter table public.pretests         enable row level security;
alter table public.word_grids       enable row level security;
alter table public.teacher_settings enable row level security;

do $$
declare t text;
begin
  foreach t in array array['spelling_errors','journal_entries','word_inquiries',
                           'pretests','word_grids','teacher_settings']
  loop
    execute format('drop policy if exists %I on public.%I', t||'_all', t);
    execute format(
      'create policy %I on public.%I for all to anon, authenticated using (true) with check (true)',
      t||'_all', t);
  end loop;
end $$;

-- ── Done ──────────────────────────────────────────────────────
-- Reload the app. The console will stop logging "optional sync
-- skipped", and pre-tests, error logs, journals, inquiries, word
-- grids and the chart-cycle setting will follow you across devices.
