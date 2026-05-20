import { eq } from 'drizzle-orm';

import { defaultSelectedPackIds } from '@/constants/packs';
import { getDatabase } from '@/lib/storage/database';
import { appKv } from '@/lib/storage/schema';

const SETUP_PREFERENCES_STORAGE_KEY = 'setup_preferences_v1';

export interface SetupPreferences {
  playerNames: string[];
  selectedPackIds: string[];
}

const EMPTY_SETUP_PREFERENCES: SetupPreferences = {
  playerNames: [],
  selectedPackIds: [],
};

function normalizePlayerNames(playerNames: unknown) {
  if (!Array.isArray(playerNames)) {
    return [] as string[];
  }

  return playerNames
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
}

function normalizePackIds(selectedPackIds: unknown) {
  if (!Array.isArray(selectedPackIds)) {
    return [...defaultSelectedPackIds];
  }

  const cleaned = selectedPackIds
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  return cleaned.length > 0 ? Array.from(new Set(cleaned)) : [...defaultSelectedPackIds];
}

function normalizeSetupPreferences(value: unknown): SetupPreferences {
  if (!value || typeof value !== 'object') {
    return { ...EMPTY_SETUP_PREFERENCES };
  }

  const typed = value as Record<string, unknown>;
  return {
    playerNames: normalizePlayerNames(typed.playerNames),
    selectedPackIds: normalizePackIds(typed.selectedPackIds),
  };
}

export async function loadSetupPreferences() {
  const database = getDatabase();
  const rows = await database
    .select({ value: appKv.value })
    .from(appKv)
    .where(eq(appKv.key, SETUP_PREFERENCES_STORAGE_KEY))
    .limit(1);

  const serialized = rows[0]?.value;
  if (!serialized) {
    return { ...EMPTY_SETUP_PREFERENCES };
  }

  try {
    const parsed = JSON.parse(serialized);
    return normalizeSetupPreferences(parsed);
  } catch {
    return { ...EMPTY_SETUP_PREFERENCES };
  }
}

export async function saveSetupPreferences(preferences: SetupPreferences) {
  const normalizedPreferences = normalizeSetupPreferences(preferences);
  const serialized = JSON.stringify(normalizedPreferences);
  const database = getDatabase();

  await database
    .insert(appKv)
    .values({
      key: SETUP_PREFERENCES_STORAGE_KEY,
      value: serialized,
    })
    .onConflictDoUpdate({
      target: appKv.key,
      set: {
        value: serialized,
      },
    });
}
