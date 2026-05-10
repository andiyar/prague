-- Dad's Prague Trip Dashboard - Seed Data
-- Run this AFTER schema.sql in the Supabase SQL Editor

-- Clear existing data
TRUNCATE trip_segments RESTART IDENTITY;
DELETE FROM config;

-- =============================================================================
-- TRIP SEGMENTS (all times in UTC)
-- =============================================================================
-- Timezone conversions used:
-- Sydney AEST = UTC+10, Hong Kong HKT = UTC+8, London BST = UTC+1, Prague CEST = UTC+2
--
-- Flight times (local → UTC):
-- CX100:  Depart Sydney 14:05 AEST (04:05 UTC) → Arrive Hong Kong 21:30 HKT (13:30 UTC)
-- CX255:  Depart Hong Kong 23:15 HKT (15:15 UTC) → Arrive London 06:20 BST (05:20 UTC next day)
-- BA852:  Depart London 08:35 BST (07:35 UTC) → Arrive Prague 11:30 CEST (09:30 UTC)
-- BA853:  Depart Prague 14:05 CEST (12:05 UTC) → Arrive London 15:15 BST (14:15 UTC)
-- CX250:  Depart London 18:20 BST (17:20 UTC) → Arrive Hong Kong 14:10 HKT (06:10 UTC next day)
-- CX181:  Depart Hong Kong 00:45 HKT (16:45 UTC prev day) → Arrive Sydney 11:45 AEST (01:45 UTC)

INSERT INTO trip_segments (start_time, end_time, location, status_emoji, status_text, kids_text, lat, lng, flight_number, flight_from, flight_to) VALUES

-- Tue 12 May: Departure day (Sydney morning, then flight)
('2026-05-12T00:00:00Z', '2026-05-12T04:05:00Z', 'Home in Sydney', '🏠', 'At home, getting ready', 'Dad is getting ready for his trip!', -33.8688, 151.2093, NULL, NULL, NULL),

-- Flight 1: Sydney → Hong Kong (CX100)
('2026-05-12T04:05:00Z', '2026-05-12T13:30:00Z', 'In flight: Sydney → Hong Kong', '✈️', 'Flying to Hong Kong', 'Dad''s on the plane!', NULL, NULL, 'CX100', 'SYD', 'HKG'),

-- Layover in Hong Kong (1h 45m)
('2026-05-12T13:30:00Z', '2026-05-12T15:15:00Z', 'Hong Kong Airport', '⏳', 'Layover in Hong Kong', 'Dad''s waiting for his next plane', 22.3080, 113.9185, NULL, NULL, NULL),

-- Flight 2: Hong Kong → London (CX255)
('2026-05-12T15:15:00Z', '2026-05-13T05:20:00Z', 'In flight: Hong Kong → London', '✈️', 'Flying to London', 'Dad''s on the plane!', NULL, NULL, 'CX255', 'HKG', 'LHR'),

-- Layover in London (2h 15m)
('2026-05-13T05:20:00Z', '2026-05-13T07:35:00Z', 'London Heathrow Airport', '⏳', 'Layover in London', 'Dad''s waiting for his next plane', 51.4700, -0.4543, NULL, NULL, NULL),

-- Flight 3: London → Prague (BA852)
('2026-05-13T07:35:00Z', '2026-05-13T09:30:00Z', 'In flight: London → Prague', '✈️', 'Flying to Prague', 'Dad''s on the plane!', NULL, NULL, 'BA852', 'LHR', 'PRG'),

-- Arrive Prague, head to hotel
('2026-05-13T09:30:00Z', '2026-05-13T13:00:00Z', 'Prague Airport → Hotel', '🛬', 'Just arrived in Prague!', 'Dad just landed!', 50.1008, 14.2600, NULL, NULL, NULL),

-- Wed 13 May afternoon/evening: At hotel
('2026-05-13T13:00:00Z', '2026-05-13T21:00:00Z', 'STAGES Hotel Prague', '🏨', 'At the hotel', 'Dad''s at the hotel', 50.1097, 14.4990, NULL, NULL, NULL),

-- Wed 13 May night: Sleeping (Prague night = 21:00-05:00 UTC = 23:00-07:00 CEST)
('2026-05-13T21:00:00Z', '2026-05-14T05:00:00Z', 'STAGES Hotel Prague', '😴', 'Sleeping', 'Dad''s sleeping', 50.1097, 14.4990, NULL, NULL, NULL),

-- Thu 14 May: Conference Day 1
('2026-05-14T05:00:00Z', '2026-05-14T07:00:00Z', 'STAGES Hotel Prague', '🏨', 'At the hotel (morning)', 'Dad''s at the hotel', 50.1097, 14.4990, NULL, NULL, NULL),
('2026-05-14T07:00:00Z', '2026-05-14T16:00:00Z', 'EAPC Conference - O2 Arena', '📍', 'At the conference', 'Dad''s at the conference', 50.1047, 14.4923, NULL, NULL, NULL),
('2026-05-14T16:00:00Z', '2026-05-14T21:00:00Z', 'Prague (evening)', '🏨', 'Free time in Prague', 'Dad''s exploring Prague!', 50.0875, 14.4213, NULL, NULL, NULL),
('2026-05-14T21:00:00Z', '2026-05-15T05:00:00Z', 'STAGES Hotel Prague', '😴', 'Sleeping', 'Dad''s sleeping', 50.1097, 14.4990, NULL, NULL, NULL),

-- Fri 15 May: Conference Day 2
('2026-05-15T05:00:00Z', '2026-05-15T07:00:00Z', 'STAGES Hotel Prague', '🏨', 'At the hotel (morning)', 'Dad''s at the hotel', 50.1097, 14.4990, NULL, NULL, NULL),
('2026-05-15T07:00:00Z', '2026-05-15T16:00:00Z', 'EAPC Conference - O2 Arena', '📍', 'At the conference', 'Dad''s at the conference', 50.1047, 14.4923, NULL, NULL, NULL),
('2026-05-15T16:00:00Z', '2026-05-15T21:00:00Z', 'Prague (evening)', '🏨', 'Free time in Prague', 'Dad''s exploring Prague!', 50.0875, 14.4213, NULL, NULL, NULL),
('2026-05-15T21:00:00Z', '2026-05-16T05:00:00Z', 'STAGES Hotel Prague', '😴', 'Sleeping', 'Dad''s sleeping', 50.1097, 14.4990, NULL, NULL, NULL),

-- Sat 16 May: Conference Day 3 (morning), then departure
('2026-05-16T05:00:00Z', '2026-05-16T07:00:00Z', 'STAGES Hotel Prague', '🏨', 'At the hotel (morning)', 'Dad''s at the hotel', 50.1097, 14.4990, NULL, NULL, NULL),
('2026-05-16T07:00:00Z', '2026-05-16T10:00:00Z', 'EAPC Conference - O2 Arena', '📍', 'At the conference (last day)', 'Dad''s at the conference', 50.1047, 14.4923, NULL, NULL, NULL),
('2026-05-16T10:00:00Z', '2026-05-16T12:05:00Z', 'Checking out, heading to airport', '🏠', 'Heading home!', 'Dad''s coming home!', 50.1008, 14.2600, NULL, NULL, NULL),

-- Flight 4: Prague → London (BA853)
('2026-05-16T12:05:00Z', '2026-05-16T14:15:00Z', 'In flight: Prague → London', '✈️', 'Flying to London', 'Dad''s on the plane!', NULL, NULL, 'BA853', 'PRG', 'LHR'),

-- Layover in London (3h 05m)
('2026-05-16T14:15:00Z', '2026-05-16T17:20:00Z', 'London Heathrow Airport', '⏳', 'Layover in London', 'Dad''s waiting for his next plane', 51.4700, -0.4543, NULL, NULL, NULL),

-- Flight 5: London → Hong Kong (CX250)
('2026-05-16T17:20:00Z', '2026-05-17T06:10:00Z', 'In flight: London → Hong Kong', '✈️', 'Flying to Hong Kong', 'Dad''s on the plane!', NULL, NULL, 'CX250', 'LHR', 'HKG'),

-- Layover in Hong Kong (10h 35m) - overnight
('2026-05-17T06:10:00Z', '2026-05-17T16:45:00Z', 'Hong Kong Airport', '⏳', 'Long layover in Hong Kong', 'Dad''s waiting for his next plane', 22.3080, 113.9185, NULL, NULL, NULL),

-- Flight 6: Hong Kong → Sydney (CX181)
('2026-05-17T16:45:00Z', '2026-05-18T01:45:00Z', 'In flight: Hong Kong → Sydney', '✈️', 'Flying home to Sydney!', 'Dad''s coming home!', NULL, NULL, 'CX181', 'HKG', 'SYD'),

-- Mon 18 May: Arrived home!
('2026-05-18T01:45:00Z', '2026-05-18T23:59:59Z', 'Home in Sydney!', '🏠', 'Back home!', 'Dad''s home!', -33.8688, 151.2093, NULL, NULL, NULL);

-- =============================================================================
-- CONFIG
-- =============================================================================
INSERT INTO config (key, value) VALUES
('dad_name', 'Dad'),
('home_timezone', 'Australia/Sydney'),
('trip_timezone', 'Europe/Prague'),
('return_datetime_utc', '2026-05-18T01:45:00Z'),
('contact_phone', '+61 423 518 466'),
('emergency_contact', 'Mum: +61XXXXXXXXX'),
('hotel_name', 'STAGES HOTEL Prague'),
('hotel_address', 'Ceskomoravska 19a, Prague, CZ-19000'),
('hotel_phone', '+420XXXXXXXXX'),
('conference_name', 'EAPC World Congress 2026'),
('conference_url', 'https://www.eapcnet.eu/eapc2026/'),
('insurance_phone', '+61 2 8907 5604'),
('insurance_policy', 'Liberty / ASMOF Corporate Travel'),
('consulate_phone', '+420 257 022 100');
