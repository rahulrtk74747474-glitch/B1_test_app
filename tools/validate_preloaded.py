#!/usr/bin/env python3
"""Validate every shipped MCQ and catch truncated/overlapping bank parts."""
import json
from collections import Counter
from pathlib import Path

files = sorted(Path('assets/preloaded').glob('bank_*.json'))
assert len(files) == 61, f'Expected 61 bank parts, got {len(files)}'
ids = set()
topics = Counter()
errors = []
total = 0
for file in files:
    try:
        items = json.loads(file.read_text(encoding='utf-8'))
    except Exception as exc:
        raise AssertionError(f'{file}: invalid JSON: {exc}') from exc
    assert isinstance(items, list), f'{file}: expected list'
    for item in items:
        total += 1
        qid = item.get('id')
        options = item.get('options')
        topic = item.get('topic')
        answer = item.get('answer')
        if not isinstance(qid, int) or qid in ids:
            errors.append(f'{file}: bad/duplicate ID {qid}')
        ids.add(qid)
        if not isinstance(topic, str) or not topic.strip():
            errors.append(f'{file}: bad subject ID {qid}')
        else:
            topics[topic] += 1
        if not isinstance(item.get('question'), str) or not item['question'].strip():
            errors.append(f'{file}: empty question ID {qid}')
        if not isinstance(options, dict) or any(not isinstance(options.get(k), str) or not options[k].strip() for k in 'ABCD'):
            errors.append(f'{file}: invalid options ID {qid}')
        if answer not in ('A', 'B', 'C', 'D'):
            errors.append(f'{file}: invalid correct key ID {qid}')
    print(f'{file}: {len(items)} MCQs')
print(f'Bundled questions: {total}; subjects: {len(topics)}')
print('By subject:', dict(sorted(topics.items())))
assert not errors, '\n'.join(errors[:20])
assert total == 12488, f'Expected 12,488 MCQs, got {total}'
assert len(topics) == 21, f'Expected 21 subjects, got {len(topics)}'
print('PASS: complete MCQ bank with valid keys and unique IDs')
