-- Add photo + audience support to status_override
-- Run in Supabase SQL Editor

ALTER TABLE status_override
    ADD COLUMN IF NOT EXISTS photo_url TEXT,
    ADD COLUMN IF NOT EXISTS audience  TEXT NOT NULL DEFAULT 'both'
        CHECK (audience IN ('main', 'kids', 'both'));

-- Public storage bucket for status photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('status-photos', 'status-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Anon (apps) can upload, public can read
DROP POLICY IF EXISTS "Anon upload status-photos" ON storage.objects;
CREATE POLICY "Anon upload status-photos"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'status-photos');

DROP POLICY IF EXISTS "Public read status-photos" ON storage.objects;
CREATE POLICY "Public read status-photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'status-photos');

DROP POLICY IF EXISTS "Anon delete status-photos" ON storage.objects;
CREATE POLICY "Anon delete status-photos"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'status-photos');
