-- ============================================================
-- Migration 011: Ensure authenticated users can write own goal fields
-- Fixes environments where user_profiles policy/grants block UPDATE/UPSERT.
-- ============================================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.user_profiles TO authenticated;

DROP POLICY IF EXISTS users_own_profile ON public.user_profiles;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'users_own_profile_select'
  ) THEN
    CREATE POLICY users_own_profile_select
      ON public.user_profiles
      FOR SELECT
      USING (auth.uid() = id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'users_own_profile_update'
  ) THEN
    CREATE POLICY users_own_profile_update
      ON public.user_profiles
      FOR UPDATE
      USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'users_own_profile_insert'
  ) THEN
    CREATE POLICY users_own_profile_insert
      ON public.user_profiles
      FOR INSERT
      WITH CHECK (auth.uid() = id);
  END IF;
END $$;
