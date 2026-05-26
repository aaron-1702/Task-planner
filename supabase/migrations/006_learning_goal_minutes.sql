-- ============================================================
-- Migration 006: Synced monthly learning goals
-- Stores per-month learning targets on the user profile so they
-- are shared automatically across all signed-in devices.
-- ============================================================

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS learning_goal_minutes JSONB NOT NULL DEFAULT '{}'::jsonb;