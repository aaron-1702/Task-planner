-- Migration 003: Enable REPLICA IDENTITY FULL for work_entries
--
-- WHY THIS IS NEEDED:
-- Supabase Realtime DELETE events only include primary key columns in old_record
-- by default (REPLICA IDENTITY DEFAULT). Any Realtime filter on a non-PK column
-- (e.g. user_id) silently drops DELETE events because Supabase cannot evaluate
-- the filter without the full old row.
--
-- With REPLICA IDENTITY FULL, PostgreSQL writes all column values to the WAL
-- for UPDATE and DELETE operations. Supabase Realtime then includes the complete
-- old row in the event, allowing user_id filters to work correctly for DELETEs.
--
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).

ALTER TABLE work_entries REPLICA IDENTITY FULL;
