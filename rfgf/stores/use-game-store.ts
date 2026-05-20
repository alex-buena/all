import { create } from 'zustand';

import { dedupeFlags, defaultSelectedPackIds } from '@/constants/packs';
import {
  ACTIVE_SESSION_PERSISTENCE_VERSION,
  clearActiveSessionFromStorage,
  loadActiveSessionFromStorage,
  saveActiveSessionToStorage,
} from '@/lib/game/active-session-storage';

type TurnPhase = 'awaiting_draw' | 'awaiting_decision';

interface PlayerState {
  id: string;
  name: string;
  currentFlags: string[];
  streak: number;
  longestStreak: number;
}

interface StreakEndedEvent {
  id: string;
  playerId: string;
  playerName: string;
  streak: number;
  turnNo: number;
  createdAt: number;
}

interface GameState {
  sessionId: string | null;
  status: 'idle' | 'active';
  sessionHydrationStatus: 'idle' | 'loading' | 'ready';
  players: PlayerState[];
  turnNo: number;
  activePlayerIndex: number;
  phase: TurnPhase;
  activeDrawnFlag: string | null;
  drawPile: string[];
  discardPile: string[];
  deckSourceFlags: string[];
  selectedPackIds: string[];
  streakEvents: StreakEndedEvent[];
  startSession: (playerNames: string[], selectedFlags: string[], packIds?: string[]) => void;
  drawFlag: () => void;
  keepDating: () => void;
  dumpPerson: () => void;
  resetSession: () => void;
  hydrateSessionFromStorage: () => Promise<void>;
}

function createId(prefix: string) {
  const random = Math.random().toString(36).slice(2, 10);
  return `${prefix}_${Date.now()}_${random}`;
}

function shuffle(items: string[]) {
  const array = [...items];

  for (let i = array.length - 1; i > 0; i -= 1) {
    const swapIndex = Math.floor(Math.random() * (i + 1));
    const current = array[i];
    array[i] = array[swapIndex];
    array[swapIndex] = current;
  }

  return array;
}

function normalizePlayers(playerNames: string[]) {
  return playerNames.map((name) => name.trim()).filter((name, index, values) => {
    return name.length > 0 && values.indexOf(name) === index;
  });
}

function normalizePackIds(packIds: string[] | undefined) {
  const cleaned = (packIds ?? []).map((packId) => packId.trim()).filter(Boolean);
  return cleaned.length > 0 ? cleaned : defaultSelectedPackIds;
}

function createIdleSessionState() {
  return {
    sessionId: null,
    status: 'idle' as const,
    players: [] as PlayerState[],
    turnNo: 1,
    activePlayerIndex: 0,
    phase: 'awaiting_draw' as const,
    activeDrawnFlag: null,
    drawPile: [] as string[],
    discardPile: [] as string[],
    deckSourceFlags: [] as string[],
    selectedPackIds: [...defaultSelectedPackIds],
    streakEvents: [] as StreakEndedEvent[],
  };
}

function persistActiveSessionSnapshot(state: GameState) {
  if (state.status !== 'active' || !state.sessionId || state.players.length === 0) {
    void clearActiveSessionFromStorage();
    return;
  }

  void saveActiveSessionToStorage({
    version: ACTIVE_SESSION_PERSISTENCE_VERSION,
    sessionId: state.sessionId,
    status: 'active',
    players: state.players,
    turnNo: state.turnNo,
    activePlayerIndex: state.activePlayerIndex,
    phase: state.phase,
    activeDrawnFlag: state.activeDrawnFlag,
    drawPile: state.drawPile,
    discardPile: state.discardPile,
    deckSourceFlags: state.deckSourceFlags,
    selectedPackIds: state.selectedPackIds,
    streakEvents: state.streakEvents,
  });
}

const idleSessionState = createIdleSessionState();

export const useGameStore = create<GameState>((set, get) => ({
  ...idleSessionState,
  sessionHydrationStatus: 'idle',
  startSession: (playerNames, selectedFlagsInput, packIds) => {
    const normalizedPlayers = normalizePlayers(playerNames);
    const selectedPackIds = normalizePackIds(packIds);
    const selectedFlags = dedupeFlags(selectedFlagsInput);

    if (normalizedPlayers.length < 2 || selectedFlags.length === 0) {
      return;
    }

    set({
      sessionId: createId('session'),
      status: 'active',
      players: normalizedPlayers.map((name) => ({
        id: createId('player'),
        name,
        currentFlags: [],
        streak: 0,
        longestStreak: 0,
      })),
      turnNo: 1,
      activePlayerIndex: 0,
      phase: 'awaiting_draw',
      activeDrawnFlag: null,
      drawPile: shuffle(selectedFlags),
      discardPile: [],
      deckSourceFlags: selectedFlags,
      selectedPackIds,
      streakEvents: [],
    });
    persistActiveSessionSnapshot(get());
  },
  drawFlag: () => {
    const state = get();

    if (state.status !== 'active' || state.phase !== 'awaiting_draw') {
      return;
    }

    let drawPile = [...state.drawPile];
    let discardPile = [...state.discardPile];

    if (drawPile.length === 0) {
      drawPile = shuffle(discardPile.length > 0 ? discardPile : state.deckSourceFlags);
      discardPile = [];
    }

    const [nextFlag, ...remainingDrawPile] = drawPile;
    if (!nextFlag) {
      return;
    }

    set({
      phase: 'awaiting_decision',
      activeDrawnFlag: nextFlag,
      drawPile: remainingDrawPile,
      discardPile,
    });
    persistActiveSessionSnapshot(get());
  },
  keepDating: () => {
    const state = get();

    if (state.status !== 'active' || state.phase !== 'awaiting_decision' || !state.activeDrawnFlag) {
      return;
    }

    const activePlayer = state.players[state.activePlayerIndex];
    if (!activePlayer) {
      return;
    }

    const updatedPlayers = state.players.map((player, index) => {
      if (index !== state.activePlayerIndex) {
        return player;
      }

      const nextStreak = player.streak + 1;
      return {
        ...player,
        currentFlags: [...player.currentFlags, state.activeDrawnFlag!],
        streak: nextStreak,
        longestStreak: Math.max(player.longestStreak, nextStreak),
      };
    });

    const nextPlayerIndex = (state.activePlayerIndex + 1) % state.players.length;

    set({
      players: updatedPlayers,
      activePlayerIndex: nextPlayerIndex,
      turnNo: state.turnNo + 1,
      phase: 'awaiting_draw',
      activeDrawnFlag: null,
      discardPile: [...state.discardPile, state.activeDrawnFlag],
    });
    persistActiveSessionSnapshot(get());
  },
  dumpPerson: () => {
    const state = get();

    if (state.status !== 'active' || state.phase !== 'awaiting_decision' || !state.activeDrawnFlag) {
      return;
    }

    const activePlayer = state.players[state.activePlayerIndex];
    if (!activePlayer) {
      return;
    }

    const streakEvents = [...state.streakEvents];
    if (activePlayer.streak > 0) {
      streakEvents.unshift({
        id: createId('streak'),
        playerId: activePlayer.id,
        playerName: activePlayer.name,
        streak: activePlayer.streak,
        turnNo: state.turnNo,
        createdAt: Date.now(),
      });
    }

    const updatedPlayers = state.players.map((player, index) => {
      if (index !== state.activePlayerIndex) {
        return player;
      }

      return {
        ...player,
        currentFlags: [],
        streak: 0,
      };
    });

    const nextPlayerIndex = (state.activePlayerIndex + 1) % state.players.length;

    set({
      players: updatedPlayers,
      activePlayerIndex: nextPlayerIndex,
      turnNo: state.turnNo + 1,
      phase: 'awaiting_draw',
      activeDrawnFlag: null,
      discardPile: [...state.discardPile, state.activeDrawnFlag],
      streakEvents,
    });
    persistActiveSessionSnapshot(get());
  },
  resetSession: () => {
    set({
      ...createIdleSessionState(),
    });
    persistActiveSessionSnapshot(get());
  },
  hydrateSessionFromStorage: async () => {
    const hydrationStatus = get().sessionHydrationStatus;
    if (hydrationStatus === 'loading' || hydrationStatus === 'ready') {
      return;
    }

    set({ sessionHydrationStatus: 'loading' });

    try {
      const persistedSession = await loadActiveSessionFromStorage();
      const currentState = get();

      if (persistedSession && currentState.status !== 'active') {
        set({
          sessionId: persistedSession.sessionId,
          status: 'active',
          players: persistedSession.players,
          turnNo: persistedSession.turnNo,
          activePlayerIndex: persistedSession.activePlayerIndex,
          phase: persistedSession.phase,
          activeDrawnFlag: persistedSession.activeDrawnFlag,
          drawPile: persistedSession.drawPile,
          discardPile: persistedSession.discardPile,
          deckSourceFlags: persistedSession.deckSourceFlags,
          selectedPackIds: persistedSession.selectedPackIds,
          streakEvents: persistedSession.streakEvents,
        });
      }
    } catch {
      // Ignore hydration failures and start from an idle in-memory session.
    } finally {
      set({ sessionHydrationStatus: 'ready' });
    }
  },
}));
