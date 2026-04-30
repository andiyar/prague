#!/bin/bash
# Refresh EAPC 2026 programme from Exordo API.
#
# Usage:
#   bash data/eapc/refresh.sh                # Pull, diff, prompt to apply
#   bash data/eapc/refresh.sh --apply        # Pull, diff, auto-replace canonical files
#
# What it does:
#   1. Pulls all 3 days from Exordo's public schedule_events API (no auth needed)
#   2. Saves raw JSON to data/eapc/refresh-YYYYMMDD/
#   3. Diffs against the canonical data/eapc/day_*.json
#   4. With --apply, replaces canonical files and regenerates programme_structured.json
#
# Source: https://eapc2026.exordo.com/api/schedule_events
# This is the same endpoint the public website uses — no scraping, no auth.

set -e

cd "$(dirname "$0")/../.."  # repo root

REFRESH_DIR="data/eapc/refresh-$(date +%Y%m%d)"
mkdir -p "$REFRESH_DIR"

EXPAND="schedule_event_presentations,session_organisers,schedule_event_presentations.paper.paper_authors,schedule_event_presentations.paper.paper_authors.organisation,schedule_event_presentations.paper.paper_authors.user,schedule_event_manual_content"

echo "Pulling fresh programme from Exordo into $REFRESH_DIR/"
for date in 2026-05-14 2026-05-15 2026-05-16; do
  url="https://eapc2026.exordo.com/api/schedule_events?limit=999&date=${date}&order_by=preview_list&expand=${EXPAND}"
  curl -s "$url" > "$REFRESH_DIR/day_${date}.json"
  count=$(python3 -c "import json; print(len(json.load(open('$REFRESH_DIR/day_${date}.json'))['data']))")
  echo "  ✓ $date — $count sessions"
done

echo ""
echo "Diffing against canonical data/eapc/day_*.json..."
python3 data/eapc/diff_programme.py "$REFRESH_DIR"

if [ "$1" = "--apply" ]; then
  echo ""
  echo "Applying refresh — replacing canonical files and regenerating programme_structured.json"
  cp "$REFRESH_DIR"/day_*.json data/eapc/
  python3 data/eapc/extract_programme.py | head -5
  echo ""
  echo "Done. Don't forget to:"
  echo "  1. Copy programme_structured.json to ConferenceNav/Resources/programme.json"
  echo "  2. Bump the lastUpdated stamp in ConferenceStore.swift"
  echo "  3. Rebuild and push to TestFlight"
else
  echo ""
  echo "Run with --apply to replace canonical files."
fi
