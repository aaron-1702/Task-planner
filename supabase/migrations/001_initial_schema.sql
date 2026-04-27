-- =============================================================================
-- Smart Task Planner – Supabase PostgreSQL Schema
-- Run in the Supabase SQL Editor (Project > SQL Editor > New Query)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0.  Enable required extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- full-text search on tasks

-- ---------------------------------------------------------------------------
-- 1.  User Profiles (extends Supabase auth.users)
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_profiles (
    id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email         TEXT NOT NULL,
    display_name  TEXT,
    avatar_url    TEXT,
    fcm_token     TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-insert profile on new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, display_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'display_name',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2.  Categories
-- ---------------------------------------------------------------------------
CREATE TABLE public.categories (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    color_value  INT  NOT NULL DEFAULT 4284955319, -- Flutter Color int
    icon         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_categories_user ON public.categories (user_id);

-- ---------------------------------------------------------------------------
-- 3.  Tasks
-- ---------------------------------------------------------------------------
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high');
CREATE TYPE task_status   AS ENUM ('open', 'inProgress', 'done');
CREATE TYPE recurrence_type AS ENUM ('none', 'daily', 'weekly', 'monthly', 'custom');

CREATE TABLE public.tasks (
    id                 UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id            UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title              TEXT         NOT NULL CHECK (char_length(title) <= 200),
    description        TEXT         CHECK (char_length(description) <= 5000),
    deadline           TIMESTAMPTZ,
    priority           task_priority NOT NULL DEFAULT 'medium',
    status             task_status   NOT NULL DEFAULT 'open',
    tags               TEXT[]        NOT NULL DEFAULT '{}',
    category_id        UUID          REFERENCES public.categories(id) ON DELETE SET NULL,
    recurrence_rule    JSONB,
    estimated_minutes  INT           CHECK (estimated_minutes > 0),
    pomodoro_count     INT           DEFAULT 0,
    is_deleted         BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_tasks_user       ON public.tasks (user_id);
CREATE INDEX idx_tasks_deadline   ON public.tasks (user_id, deadline) WHERE NOT is_deleted;
CREATE INDEX idx_tasks_status     ON public.tasks (user_id, status)   WHERE NOT is_deleted;
CREATE INDEX idx_tasks_updated    ON public.tasks (user_id, updated_at DESC);
CREATE INDEX idx_tasks_tags       ON public.tasks USING GIN (tags);
-- Full-text search
CREATE INDEX idx_tasks_fts ON public.tasks
    USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER tasks_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4.  Reminders
-- ---------------------------------------------------------------------------
CREATE TABLE public.reminders (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id      UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
    remind_at    TIMESTAMPTZ NOT NULL,
    is_sent      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reminders_task    ON public.reminders (task_id);
CREATE INDEX idx_reminders_pending ON public.reminders (remind_at) WHERE NOT is_sent;

-- ---------------------------------------------------------------------------
-- 5.  Row-Level Security (RLS)
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders     ENABLE ROW LEVEL SECURITY;

-- user_profiles: users see only their own row
CREATE POLICY "users_own_profile"
    ON public.user_profiles FOR ALL
    USING (auth.uid() = id);

-- categories: users see only their own categories
CREATE POLICY "users_own_categories"
    ON public.categories FOR ALL
    USING (auth.uid() = user_id);

-- tasks: users see only their own tasks
CREATE POLICY "users_own_tasks"
    ON public.tasks FOR ALL
    USING (auth.uid() = user_id);

-- reminders: users see only their own reminders
CREATE POLICY "users_own_reminders"
    ON public.reminders FOR ALL
    USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 6.  Realtime (enable for tasks table)
-- ---------------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;

-- ---------------------------------------------------------------------------
-- 7.  Seed default categories (run per user via Edge Function or trigger)
-- ---------------------------------------------------------------------------
-- Example: call after user signs up
-- INSERT INTO public.categories (user_id, name, color_value, icon)
-- VALUES
--   ('<user_id>', 'Work',     4280391411, 'briefcase'),
--   ('<user_id>', 'Personal', 4284955319, 'person'),
--   ('<user_id>', 'Health',   4278228616, 'heart'),
--   ('<user_id>', 'Learning', 4293271817, 'book');
