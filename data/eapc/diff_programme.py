#!/usr/bin/env python3
"""Diff two extractions of the EAPC programme to spot programme changes."""

import json
import sys
from pathlib import Path


def load_sessions(path):
    with open(path) as f:
        return {s["id"]: s for s in json.load(f)["data"]}


def diff_day(old_path, new_path, label):
    old = load_sessions(old_path)
    new = load_sessions(new_path)

    old_ids = set(old.keys())
    new_ids = set(new.keys())

    added = new_ids - old_ids
    removed = old_ids - new_ids
    common = old_ids & new_ids

    print(f"\n=== {label} ===")
    print(f"  Sessions: {len(old)} → {len(new)} ({'+' if len(new) > len(old) else ''}{len(new) - len(old)})")

    if added:
        print(f"\n  ADDED ({len(added)}):")
        for sid in sorted(added):
            s = new[sid]
            print(f"    + [{sid}] {s['title']} ({s.get('starts_at', '')})")

    if removed:
        print(f"\n  REMOVED ({len(removed)}):")
        for sid in sorted(removed):
            s = old[sid]
            print(f"    - [{sid}] {s['title']} ({s.get('starts_at', '')})")

    # Check changes within common sessions
    title_changes = []
    venue_changes = []
    time_changes = []
    type_changes = []
    pres_count_changes = []
    pres_title_changes = []

    for sid in common:
        o = old[sid]
        n = new[sid]

        if o.get("title") != n.get("title"):
            title_changes.append((sid, o["title"], n["title"]))
        if o.get("schedule_venue_id") != n.get("schedule_venue_id"):
            venue_changes.append((sid, o["title"], o.get("schedule_venue_id"), n.get("schedule_venue_id")))
        if o.get("starts_at") != n.get("starts_at") or o.get("ends_at") != n.get("ends_at"):
            time_changes.append((sid, o["title"], f"{o.get('starts_at')}-{o.get('ends_at')}", f"{n.get('starts_at')}-{n.get('ends_at')}"))
        if o.get("type") != n.get("type"):
            type_changes.append((sid, o["title"], o.get("type"), n.get("type")))

        old_pres = {p["id"]: p for p in o.get("schedule_event_presentations", [])}
        new_pres = {p["id"]: p for p in n.get("schedule_event_presentations", [])}

        if len(old_pres) != len(new_pres):
            pres_count_changes.append((sid, o["title"], len(old_pres), len(new_pres)))

        # Check presentation titles for common presentations
        for pid in old_pres.keys() & new_pres.keys():
            op = old_pres[pid].get("paper", {})
            np = new_pres[pid].get("paper", {})
            if op and np and op.get("title") != np.get("title"):
                pres_title_changes.append((sid, pid, op.get("title"), np.get("title")))

    if title_changes:
        print(f"\n  TITLE CHANGES ({len(title_changes)}):")
        for sid, old_t, new_t in title_changes:
            print(f"    [{sid}] {old_t}")
            print(f"      → {new_t}")

    if venue_changes:
        print(f"\n  VENUE CHANGES ({len(venue_changes)}):")
        for sid, title, old_v, new_v in venue_changes:
            print(f"    [{sid}] {title[:60]}: venue_id {old_v} → {new_v}")

    if time_changes:
        print(f"\n  TIME CHANGES ({len(time_changes)}):")
        for sid, title, old_t, new_t in time_changes:
            print(f"    [{sid}] {title[:60]}: {old_t} → {new_t}")

    if type_changes:
        print(f"\n  TYPE CHANGES ({len(type_changes)}):")
        for sid, title, old_ty, new_ty in type_changes:
            print(f"    [{sid}] {title[:60]}: {old_ty} → {new_ty}")

    if pres_count_changes:
        print(f"\n  PRESENTATION COUNT CHANGES ({len(pres_count_changes)}):")
        for sid, title, old_c, new_c in pres_count_changes:
            print(f"    [{sid}] {title[:60]}: {old_c} → {new_c}")

    if pres_title_changes:
        print(f"\n  PRESENTATION TITLE CHANGES ({len(pres_title_changes)}):")
        for sid, pid, old_t, new_t in pres_title_changes[:20]:  # cap output
            print(f"    [s{sid}/p{pid}] {old_t[:70]}")
            print(f"      → {new_t[:70]}")
        if len(pres_title_changes) > 20:
            print(f"    ... and {len(pres_title_changes) - 20} more")

    return {
        "added": len(added),
        "removed": len(removed),
        "title_changes": len(title_changes),
        "venue_changes": len(venue_changes),
        "time_changes": len(time_changes),
        "pres_count_changes": len(pres_count_changes),
        "pres_title_changes": len(pres_title_changes),
    }


def main():
    if len(sys.argv) > 1:
        refresh_dir = sys.argv[1]
    else:
        # Find most recent refresh dir
        refresh_dirs = sorted(Path("data/eapc").glob("refresh-*"))
        if not refresh_dirs:
            print("No refresh directory found")
            sys.exit(1)
        refresh_dir = str(refresh_dirs[-1])

    print(f"Comparing data/eapc/day_*.json (original) vs {refresh_dir}/day_*.json (refresh)\n")

    totals = {"added": 0, "removed": 0, "title_changes": 0, "venue_changes": 0, "time_changes": 0, "pres_count_changes": 0, "pres_title_changes": 0}

    for date in ["2026-05-14", "2026-05-15", "2026-05-16"]:
        old_path = f"data/eapc/day_{date}.json"
        new_path = f"{refresh_dir}/day_{date}.json"
        result = diff_day(old_path, new_path, date)
        for k, v in result.items():
            totals[k] += v

    print(f"\n=== TOTALS ===")
    for k, v in totals.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
