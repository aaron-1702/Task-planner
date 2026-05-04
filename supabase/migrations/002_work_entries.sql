-- ============================================================
-- Migration 002: Work Entries
-- Tracks daily work sessions with start/end times and breaks.
-- ============================================================

CREATE TABLE IF NOT EXISTS work_entries (
  id            TEXT        PRIMARY KEY,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date          DATE        NOT NULL,               -- calendar day of the entry
  start_time    TIMESTAMPTZ NOT NULL,               -- absolute start (UTC)
  end_time      TIMESTAMPTZ NOT NULL,               -- absolute end (UTC)
  break_minutes INTEGER     NOT NULL DEFAULT 0,     -- break duration in minutes
  note          TEXT,                               -- optional activity note
  is_deleted    BOOLEAN     NOT NULL DEFAULT FALSE, -- soft-delete flag
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_end_after_start CHECK (end_time > start_time),
  CONSTRAINT chk_break_positive  CHECK (break_minutes >= 0)
);

-- ── Indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_work_entries_user_date
  ON work_entries (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_work_entries_updated_at
  ON work_entries (user_id, updated_at DESC);

-- ── Row-Level Security ─────────────────────────────────────
ALTER TABLE work_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own work entries"
  ON work_entries
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── Auto-update updated_at ─────────────────────────────────
CREATE OR REPLACE FUNCTION update_work_entry_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_work_entries_updated_at
  BEFORE UPDATE ON work_entries
  FOR EACH ROW EXECUTE FUNCTION update_work_entry_updated_at();
