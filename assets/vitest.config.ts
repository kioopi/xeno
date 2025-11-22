import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: ['./vitest.setup.ts'],
    include: ['js/**/*.{test,spec}.{js,ts}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'js/**/*.{test,spec}.{js,ts}',
      ],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './js'),
    },
  },
});
