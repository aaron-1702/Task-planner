-- ============================================================
-- Migration 004: Learning Entries
-- Tracks daily learning sessions with start/end times and breaks.
-- ============================================================

CREATE TABLE IF NOT EXISTS learning_entries (
  id            TEXT        PRIMARY KEY,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date          DATE        NOT NULL,
  start_time    TIMESTAMPTZ NOT NULL,
  end_time      TIMESTAMPTZ NOT NULL,
  break_minutes INTEGER     NOT NULL DEFAULT 0,
  topic         TEXT        NOT NULL,
  note          TEXT,
  is_deleted    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_learning_end_after_start CHECK (end_time > start_time),
  CONSTRAINT chk_learning_break_positive CHECK (break_minutes >= 0)
);

CREATE INDEX IF NOT EXISTS idx_learning_entries_user_date
  ON learning_entries (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_learning_entries_updated_at
  ON learning_entries (user_id, updated_at DESC);

ALTER TABLE learning_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own learning entries"
  ON learning_entries
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION update_learning_entry_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_learning_entries_updated_at
  BEFORE UPDATE ON learning_entries
  FOR EACH ROW EXECUTE FUNCTION update_learning_entry_updated_at();

ALTER PUBLICATION supabase_realtime ADD TABLE public.learning_entries;
