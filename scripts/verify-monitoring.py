#!/usr/bin/env python3
"""Validate the live stack through Grafana's authenticated data-source proxy."""
import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--screenshots', action='store_true')
parser.add_argument('--test-app-down', action='store_true')
parser.add_argument('--allow-missing-container-metrics', action='store_true')
args = parser.parse_args()
if Path('.env').exists():
    for line in Path('.env').read_text().splitlines():
        if line and not line.startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            os.environ.setdefault(key, value)
base = os.environ.get('GRAFANA_URL', 'http://127.0.0.1:3000')
user = os.environ.get('GRAFANA_ADMIN_USER', 'admin')
password = os.environ['GRAFANA_ADMIN_PASSWORD']
auth = base64.b64encode(f'{user}:{password}'.encode()).decode()
out = Path(os.environ.get('EVIDENCE_DIR', 'docs/evidence'))
out.mkdir(parents=True, exist_ok=True)
summary = {'timestamp_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'checks': {}}


def get(path):
    req = urllib.request.Request(base + path, headers={'Authorization': 'Basic ' + auth})
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.load(response)


def wait_for(fn, seconds=180):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        try:
            last = fn()
            if last:
                return last
        except (urllib.error.URLError, OSError, ValueError) as error:
            last = str(error)
        time.sleep(5)
    raise RuntimeError(f'Acceptance check timed out: {last}')


def prom(query):
    result = get('/api/datasources/proxy/uid/prometheus/api/v1/query?' + urllib.parse.urlencode({'query': query}))
    if result.get('status') != 'success':
        raise RuntimeError(result)
    return result['data']['result']


try:
    wait_for(lambda: get('/api/health').get('database') == 'ok')
    dashboards = wait_for(lambda: [d for d in get('/api/search?type=dash-db') if d['uid'] in {'application', 'host', 'containers'}])
    assert len(dashboards) == 3, dashboards
    summary['checks']['provisioned_dashboards'] = [d['uid'] for d in dashboards]
    up = wait_for(lambda: prom('up') if len(prom('up')) >= 4 and all(float(x['value'][1]) == 1 for x in prom('up')) else None)
    summary['checks']['scrape_targets'] = up
    # Real traffic creates non-empty rate/histogram series and corresponding JSON logs.
    for _ in range(40):
        for path in ['/', '/unknown-example']:
            try:
                urllib.request.urlopen('http://127.0.0.1:8080' + path, timeout=3).read()
            except urllib.error.HTTPError as error:
                assert error.code == 404
        time.sleep(0.25)
    wait_for(lambda: prom('sum(http_requests_total{job="app"})'))
    summary['checks']['application_requests'] = prom('sum(http_requests_total{job="app"})')
    summary['checks']['application_errors'] = prom('sum(http_errors_total{job="app"})')
    summary['checks']['latency_buckets'] = prom('count(http_request_duration_seconds_bucket{job="app"})')
    for metric in ['node_cpu_seconds_total', 'node_memory_MemAvailable_bytes', 'node_filesystem_size_bytes', 'node_network_receive_bytes_total']:
        result = prom('count(' + metric + ')')
        assert result and float(result[0]['value'][1]) > 0, metric
        summary['checks'][metric] = result
    container_query = 'container_memory_working_set_bytes{container_label_com_docker_compose_service!=""}'
    containers = prom(container_query)
    limits = prom('container_spec_memory_limit_bytes{container_label_com_docker_compose_service!=""} > 0')
    summary['checks']['container_working_sets'] = containers
    summary['checks']['container_limits'] = limits
    if not containers or not limits:
        summary['checks']['container_metrics_status'] = 'BLOCKED: runtime exposes no per-container cgroups/limits'
        if not args.allow_missing_container_metrics:
            raise AssertionError('Missing cAdvisor container/limit metrics')
    else:
        summary['checks']['container_metrics_status'] = 'PASS'
    log_path = '/api/datasources/proxy/uid/loki/loki/api/v1/query_range?' + urllib.parse.urlencode({'query': '{service="app"} | json', 'limit': 20})
    logs = wait_for(lambda: get(log_path)['data']['result'])
    assert any('http_request' in value[1] for stream in logs for value in stream['values'])
    (out / 'loki-query.json').write_text(json.dumps(logs, indent=2) + '\n')
    summary['checks']['loki_stream_count'] = len(logs)
    rules = get('/api/datasources/proxy/uid/prometheus/api/v1/rules')['data']['groups']
    names = {rule['name'] for group in rules for rule in group['rules']}
    assert {'AppDown', 'HighAppErrorRate', 'HostDiskAlmostFull', 'ContainerMemoryNearLimit'} <= names
    summary['checks']['loaded_alert_rules'] = sorted(names)
    if args.test_app_down:
        compose = ['docker', 'compose', '-f', 'docker-compose.yml', '-f', 'docker-compose.monitoring.yml']
        try:
            subprocess.run(compose + ['stop', 'app'], check=True)
            firing = wait_for(lambda: prom('ALERTS{alertname="AppDown",alertstate="firing"}'), seconds=120)
            summary['checks']['actual_app_down_firing'] = firing
        finally:
            subprocess.run(compose + ['up', '-d', '--no-build', 'app'], check=True)
        wait_for(lambda: all(float(x['value'][1]) == 1 for x in prom('up{job="app"}')) and prom('up{job="app"}'))
        wait_for(lambda: not prom('ALERTS{alertname="AppDown"}'))
        summary['checks']['actual_app_down_recovery'] = 'PASS'
    if args.screenshots:
        from playwright.sync_api import sync_playwright
        screenshots = Path('docs/screenshots')
        screenshots.mkdir(parents=True, exist_ok=True)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('google-chrome'), args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 1600, 'height': 1100}, device_scale_factor=1)
            login = context.request.post(base + '/login', data={'user': user, 'password': password})
            assert login.ok, 'Grafana login failed'
            page = context.new_page()
            for uid in ['application', 'host', 'containers']:
                page.goto(base + '/d/' + uid + '/' + uid + '?kiosk&from=now-15m&to=now', wait_until='networkidle')
                page.wait_for_timeout(12000)
                page.screenshot(path=str(screenshots / (uid + '.png')), full_page=True)
            browser.close()
        summary['checks']['screenshots'] = ['application.png', 'host.png', 'containers.png']
    summary['result'] = 'PASS' if summary['checks']['container_metrics_status'] == 'PASS' else 'PARTIAL: container metrics BLOCKED'
except Exception as error:
    summary['result'] = 'FAIL'
    summary['error'] = str(error)
    raise
finally:
    (out / 'monitoring-verification.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
