-- ============================================================
-- Migration 010: Idempotent realtime publication for user_profiles
-- Safely ensures user_profiles is part of supabase_realtime even
-- when environments were partially migrated.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'user_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_profiles;
  END IF;
END $$;
