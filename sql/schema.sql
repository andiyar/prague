-- Dad's Prague Trip Dashboard - Supabase Schema
-- Run this in the Supabase SQL Editor

-- Table: trip_segments
-- Stores the pre-planned schedule of the trip
CREATE TABLE IF NOT EXISTS trip_segments (
    id SERIAL PRIMARY KEY,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    status_emoji TEXT NOT NULL,
    status_text TEXT NOT NULL,
    kids_text TEXT NOT NULL,
    lat DECIMAL(9,6),
    lng DECIMAL(9,6),
    flight_number TEXT,
    flight_from TEXT,
    flight_to TEXT
);

-- Table: status_override
-- Manual status updates that override the schedule
CREATE TABLE IF NOT EXISTS status_override (
    id INTEGER PRIMARY KEY DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    status_emoji TEXT NOT NULL,
    status_text TEXT NOT NULL,
    kids_text TEXT NOT NULL,
    note TEXT,
    lat DECIMAL(9,6),
    lng DECIMAL(9,6)
);

-- Table: config
-- Key-value store for settings
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- Enable Row Level Security (RLS) but allow public read access
ALTER TABLE trip_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_override ENABLE ROW LEVEL SECURITY;
ALTER TABLE config ENABLE ROW LEVEL SECURITY;

-- Policies for public read access
CREATE POLICY "Allow public read access on trip_segments" ON trip_segments
    FOR SELECT USING (true);

CREATE POLICY "Allow public read access on status_override" ON status_override
    FOR SELECT USING (true);

CREATE POLICY "Allow public read access on config" ON config
    FOR SELECT USING (true);

-- Policies for authenticated write access (via anon key with API)
CREATE POLICY "Allow anon insert on status_override" ON status_override
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update on status_override" ON status_override
    FOR UPDATE USING (true);

CREATE POLICY "Allow anon delete on status_override" ON status_override
    FOR DELETE USING (true);
