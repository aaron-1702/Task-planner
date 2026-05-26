-- ============================================================
-- Migration 009: Realtime for user profile goal sync
-- Ensures changes on user_profiles (goal columns) are emitted
-- to Supabase Realtime so other devices receive live updates.
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.user_profiles;
