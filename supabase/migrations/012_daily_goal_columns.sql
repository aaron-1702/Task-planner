-- Migration 012: Synced recurring daily goals

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS daily_goal_templates JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS daily_goal_completions JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS daily_goal_updated_at JSONB NOT NULL DEFAULT '{}'::jsonb;