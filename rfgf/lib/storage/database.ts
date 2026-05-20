import type { ExpoSQLiteDatabase } from 'drizzle-orm/expo-sqlite';
import { drizzle } from 'drizzle-orm/expo-sqlite';
import migrations from '@/drizzle/migrations';
import { migrate } from 'drizzle-orm/expo-sqlite/migrator';
import * as SQLite from 'expo-sqlite';

import * as schema from '@/lib/storage/schema';

const DATABASE_NAME = 'rfgf.db';

type AppDatabase = ExpoSQLiteDatabase<typeof schema> & { $client: SQLite.SQLiteDatabase };

let sqliteClient: SQLite.SQLiteDatabase | null = null;
let drizzleClient: AppDatabase | null = null;

export function getSQLiteClient() {
  if (!sqliteClient) {
    sqliteClient = SQLite.openDatabaseSync(DATABASE_NAME);
  }

  return sqliteClient;
}

export function getDatabase() {
  if (!drizzleClient) {
    drizzleClient = drizzle(getSQLiteClient(), { schema });
  }

  return drizzleClient;
}

export async function initializeDatabase() {
  const database = getDatabase();
  database.$client.execSync('PRAGMA foreign_keys = ON;');
  await migrate(database, migrations);
}
