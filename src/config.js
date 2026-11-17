export function readConfig(env = process.env) {
  const port = Number(env.PORT ?? 8080);
  const shutdownTimeoutMs = Number(env.SHUTDOWN_TIMEOUT_MS ?? 10000);
  const logLevel = env.LOG_LEVEL ?? 'info';
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error('PORT must be an integer from 0 to 65535');
  if (!Number.isInteger(shutdownTimeoutMs) || shutdownTimeoutMs < 1) throw new Error('SHUTDOWN_TIMEOUT_MS must be positive');
  if (!['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'].includes(logLevel)) throw new Error('Invalid LOG_LEVEL');
  return {
    port,
    logLevel,
    environment: env.ENVIRONMENT ?? 'local',
    version: env.APP_VERSION ?? '1.0.0',
    shutdownTimeoutMs,
    metricsToken: env.METRICS_TOKEN ?? '',
  };
}
