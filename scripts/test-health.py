#!/usr/bin/env python3
"""Exercise actual host collection, JSON, exit codes and bounded rotation."""
import json
from pathlib import Path
import subprocess
import tempfile

results = []
with tempfile.TemporaryDirectory(prefix='health-test-') as temporary:
    root = Path(temporary)
    base = ['bash', 'system_health.sh', '--json', '--log', str(root / 'health_log.txt')]
    cases = [
        ('normal', ['--cpu', '100', '--mem', '100', '--disk', '100', '--critical', '100'], 0),
        ('warning', ['--cpu', '0', '--mem', '0', '--disk', '0', '--critical', '100'], 1),
        ('critical', ['--cpu', '0', '--mem', '0', '--disk', '0', '--critical', '0'], 2),
        ('invalid', ['--cpu', '101'], 2),
        ('help', ['--help'], 0),
    ]
    for name, flags, expected in cases:
        result = subprocess.run(base + flags, capture_output=True, text=True, check=False)
        data = json.loads(result.stdout) if name not in ['invalid', 'help'] else None
        assert result.returncode == expected, (name, result.returncode, result.stderr)
        if data:
            assert len(data['disks']) > 0 and len(data['top_processes']) == 5
            assert isinstance(data['cpu_percent'], (int, float)) and 0 <= data['cpu_percent'] <= 100
            assert data['status'] == expected
        if name in ['warning', 'critical']:
            assert '[WARNING]' in result.stderr
        results.append({'case': name, 'expected_exit': expected, 'actual_exit': result.returncode, 'json_valid': data is not None, 'disk_entries': len(data['disks']) if data else None})
    for _ in range(5):
        subprocess.run(base + ['--max-log-bytes', '1', '--keep', '2'] + cases[0][1], capture_output=True, text=True, check=True)
    assert (root / 'health_log.txt.1').exists() and (root / 'health_log.txt.2').exists()
    assert not (root / 'health_log.txt.3').exists()
    results.append({'case': 'rotation', 'backups': 2, 'result': 'PASS'})
    human = subprocess.run(['bash', 'system_health.sh', '--log', str(root / 'human.txt')] + cases[0][1], capture_output=True, text=True, check=True)
    assert 'CPU=' in human.stdout and 'Top 5 processes:' in human.stdout
    assert human.stdout == (root / 'human.txt').read_text()
    results.append({'case': 'timestamped_human_log', 'result': 'PASS'})
out = Path('docs/evidence')
out.mkdir(parents=True, exist_ok=True)
(out / 'health-script-tests.json').write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results, indent=2))
