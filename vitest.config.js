import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      include: ['src/**/*.js'],
      reporter: ['text', 'json-summary', 'lcov'],
      thresholds: { lines: 90, functions: 90, statements: 90, branches: 85 },
    },
  },
});
