#!/usr/bin/env python3
"""Exercise the final deployment transaction with different real image identities."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--image', default='assessment:ci')
args = parser.parse_args()
suffix = str(os.getpid())
registry = 'assessment-registry-' + suffix
application = 'assessment-rollback-' + suffix
seed = 'assessment-fault-seed-' + suffix
repository = 'localhost:5010/assessment-' + suffix
good = repository + ':good'
bad = repository + ':bad'
out = Path('docs/evidence')
out.mkdir(parents=True, exist_ok=True)
output = []


def run(command, *, env=None, expected=0):
    result = subprocess.run(command, env=env, capture_output=True, text=True, check=False)
    output.append('$ ' + ' '.join(command) + '\n' + result.stdout + result.stderr)
    assert result.returncode == expected, (command, result.returncode, result.stdout, result.stderr)
    return result.stdout.strip()


def root():
    with urllib.request.urlopen('http://127.0.0.1:18083/', timeout=3) as response:
        return json.load(response)


summary = {'result': 'FAIL'}
try:
    run(['docker', 'run', '-d', '--name', registry, '-p', '127.0.0.1:5010:5000', 'registry:2.8.3'])
    for attempt in range(30):
        try:
            urllib.request.urlopen('http://127.0.0.1:5010/v2/', timeout=2).read()
            break
        except OSError:
            time.sleep(0.5)
    else:
        raise AssertionError('Local registry readiness timeout')
    run(['docker', 'tag', args.image, good])
    # A stopped fixture's changed CMD creates a distinct, genuinely broken image.
    run(['docker', 'create', '--name', seed, args.image, 'node', '-e', "require('node:http').createServer((q,s)=>s.end('wrong port')).listen(9999)"])
    run(['docker', 'commit', seed, bad])
    good_id = run(['docker', 'image', 'inspect', good, '--format', '{{.Id}}'])
    bad_id = run(['docker', 'image', 'inspect', bad, '--format', '{{.Id}}'])
    assert good_id != bad_id
    run(['docker', 'push', good])
    run(['docker', 'push', bad])
    with tempfile.TemporaryDirectory(prefix='deploy-integration-') as temporary:
        env_file = Path(temporary) / 'app.env'
        env_file.write_text('PORT=8080\nLOG_LEVEL=info\nAPP_VERSION=1.0.0\nENVIRONMENT=rollback-test\n')
        env_file.chmod(0o600)
        env = {**os.environ, 'APP_NAME': application, 'APP_ENV_FILE': str(env_file), 'DEPLOY_LOCK': str(Path(temporary) / 'deploy.lock'), 'APP_HOST_PORT': '18083', 'APP_LOG_DRIVER': 'json-file', 'HEALTH_ATTEMPTS': '3'}
        run(['bash', 'scripts/deploy.sh', good], env=env)
        assert root()['version'] == '1.0.0'
        failure = run(['bash', 'scripts/deploy.sh', bad], env=env, expected=1)
        assert 'ROLLBACK_SUCCEEDED' in failure
        assert root()['version'] == '1.0.0'
        restored_id = run(['docker', 'inspect', application, '--format', '{{.Image}}'])
        assert restored_id == good_id and restored_id != bad_id
        invalid = {**env, 'APP_ENV_FILE': str(Path(temporary) / 'missing.env')}
        run(['bash', 'scripts/deploy.sh', bad], env=invalid, expected=2)
        assert root()['version'] == '1.0.0'
        summary = {'result': 'PASS', 'initial_image_id': good_id, 'failed_candidate_image_id': bad_id, 'restored_image_id': restored_id, 'failed_deploy_exit': 1, 'invalid_config_exit': 2, 'restored_version': '1.0.0', 'scope': 'real local Docker registry/containers; not AWS'}
finally:
    subprocess.run(['docker', 'rm', '-f', application, application + '-previous', registry, seed], capture_output=True, check=False)
    subprocess.run(['docker', 'image', 'rm', good, bad], capture_output=True, check=False)
    (out / 'deployment-transaction.txt').write_text('\n'.join(output))
    (out / 'deployment-transaction.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
