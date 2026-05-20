import { create } from 'zustand';

import { initializeApp } from '@/lib/bootstrap/initialize-app';

type BootstrapStatus = 'idle' | 'loading' | 'ready' | 'error';

interface AppBootstrapStore {
  status: BootstrapStatus;
  error: string | null;
  bootstrap: () => Promise<void>;
}

export const useAppBootstrapStore = create<AppBootstrapStore>((set, get) => ({
  status: 'idle',
  error: null,
  bootstrap: async () => {
    const status = get().status;
    if (status === 'loading' || status === 'ready') {
      return;
    }

    set({ status: 'loading', error: null });

    try {
      await initializeApp();
      set({ status: 'ready', error: null });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown bootstrap error';
      set({ status: 'error', error: message });
    }
  },
}));
