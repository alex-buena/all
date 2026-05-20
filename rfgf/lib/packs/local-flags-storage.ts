import { eq } from 'drizzle-orm';

import { dedupeFlags } from '@/constants/packs';
import { getDatabase } from '@/lib/storage/database';
import { appKv } from '@/lib/storage/schema';

const LOCAL_FLAGS_STORAGE_KEY = 'local_flags_v1';

function sanitizeLocalFlags(value: unknown) {
  if (!Array.isArray(value)) {
    return [] as string[];
  }

  const typedFlags = value.filter((flag): flag is string => typeof flag === 'string');
  return dedupeFlags(typedFlags);
}

export async function loadLocalFlagsFromStorage() {
  const database = getDatabase();
  const rows = await database
    .select({ value: appKv.value })
    .from(appKv)
    .where(eq(appKv.key, LOCAL_FLAGS_STORAGE_KEY))
    .limit(1);

  const serialized = rows[0]?.value;
  if (!serialized) {
    return [] as string[];
  }

  try {
    const parsed = JSON.parse(serialized);
    return sanitizeLocalFlags(parsed);
  } catch {
    return [] as string[];
  }
}

export async function saveLocalFlagsToStorage(flags: string[]) {
  const normalizedFlags = dedupeFlags(flags);
  const serialized = JSON.stringify(normalizedFlags);
  const database = getDatabase();

  await database
    .insert(appKv)
    .values({
      key: LOCAL_FLAGS_STORAGE_KEY,
      value: serialized,
    })
    .onConflictDoUpdate({
      target: appKv.key,
      set: {
        value: serialized,
      },
    });
}
