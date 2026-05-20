import { initializeI18n } from '@/lib/i18n';
import { initializeDatabase } from '@/lib/storage/database';
import { useGameStore } from '@/stores/use-game-store';

export async function initializeApp() {
  await Promise.all([initializeI18n(), initializeDatabase()]);
  await useGameStore.getState().hydrateSessionFromStorage();
}
