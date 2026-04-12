#!/usr/bin/env python3
"""Extract EAPC 2026 programme from Exordo API into structured JSON for Notion import."""

import json
import re
from datetime import datetime, timedelta, timezone

# Venue mapping
VENUES = {
    1: "Refreshment & lunch area",
    2: "Hall A",
    3: "C1",
    4: "C2",
    5: "D4",
    6: "D3",
    7: "C3",
    8: "D9",
    9: "D8",
    10: "D7",
    11: "Printed Posters Hall",
}

# Session type display names
TYPE_MAP = {
    "keynote_with_presentations": "Keynote",
    "oral_with_presentations": "Oral",
    "poster_with_presentations": "Poster",
    "panel_with_presentations": "Panel",
    "general_with_presentations": "General",
    "meeting_with_presentations": "Meeting",
    "tea_and_coffee_with_presentations": "Break",
    "lunch_with_presentations": "Lunch",
    "keynote_manual": "Keynote",
    "oral_manual": "Oral",
    "poster_manual": "Poster",
    "panel_manual": "Panel",
    "general_manual": "General",
    "meeting_manual": "Meeting",
    "tea_and_coffee_manual": "Break",
    "lunch_manual": "Lunch",
}

# Prague is CEST (UTC+2) in May
PRAGUE_TZ = timezone(timedelta(hours=2))


def strip_html(html):
    """Remove HTML tags and clean up whitespace."""
    if not html:
        return ""
    text = re.sub(r'<br\s*/?>', '\n', html)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'&nbsp;', ' ', text)
    text = re.sub(r'&amp;', '&', text)
    text = re.sub(r'&lt;', '<', text)
    text = re.sub(r'&gt;', '>', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def utc_to_prague(utc_str):
    """Convert UTC ISO string to Prague time string."""
    if not utc_str:
        return ""
    dt = datetime.fromisoformat(utc_str.replace('Z', '+00:00'))
    prague = dt.astimezone(PRAGUE_TZ)
    return prague.strftime("%H:%M")


def utc_to_prague_iso(utc_str):
    """Convert UTC ISO string to Prague ISO string."""
    if not utc_str:
        return ""
    dt = datetime.fromisoformat(utc_str.replace('Z', '+00:00'))
    prague = dt.astimezone(PRAGUE_TZ)
    return prague.isoformat()


def get_session_type(type_str):
    """Map API type to display type."""
    return TYPE_MAP.get(type_str, type_str.split("_")[0].capitalize() if type_str else "Unknown")


def extract_presentations(session):
    """Extract presentations from a session."""
    presentations = []
    for pres in session.get("schedule_event_presentations", []):
        paper = pres.get("paper", {})
        if not paper:
            continue

        authors = []
        for a in paper.get("paper_authors", []):
            name = f"{a.get('prefix', '')} {a.get('name', '')} {a.get('surname', '')}".strip()
            org = a.get("identity_string", "")
            presenting = a.get("presenting", False)
            authors.append({
                "name": name,
                "organisation": org,
                "presenting": presenting,
            })

        presentations.append({
            "id": pres["id"],
            "title": paper.get("title", ""),
            "starts_at": utc_to_prague(pres.get("starts_at")),
            "ends_at": utc_to_prague(pres.get("ends_at")),
            "duration_mins": pres.get("duration", 0),
            "authors": authors,
            "presenter": next((a["name"] for a in authors if a["presenting"]), ""),
        })

    return presentations


def extract_chairs(session):
    """Extract session chairs/organisers."""
    chairs = []
    for org in session.get("session_organisers", []):
        user = org.get("user", {})
        if user:
            name = f"{user.get('prefix', '')} {user.get('name', '')} {user.get('surname', '')}".strip()
            chairs.append(name)
        elif org.get("name"):
            name = f"{org.get('prefix', '')} {org.get('name', '')} {org.get('surname', '')}".strip()
            chairs.append(name)
    return chairs


def process_day(filepath, day_label):
    """Process a single day's JSON file."""
    with open(filepath) as f:
        data = json.load(f)

    sessions = []
    for s in data["data"]:
        session_type = get_session_type(s.get("type", ""))

        # Skip breaks and lunches for the Notion database
        # (keep them but tag them)

        presentations = extract_presentations(s)
        chairs = extract_chairs(s)
        description = strip_html(s.get("description", ""))

        sessions.append({
            "id": s["id"],
            "day": day_label,
            "date": day_label,
            "title": s["title"],
            "type": session_type,
            "venue": VENUES.get(s.get("schedule_venue_id"), "TBD"),
            "starts_at": utc_to_prague(s.get("starts_at")),
            "ends_at": utc_to_prague(s.get("ends_at")),
            "starts_at_iso": utc_to_prague_iso(s.get("starts_at")),
            "ends_at_iso": utc_to_prague_iso(s.get("ends_at")),
            "description": description,
            "chairs": chairs,
            "presentations_count": s.get("presentations_count", 0),
            "presentations": presentations,
        })

    return sessions


def main():
    all_sessions = []

    days = [
        ("data/eapc/day_2026-05-14.json", "2026-05-14"),
        ("data/eapc/day_2026-05-15.json", "2026-05-15"),
        ("data/eapc/day_2026-05-16.json", "2026-05-16"),
    ]

    day_names = {
        "2026-05-14": "Thursday",
        "2026-05-15": "Friday",
        "2026-05-16": "Saturday",
    }

    for filepath, date in days:
        sessions = process_day(filepath, date)
        all_sessions.extend(sessions)
        print(f"{day_names[date]} {date}: {len(sessions)} sessions, "
              f"{sum(s['presentations_count'] for s in sessions)} presentations")

    # Count total presentations
    total_pres = sum(len(s["presentations"]) for s in all_sessions)
    print(f"\nTotal: {len(all_sessions)} sessions, {total_pres} presentations extracted")

    # Save structured output
    with open("data/eapc/programme_structured.json", "w") as f:
        json.dump(all_sessions, f, indent=2, ensure_ascii=False)

    print("Saved to data/eapc/programme_structured.json")

    # Also print a summary
    print("\n=== PROGRAMME OVERVIEW ===\n")
    for date, day_name in day_names.items():
        print(f"\n--- {day_name}, {date} ---")
        day_sessions = [s for s in all_sessions if s["date"] == date]
        for s in sorted(day_sessions, key=lambda x: x["starts_at"]):
            chair_str = f" (Chair: {', '.join(s['chairs'])})" if s['chairs'] else ""
            pres_str = f" [{s['presentations_count']} presentations]" if s['presentations_count'] > 0 else ""
            print(f"  {s['starts_at']}-{s['ends_at']}  [{s['type']:>7}]  {s['venue']:<25} {s['title']}{pres_str}{chair_str}")


if __name__ == "__main__":
    main()
