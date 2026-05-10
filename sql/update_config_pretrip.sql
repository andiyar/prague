-- Pre-trip config update — run in Supabase SQL Editor
-- Updates contact phone and adds insurance details

-- Ben's mobile number
UPDATE config SET value = '+61 423 518 466' WHERE key = 'contact_phone';

-- Travel insurance: Liberty Specialty Markets / ASMOF Corporate Travel
-- Emergency assistance via World Travel Protection (24/7)
INSERT INTO config (key, value) VALUES
    ('insurance_phone', '+61 2 8907 5604'),
    ('insurance_policy', 'Liberty / ASMOF Corporate Travel'),
    ('consulate_phone', '+420 257 022 100')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Remove unused placeholder rows
DELETE FROM config WHERE key IN ('emergency_contact', 'hotel_phone');
