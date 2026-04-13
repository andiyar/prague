#!/bin/bash
# Fetch EAPC 2026 programme data from Exordo API
#
# The Exordo conference platform exposes a public REST API at:
#   https://eapc2026.exordo.com/api/schedule_events
#
# No authentication is required. The API was discovered by monitoring
# network requests on the programme page:
#   https://eapc2026.exordo.com/programme/sessions/2026-05-14
#
# HOW THIS WAS FOUND (April 2026):
#   1. Opened the Exordo programme page in Chrome
#   2. Monitored network requests filtering for "session"
#   3. Found the API endpoint at /api/schedule_events
#   4. The expand= parameter pulls in nested presentation/author data
#
# USAGE:
#   cd data/eapc
#   ./fetch_programme.sh
#
# This will:
#   1. Download raw JSON for each conference day
#   2. Run extract_programme.py to build programme_structured.json
#   3. Copy the result to ConferenceNav/Resources/programme.json
#
# AFTER FETCHING:
#   - Rebuild the ConferenceNav Xcode project: cd ConferenceNav && xcodegen generate
#   - Build and test the app

set -euo pipefail
cd "$(dirname "$0")"

BASE_URL="https://eapc2026.exordo.com/api/schedule_events"

# The expand parameter fetches all nested data we need:
#   - schedule_event_presentations: the talks/posters within each session
#   - session_organisers: session chairs
#   - .paper.paper_authors: author details for each presentation
#   - .paper.paper_authors.organisation: author affiliations
#   - .paper.paper_authors.user: author user profiles
#   - schedule_event_manual_content: manually added content
EXPAND="schedule_event_presentations,session_organisers,schedule_event_presentations.paper.paper_authors,schedule_event_presentations.paper.paper_authors.organisation,schedule_event_presentations.paper.paper_authors.user,schedule_event_manual_content"

DAYS=("2026-05-14" "2026-05-15" "2026-05-16")

echo "=== Fetching EAPC 2026 Programme from Exordo API ==="
echo ""

for DAY in "${DAYS[@]}"; do
    OUTPUT="day_${DAY}.json"
    echo "Fetching ${DAY}..."

    curl -s "${BASE_URL}?limit=999&date=${DAY}&order_by=preview_list&expand=${EXPAND}" \
        -o "${OUTPUT}"

    # Verify we got valid JSON with data
    COUNT=$(python3 -c "import json,sys; d=json.load(open('${OUTPUT}')); print(len(d.get('data',[])))")
    echo "  -> ${COUNT} sessions saved to ${OUTPUT}"
done

echo ""
echo "=== Running extraction script ==="

# Run from repo root since extract_programme.py uses relative paths
cd ../..
python3 data/eapc/extract_programme.py

echo ""
echo "=== Updating ConferenceNav bundle ==="
cp data/eapc/programme_structured.json ConferenceNav/Resources/programme.json
echo "Copied to ConferenceNav/Resources/programme.json"

echo ""
echo "Done! Remember to rebuild the Xcode project if the structure changed:"
echo "  cd ConferenceNav && xcodegen generate"
