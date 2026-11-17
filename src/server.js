import { pathToFileURL } from 'node:url';
import { createApp } from './app.js';
import { readConfig } from './config.js';

export function startServer(config = readConfig()) {
  const context = createApp({ config });
  const server = context.app.listen(config.port, '0.0.0.0', () => {
    context.logger.info({ event: 'server_started', port: server.address().port, version: config.version }, 'server listening');
  });
  let stopping = false;
  const shutdown = (signal) => {
    if (stopping) return;
    stopping = true;
    context.state.ready = false;
    context.logger.info({ event: 'shutdown_started', signal }, 'draining connections');
    const deadline = setTimeout(() => {
      context.logger.error({ event: 'shutdown_timeout' }, 'shutdown deadline exceeded');
      server.closeAllConnections();
      process.exitCode = 1;
    }, config.shutdownTimeoutMs);
    deadline.unref();
    server.close(() => {
      clearTimeout(deadline);
      context.logger.info({ event: 'shutdown_complete' }, 'server stopped');
    });
  };
  const onTerm = () => shutdown('SIGTERM');
  const onInt = () => shutdown('SIGINT');
  process.once('SIGTERM', onTerm);
  process.once('SIGINT', onInt);
  server.on('close', () => {
    process.removeListener('SIGTERM', onTerm);
    process.removeListener('SIGINT', onInt);
  });
  return { ...context, server, shutdown };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) startServer();
