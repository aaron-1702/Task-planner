-- ============================================================
-- Migration 007: Per-month learning goal update timestamps
-- Enables conflict-aware merge (last-write-wins per month)
-- for synchronized learning goals across devices.
-- ============================================================

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS learning_goal_updated_at JSONB NOT NULL DEFAULT '{}'::jsonb;
