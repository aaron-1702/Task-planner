-- Migration 013: Add work_entries to supabase_realtime publication
--
-- WHY THIS IS NEEDED:
-- work_entries was created in migration 002 and given REPLICA IDENTITY FULL
-- in migration 003, but was never added to the supabase_realtime publication.
-- Without this, all Realtime subscriptions to work_entries fail with:
--   RealtimeDisabledForConfiguration: Unable to subscribe to changes ...
--
-- Idempotent: safe to run multiple times.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM   pg_publication_tables
    WHERE  pubname   = 'supabase_realtime'
      AND  schemaname = 'public'
      AND  tablename  = 'work_entries'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.work_entries;
  END IF;
END;
$$;
