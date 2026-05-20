import { create } from 'zustand';

import { normalizeFlagText } from '@/constants/packs';
import {
  loadLocalFlagsFromStorage,
  saveLocalFlagsToStorage,
} from '@/lib/packs/local-flags-storage';

type LocalFlagsStatus = 'idle' | 'loading' | 'ready' | 'error';

interface LocalFlagsStore {
  status: LocalFlagsStatus;
  error: string | null;
  flags: string[];
  loadFlags: () => Promise<void>;
  addFlag: (flag: string) => Promise<void>;
  updateFlag: (index: number, flag: string) => Promise<void>;
  deleteFlag: (index: number) => Promise<void>;
}

function sanitizeInputFlag(value: string) {
  const cleaned = value.trim();
  if (!cleaned) {
    throw new Error('Flag text is required.');
  }

  return cleaned;
}

function hasDuplicateFlag(flags: string[], candidate: string, skipIndex: number | null = null) {
  const normalizedCandidate = normalizeFlagText(candidate);
  return flags.some((flag, index) => {
    if (skipIndex !== null && index === skipIndex) {
      return false;
    }

    return normalizeFlagText(flag) === normalizedCandidate;
  });
}

async function ensureFlagsLoaded(store: Pick<LocalFlagsStore, 'status' | 'loadFlags'>) {
  if (store.status === 'idle') {
    await store.loadFlags();
  }
}

export const useLocalFlagsStore = create<LocalFlagsStore>((set, get) => ({
  status: 'idle',
  error: null,
  flags: [],
  loadFlags: async () => {
    const status = get().status;
    if (status === 'loading') {
      return;
    }

    set({ status: 'loading', error: null });

    try {
      const flags = await loadLocalFlagsFromStorage();
      set({ flags, status: 'ready', error: null });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to load local flags.';
      set({ status: 'error', error: message });
    }
  },
  addFlag: async (flagInput) => {
    await ensureFlagsLoaded(get());

    const flag = sanitizeInputFlag(flagInput);
    const currentFlags = get().flags;

    if (hasDuplicateFlag(currentFlags, flag)) {
      throw new Error('Flag already exists.');
    }

    const nextFlags = [...currentFlags, flag];
    await saveLocalFlagsToStorage(nextFlags);
    set({ flags: nextFlags, status: 'ready', error: null });
  },
  updateFlag: async (index, flagInput) => {
    await ensureFlagsLoaded(get());

    const currentFlags = get().flags;
    if (index < 0 || index >= currentFlags.length) {
      throw new Error('Flag not found.');
    }

    const flag = sanitizeInputFlag(flagInput);

    if (hasDuplicateFlag(currentFlags, flag, index)) {
      throw new Error('Flag already exists.');
    }

    const nextFlags = currentFlags.map((existingFlag, flagIndex) => {
      if (flagIndex !== index) {
        return existingFlag;
      }

      return flag;
    });

    await saveLocalFlagsToStorage(nextFlags);
    set({ flags: nextFlags, status: 'ready', error: null });
  },
  deleteFlag: async (index) => {
    await ensureFlagsLoaded(get());

    const currentFlags = get().flags;
    if (index < 0 || index >= currentFlags.length) {
      throw new Error('Flag not found.');
    }

    const nextFlags = currentFlags.filter((_, flagIndex) => flagIndex !== index);
    await saveLocalFlagsToStorage(nextFlags);
    set({ flags: nextFlags, status: 'ready', error: null });
  },
}));
