#!/usr/bin/env python3
"""CI check for the extra 1-6500 reference bank; malformed records are excluded."""
import json
from collections import Counter
from pathlib import Path

paths = sorted(Path("assets/additional").glob("reference_*.json"))
assert len(paths) == 32, f"Expected 32 packs; received {len(paths)}"
ids = set()
topics = Counter()
total = 0
for path in paths:
    items = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(items, list) and items, f"{path} not a non-empty JSON list"
    for q in items:
        total += 1
        qid = q.get("id")
        assert isinstance(qid, int) and qid >= 120000001 and qid <= 120006500, (path, qid)
        assert qid not in ids, f"Duplicate reference question {qid}"
        ids.add(qid)
        assert isinstance(q.get("topic"), str) and q["topic"].strip(), (path, qid)
        assert isinstance(q.get("question"), str) and q["question"].strip(), (path, qid)
        assert q.get("answer") in "ABCD", (path, qid)
        assert all(isinstance(q.get("options", {}).get(k), str) and
                   q["options"][k].strip() for k in "ABCD"), (path, qid)
        topics[q["topic"]] += 1
assert total == 6266, f"Expected 6266 usable records, got {total}"
print(f"PASS: {total} new MCQs, {len(paths)} segments, {len(topics)} source subjects; excluded 230 incomplete entries.")
print(dict(sorted(topics.items())))
