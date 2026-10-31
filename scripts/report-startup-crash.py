#!/usr/bin/env python3
"""Publish bounded native-host crash evidence, without dumping simulator logs."""
from pathlib import Path
import json
import re
import sys


def report(message):
    escaped = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::notice title=Native startup evidence::{escaped[:12000]}')


for path in Path(sys.argv[1]).rglob('*'):
    if not path.is_file() or path.stat().st_size > 30_000_000:
        continue
    if path.suffix not in ('.ips', '.crash', '.log', '.txt'):
        continue
    data = path.read_text(errors='replace')
    if path.suffix in ('.ips', '.crash') and 'CranfordHistoricalAR' in data:
        if path.suffix == '.ips':
            try:
                payload = json.loads(data.split('\n', 1)[1])
                evidence = {key: payload.get(key) for key in ('exception', 'termination', 'asi', 'faultingThread')}
                threads = payload.get('threads', [])
                evidence['triggeredFrames'] = [t.get('frames', [])[:15] for t in threads if t.get('triggered')]
                report(path.name + ': ' + json.dumps(evidence))
                continue
            except (ValueError, IndexError):
                pass
        report(path.name + ': ' + data[:10000])
    else:
        lines = [line for line in data.splitlines() if re.search(
            r'Could not cast|abort\(\)|Terminating app|Library not loaded|Symbol not found|reason:|Fatal error:', line, re.I)]
        if lines:
            report(path.name + ': ' + '\n'.join(lines[-12:]))
