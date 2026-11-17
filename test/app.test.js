import { describe, it, expect, afterEach, vi } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { readConfig } from '../src/config.js';
import { startServer } from '../src/server.js';
import net from 'node:net';

const contexts = [];
function setup(options = {}) {
  const context = createApp({ config: readConfig({ LOG_LEVEL: 'silent', APP_VERSION: '2.3.4' }), ...options });
  contexts.push(context);
  return context;
}
afterEach(() => { for (const context of contexts.splice(0)) context.registry.clear(); });

describe('HTTP contract and instrumentation', () => {
  it('returns the exact required root response and version', async () => {
    const { app } = setup();
    const response = await request(app).get('/').expect(200).expect('Content-Type', /json/);
    expect(response.body).toEqual({ message: 'Hello from DevOps Task!', status: 'running', version: '2.3.4' });
    expect(response.headers['x-powered-by']).toBeUndefined();
  });
  it('reports healthy and draining states', async () => {
    const { app, state } = setup();
    expect((await request(app).get('/health').expect(200)).body).toEqual({ status: 'healthy' });
    state.ready = false;
    expect((await request(app).get('/health').expect(503)).body).toEqual({ status: 'draining' });
  });
  it('counts requests/errors and records histogram buckets in Prometheus format', async () => {
    const { app } = setup();
    await request(app).get('/');
    await request(app).get('/unknown-123').expect(404);
    const { text } = await request(app).get('/metrics').expect(200).expect('Content-Type', /text\/plain/);
    expect(text).toMatch(/http_requests_total\{[^\n]*route="\/"[^\n]*status_code="200"[^\n]*\} 1/);
    expect(text).toMatch(/http_errors_total\{[^\n]*route="unmatched"[^\n]*status_code="404"[^\n]*\} 1/);
    expect(text).toContain('http_request_duration_seconds_bucket');
    expect(text).toContain('process_resident_memory_bytes');
    expect(text).not.toContain('unknown-123');
  });
  it('handles exceptions without leaking error details', async () => {
    const logger = { info: vi.fn(), error: vi.fn() };
    const { app } = setup({ logger, registerRoutes: (app) => app.get('/fault', () => { throw new Error('private detail'); }) });
    expect((await request(app).get('/fault').expect(500)).body).toEqual({ error: 'Internal server error' });
    expect(logger.error).toHaveBeenCalled();
    const { text } = await request(app).get('/metrics');
    expect(text).toContain('status_code="500"} 1');
  });
  it('writes structured bounded route logs without arbitrary paths or credentials', async () => {
    const logger = { info: vi.fn(), error: vi.fn() };
    const { app } = setup({ logger });
    await request(app).get('/secret/customer-id?token=secret').set('Authorization', 'Bearer private');
    expect(logger.info.mock.calls[0][0]).toMatchObject({ event: 'http_request', route: 'unmatched', status_code: 404 });
    expect(JSON.stringify(logger.info.mock.calls)).not.toMatch(/customer-id|Bearer|token=secret/);
  });
  it('protects metrics when a secret token is configured', async () => {
    const { app } = setup({ config: readConfig({ LOG_LEVEL: 'silent', METRICS_TOKEN: 'test-only-secret' }) });
    await request(app).get('/metrics').expect(401);
    await request(app).get('/metrics').set('Authorization', 'Bearer wrong').expect(401);
    await request(app).get('/metrics').set('Authorization', 'Bearer test-only-secrex').expect(401);
    await request(app).get('/metrics').set('Authorization', 'Bearer test-only-secret').expect(200);
  });
});

describe('configuration', () => {
  it('supplies defaults and reads environment variables', () => {
    expect(readConfig({})).toEqual({ port: 8080, logLevel: 'info', environment: 'local', version: '1.0.0', shutdownTimeoutMs: 10000, metricsToken: '' });
    expect(readConfig({ PORT: '9000', LOG_LEVEL: 'debug', ENVIRONMENT: 'staging', APP_VERSION: '3.0.0', SHUTDOWN_TIMEOUT_MS: '500' })).toEqual({ port: 9000, logLevel: 'debug', environment: 'staging', version: '3.0.0', shutdownTimeoutMs: 500, metricsToken: '' });
  });
  it.each(['bad', '-1', '65536', '0.5'])('rejects invalid port %s', (PORT) => expect(() => readConfig({ PORT })).toThrow('PORT'));
  it.each(['0', '-1', 'invalid'])('rejects invalid timeout %s', (SHUTDOWN_TIMEOUT_MS) => expect(() => readConfig({ SHUTDOWN_TIMEOUT_MS })).toThrow('SHUTDOWN_TIMEOUT_MS'));
  it('rejects invalid log levels', () => expect(() => readConfig({ LOG_LEVEL: 'verbose' })).toThrow('LOG_LEVEL'));
});

describe('server lifecycle', () => {
  it('listens and gracefully drains once', async () => {
    const context = startServer(readConfig({ PORT: '0', LOG_LEVEL: 'silent' }));
    await new Promise((resolve) => context.server.once('listening', resolve));
    await request(context.server).get('/health').expect(200);
    const closed = new Promise((resolve) => context.server.once('close', resolve));
    context.shutdown('SIGTERM');
    context.shutdown('SIGTERM');
    await closed;
    expect(context.state.ready).toBe(false);
    context.registry.clear();
  });
  it.each(['SIGTERM', 'SIGINT'])('handles %s and unregisters handlers', async (signal) => {
    const context = startServer(readConfig({ PORT: '0', LOG_LEVEL: 'silent' }));
    await new Promise((resolve) => context.server.once('listening', resolve));
    const handler = process.listeners(signal).find((fn) => fn.name === (signal === 'SIGTERM' ? 'onTerm' : 'onInt'));
    const closed = new Promise((resolve) => context.server.once('close', resolve));
    handler();
    await closed;
    expect(process.listeners(signal)).not.toContain(handler);
    context.registry.clear();
  });
  it('forcibly closes unfinished connections after the shutdown deadline', async () => {
    const context = startServer(readConfig({ PORT: '0', LOG_LEVEL: 'silent', SHUTDOWN_TIMEOUT_MS: '30' }));
    await new Promise((resolve) => context.server.once('listening', resolve));
    const socket = net.connect(context.server.address().port, '127.0.0.1');
    await new Promise((resolve) => socket.once('connect', resolve));
    socket.write('GET / HTTP/1.1\r\nHost: localhost\r\n');
    const oldCode = process.exitCode;
    const closed = new Promise((resolve) => context.server.once('close', resolve));
    context.shutdown('SIGTERM');
    await closed;
    expect(process.exitCode).toBe(1);
    process.exitCode = oldCode;
    socket.destroy();
    context.registry.clear();
  });
});
