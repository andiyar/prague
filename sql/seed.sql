-- Dad's Prague Trip Dashboard - Seed Data
-- Run this AFTER schema.sql in the Supabase SQL Editor

-- Clear existing data
TRUNCATE trip_segments RESTART IDENTITY;
DELETE FROM config;

-- =============================================================================
-- TRIP SEGMENTS (all times in UTC)
-- =============================================================================
-- Timezone conversions used:
-- Sydney AEST = UTC+10, Prague CEST = UTC+2, Dubai GST = UTC+4
--
-- Flight times (local → UTC):
-- EK417: Depart Sydney 20:10 AEST (10:10 UTC) → Arrive Dubai 04:30 GST (00:30 UTC next day)
-- EK139: Depart Dubai 08:35 GST (04:35 UTC) → Arrive Prague 13:00 CEST (11:00 UTC)
-- EK140: Depart Prague 16:10 CEST (14:10 UTC) → Arrive Dubai 23:55 GST (19:55 UTC)
-- EK412: Depart Dubai 10:10 GST (06:10 UTC) → Arrive Sydney 06:05 AEST (20:05 UTC previous day... wait, that's next day)
--        Actually: Depart Sun 17 May 10:10 Dubai = 06:10 UTC, Arrive Mon 18 May 06:05 Sydney = 20:05 UTC Sun 17 May
--        Flight is 13h55m, so 06:10 + 13:55 = 20:05 UTC. Arrives Mon 06:05 AEST = 20:05 UTC Sun. Correct!

INSERT INTO trip_segments (start_time, end_time, location, status_emoji, status_text, kids_text, lat, lng, flight_number, flight_from, flight_to) VALUES

-- Tue 12 May: Departure day (Sydney morning/afternoon, then flight)
('2026-05-12T00:00:00Z', '2026-05-12T10:10:00Z', 'Home in Sydney', '🏠', 'At home, getting ready', 'Dad is getting ready for his trip!', -33.8688, 151.2093, NULL, NULL, NULL),

-- Flight 1: Sydney → Dubai (EK417)
('2026-05-12T10:10:00Z', '2026-05-13T00:30:00Z', 'In flight: Sydney → Dubai', '✈️', 'Flying to Dubai', 'Dad''s on the plane!', NULL, NULL, 'EK417', 'SYD', 'DXB'),

-- Layover in Dubai (4h 5m)
('2026-05-13T00:30:00Z', '2026-05-13T04:35:00Z', 'Dubai Airport', '⏳', 'Layover in Dubai', 'Dad''s waiting for his next plane', 25.2532, 55.3657, NULL, NULL, NULL),

-- Flight 2: Dubai → Prague (EK139)
('2026-05-13T04:35:00Z', '2026-05-13T11:00:00Z', 'In flight: Dubai → Prague', '✈️', 'Flying to Prague', 'Dad''s on the plane!', NULL, NULL, 'EK139', 'DXB', 'PRG'),

-- Arrive Prague, head to hotel
('2026-05-13T11:00:00Z', '2026-05-13T13:00:00Z', 'Prague Airport → Hotel', '🛬', 'Just arrived in Prague!', 'Dad just landed!', 50.1008, 14.2600, NULL, NULL, NULL),

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
('2026-05-16T10:00:00Z', '2026-05-16T14:10:00Z', 'Checking out, heading to airport', '🏠', 'Heading home!', 'Dad''s coming home!', 50.1008, 14.2600, NULL, NULL, NULL),

-- Flight 3: Prague → Dubai (EK140)
('2026-05-16T14:10:00Z', '2026-05-16T19:55:00Z', 'In flight: Prague → Dubai', '✈️', 'Flying to Dubai', 'Dad''s on the plane!', NULL, NULL, 'EK140', 'PRG', 'DXB'),

-- Layover in Dubai (10h 15m) - includes overnight
('2026-05-16T19:55:00Z', '2026-05-17T06:10:00Z', 'Dubai Airport', '⏳', 'Long layover in Dubai', 'Dad''s waiting for his next plane', 25.2532, 55.3657, NULL, NULL, NULL),

-- Flight 4: Dubai → Sydney (EK412)
('2026-05-17T06:10:00Z', '2026-05-17T20:05:00Z', 'In flight: Dubai → Sydney', '✈️', 'Flying home to Sydney!', 'Dad''s coming home!', NULL, NULL, 'EK412', 'DXB', 'SYD'),

-- Mon 18 May: Arrived home!
('2026-05-17T20:05:00Z', '2026-05-18T23:59:59Z', 'Home in Sydney!', '🏠', 'Back home!', 'Dad''s home!', -33.8688, 151.2093, NULL, NULL, NULL);

-- =============================================================================
-- CONFIG
-- =============================================================================
INSERT INTO config (key, value) VALUES
('dad_name', 'Dad'),
('home_timezone', 'Australia/Sydney'),
('trip_timezone', 'Europe/Prague'),
('return_datetime_utc', '2026-05-17T20:05:00Z'),
('contact_phone', '+61XXXXXXXXX'),
('emergency_contact', 'Mum: +61XXXXXXXXX'),
('hotel_name', 'STAGES HOTEL Prague'),
('hotel_address', 'Ceskomoravska 19a, Prague, CZ-19000'),
('hotel_phone', '+420XXXXXXXXX'),
('conference_name', 'EAPC World Congress 2026'),
('conference_url', 'https://www.eapcnet.eu/eapc2026/');
