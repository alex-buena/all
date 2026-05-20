import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './lib/storage/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  driver: 'expo',
});
