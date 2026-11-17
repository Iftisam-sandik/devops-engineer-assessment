import express from 'express';
import pino from 'pino';
import { Counter, Histogram, Registry, collectDefaultMetrics } from 'prom-client';
import { readConfig } from './config.js';
import { timingSafeEqual } from 'node:crypto';

export function createApp({ config = readConfig(), logger, registerRoutes } = {}) {
  const log = logger ?? pino({ level: config.logLevel, base: { service: 'devops-app', environment: config.environment } });
  const app = express();
  const registry = new Registry();
  const state = { ready: true };
  registry.setDefaultLabels({ service: 'devops-app', environment: config.environment });
  collectDefaultMetrics({ register: registry });
  const labelNames = ['method', 'route', 'status_code'];
  const requests = new Counter({ name: 'http_requests_total', help: 'Completed HTTP requests', labelNames, registers: [registry] });
  const errors = new Counter({ name: 'http_errors_total', help: 'HTTP responses with status >= 400', labelNames, registers: [registry] });
  const latency = new Histogram({ name: 'http_request_duration_seconds', help: 'HTTP request duration in seconds', labelNames, buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5], registers: [registry] });
  app.disable('x-powered-by');
  app.use((req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const route = req.route?.path ?? 'unmatched';
      const method = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'].includes(req.method) ? req.method : 'OTHER';
      const labels = { method, route, status_code: String(res.statusCode) };
      const seconds = Number(process.hrtime.bigint() - start) / 1e9;
      requests.inc(labels);
      if (res.statusCode >= 400) errors.inc(labels);
      latency.observe(labels, seconds);
      log.info({ event: 'http_request', method, route, status_code: res.statusCode, duration_ms: seconds * 1000 }, 'request completed');
    });
    next();
  });
  app.get('/', (_req, res) => res.json({ message: 'Hello from DevOps Task!', status: 'running', version: config.version }));
  app.get('/health', (_req, res) => res.status(state.ready ? 200 : 503).json({ status: state.ready ? 'healthy' : 'draining' }));
  app.get('/metrics', async (req, res) => {
    if (config.metricsToken) {
      const expected = Buffer.from(`Bearer ${config.metricsToken}`);
      const actual = Buffer.from(req.get('authorization') ?? '');
      if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return res.status(401).json({ error: 'Unauthorized' });
    }
    res.type(registry.contentType).send(await registry.metrics());
  });
  // Dependency injection permits testing unexpected failures without exposing a failure endpoint.
  if (registerRoutes) registerRoutes(app);
  app.use((_req, res) => res.status(404).json({ error: 'Not found' }));
  app.use((error, _req, res, _next) => {
    log.error({ event: 'request_error', error: error.message }, 'request failed');
    res.status(500).json({ error: 'Internal server error' });
  });
  return { app, registry, state, logger: log };
}
