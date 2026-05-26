-- ============================================================
-- Migration 008: Synced monthly work goals
-- Stores monthly work targets and per-month update timestamps
-- for conflict-aware cross-device synchronization.
-- ============================================================

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS work_goal_minutes JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS work_goal_updated_at JSONB NOT NULL DEFAULT '{}'::jsonb;
