-- Push Notification Tables for Where's Ben?
-- Run this in Supabase SQL Editor

-- Table: push_tokens
-- Stores device tokens for push notifications
CREATE TABLE IF NOT EXISTS push_tokens (
    device_id    TEXT PRIMARY KEY,
    token        TEXT NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Table: sent_notifications
-- Tracks sent notifications to avoid duplicates
CREATE TABLE IF NOT EXISTS sent_notifications (
    id           SERIAL PRIMARY KEY,
    trigger_type TEXT NOT NULL,  -- 'status', 'departure', 'landing', 'presentation'
    trigger_id   TEXT NOT NULL,  -- segment ID, override ID, or custom identifier
    sent_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Create unique index to prevent duplicate notifications
CREATE UNIQUE INDEX IF NOT EXISTS sent_notifications_unique
ON sent_notifications(trigger_type, trigger_id);

-- Enable RLS
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_notifications ENABLE ROW LEVEL SECURITY;

-- Policies for push_tokens
CREATE POLICY "Allow anon insert on push_tokens" ON push_tokens
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update on push_tokens" ON push_tokens
    FOR UPDATE USING (true);

CREATE POLICY "Allow anon select on push_tokens" ON push_tokens
    FOR SELECT USING (true);

-- Policies for sent_notifications
CREATE POLICY "Allow anon insert on sent_notifications" ON sent_notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon select on sent_notifications" ON sent_notifications
    FOR SELECT USING (true);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for push_tokens
DROP TRIGGER IF EXISTS update_push_tokens_updated_at ON push_tokens;
CREATE TRIGGER update_push_tokens_updated_at
    BEFORE UPDATE ON push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
