-- Conference picks table for EAPragueC 2026
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/dyxupzbyssvcxjppipnl/sql

CREATE TABLE IF NOT EXISTS conference_picks (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    session_id  INTEGER NOT NULL,
    picked_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, session_id)
);

ALTER TABLE conference_picks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon all on conference_picks" ON conference_picks
    FOR ALL USING (true) WITH CHECK (true);
