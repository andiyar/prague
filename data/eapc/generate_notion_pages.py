#!/usr/bin/env python3
"""Generate Notion pages JSON from structured EAPC programme data."""

import json
import re
from datetime import datetime, timedelta, timezone

PRAGUE_TZ = timezone(timedelta(hours=2))

DAY_MAP = {
    "2026-05-14": "Thu 14 May",
    "2026-05-15": "Fri 15 May",
    "2026-05-16": "Sat 16 May",
}

# Auto-tag sessions based on title keywords
TAG_RULES = [
    (r"(?i)\bpain\b", "Pain"),
    (r"(?i)\bsymptom", "Symptoms"),
    (r"(?i)\bpsycholog", "Psychology"),
    (r"(?i)\bspiritual|social.*issues|existential", "Social/Spiritual"),
    (r"(?i)\bbereavement|grief", "Bereavement"),
    (r"(?i)\bcaregiv|family\s+care|caring\s+at\s+home", "Caregivers"),
    (r"(?i)\bservice\s+dev|system\s+change|development\s+of\s+palliative|integration\s+of", "Service Dev"),
    (r"(?i)\beducat|training|EPEC", "Education"),
    (r"(?i)\bcommunicat", "Communication"),
    (r"(?i)\bpaediatric|pediatric|children|perinatal", "Paediatrics"),
    (r"(?i)\bethic|policy|law|assisted\s+dying", "Ethics/Policy"),
    (r"(?i)\bdigital|technolog|innovation|AI\b|artificial\s+intellig", "Digital/Tech"),
    (r"(?i)\bresearch\s+method|methodology|participatory\s+research", "Research Methods"),
    (r"(?i)\brehabilitat", "Rehab"),
    (r"(?i)\bcommunity|advocacy|volunteering|public\s+health", "Community"),
    (r"(?i)\binequali|seldom\s+heard|LGBT|inclusive", "Inequalities"),
    (r"(?i)\badvance\s+care\s+plan|ACP\b", "ACP"),
    (r"(?i)\bdementia|ageing|aging", "Dementia"),
    (r"(?i)\bprognosti", "Symptoms"),
    (r"(?i)\bcardiovascular|respiratory|digestive|oxygen\s+therapy", "Symptoms"),
    (r"(?i)\bsedation", "Ethics/Policy"),
    (r"(?i)\bopioid", "Pain"),
]


def auto_tag(title, description=""):
    """Auto-tag a session based on title and description."""
    text = f"{title} {description}"
    tags = set()
    for pattern, tag in TAG_RULES:
        if re.search(pattern, text):
            tags.add(tag)
    return sorted(tags)


def build_page_content(session):
    """Build Notion markdown content for a session page."""
    parts = []

    # Description
    if session.get("description"):
        parts.append(session["description"])
        parts.append("")

    # Presentations
    presentations = session.get("presentations", [])
    if presentations:
        parts.append(f"## Presentations ({len(presentations)})")
        parts.append("")
        for p in presentations:
            time_str = f"**{p['starts_at']}-{p['ends_at']}**" if p.get("starts_at") else ""
            presenter = f" — *{p['presenter']}*" if p.get("presenter") else ""

            # Build author list
            authors_strs = []
            for a in p.get("authors", []):
                org = f" ({a['organisation']})" if a.get("organisation") else ""
                flag = " [presenting]" if a.get("presenting") else ""
                authors_strs.append(f"{a['name']}{org}{flag}")

            parts.append(f"### {p['title']}")
            if time_str:
                parts.append(f"{time_str}{presenter}")
            if authors_strs:
                parts.append("")
                for a_str in authors_strs:
                    parts.append(f"- {a_str}")
            parts.append("")

    return "\n".join(parts)


def main():
    with open("data/eapc/programme_structured.json") as f:
        all_sessions = json.load(f)

    # Skip breaks, lunches, and poster exhibitions (too many presentations, not useful for programme building)
    skip_types = {"Break", "Lunch", "Tea"}
    skip_titles = {"Networking break", "Networking lunch", "Printed Poster exhibition"}

    pages = []
    skipped = 0

    for s in all_sessions:
        session_type = s["type"]

        # Skip breaks/lunches
        if session_type in skip_types:
            skipped += 1
            continue

        # Skip if title starts with any skip pattern
        if any(s["title"].startswith(prefix) for prefix in skip_titles):
            skipped += 1
            continue

        tags = auto_tag(s["title"], s.get("description", ""))

        # Build content
        content = build_page_content(s)

        page = {
            "properties": {
                "Session": s["title"],
                "Day": DAY_MAP.get(s["date"], s["date"]),
                "Time": f"{s['starts_at']}-{s['ends_at']}",
                "Type": session_type,
                "Venue": s["venue"],
                "Chairs": ", ".join(s.get("chairs", [])),
                "Presentations": s["presentations_count"],
                "Tags": json.dumps(tags) if tags else "[]",
            },
            "content": content,
        }

        pages.append(page)

    # Split into batches of 20 (to avoid overwhelming Notion)
    batch_size = 20
    batches = []
    for i in range(0, len(pages), batch_size):
        batches.append(pages[i:i + batch_size])

    for i, batch in enumerate(batches):
        with open(f"data/eapc/notion_batch_{i}.json", "w") as f:
            json.dump(batch, f, indent=2, ensure_ascii=False)

    print(f"Generated {len(pages)} pages ({skipped} skipped)")
    print(f"Split into {len(batches)} batches")
    for i, b in enumerate(batches):
        print(f"  Batch {i}: {len(b)} pages")


if __name__ == "__main__":
    main()
