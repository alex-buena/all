import { eq } from 'drizzle-orm';

import { defaultSelectedPackIds } from '@/constants/packs';
import { getDatabase } from '@/lib/storage/database';
import { appKv } from '@/lib/storage/schema';

const ACTIVE_SESSION_STORAGE_KEY = 'active_game_session_v1';
const ACTIVE_SESSION_STORAGE_VERSION = 1;

export type PersistedTurnPhase = 'awaiting_draw' | 'awaiting_decision';

export interface PersistedPlayerState {
  id: string;
  name: string;
  currentFlags: string[];
  streak: number;
  longestStreak: number;
}

export interface PersistedStreakEndedEvent {
  id: string;
  playerId: string;
  playerName: string;
  streak: number;
  turnNo: number;
  createdAt: number;
}

export interface PersistedActiveSession {
  version: number;
  sessionId: string;
  status: 'active';
  players: PersistedPlayerState[];
  turnNo: number;
  activePlayerIndex: number;
  phase: PersistedTurnPhase;
  activeDrawnFlag: string | null;
  drawPile: string[];
  discardPile: string[];
  deckSourceFlags: string[];
  selectedPackIds: string[];
  streakEvents: PersistedStreakEndedEvent[];
}

function dedupeStringArray(values: string[]) {
  const seen = new Set<string>();
  const deduped: string[] = [];

  for (const value of values) {
    if (!value || seen.has(value)) {
      continue;
    }

    seen.add(value);
    deduped.push(value);
  }

  return deduped;
}

function toStringArray(value: unknown) {
  if (!Array.isArray(value)) {
    return [] as string[];
  }

  return value.filter((entry): entry is string => typeof entry === 'string').map((entry) => entry.trim());
}

function toFiniteNonNegativeInteger(value: unknown, fallback: number) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return fallback;
  }

  const rounded = Math.floor(value);
  return rounded >= 0 ? rounded : fallback;
}

function sanitizePlayer(value: unknown): PersistedPlayerState | null {
  if (!value || typeof value !== 'object') {
    return null;
  }

  const typed = value as Record<string, unknown>;
  const id = typeof typed.id === 'string' ? typed.id.trim() : '';
  const name = typeof typed.name === 'string' ? typed.name.trim() : '';
  const currentFlags = toStringArray(typed.currentFlags).filter((flag) => flag.length > 0);
  const streak = toFiniteNonNegativeInteger(typed.streak, 0);
  const longestStreak = toFiniteNonNegativeInteger(typed.longestStreak, streak);

  if (!id || !name) {
    return null;
  }

  return {
    id,
    name,
    currentFlags,
    streak,
    longestStreak: Math.max(longestStreak, streak),
  };
}

function sanitizeStreakEvent(value: unknown): PersistedStreakEndedEvent | null {
  if (!value || typeof value !== 'object') {
    return null;
  }

  const typed = value as Record<string, unknown>;
  const id = typeof typed.id === 'string' ? typed.id.trim() : '';
  const playerId = typeof typed.playerId === 'string' ? typed.playerId.trim() : '';
  const playerName = typeof typed.playerName === 'string' ? typed.playerName.trim() : '';
  const streak = toFiniteNonNegativeInteger(typed.streak, 0);
  const turnNo = toFiniteNonNegativeInteger(typed.turnNo, 1);
  const createdAt = toFiniteNonNegativeInteger(typed.createdAt, Date.now());

  if (!id || !playerId || !playerName || streak <= 0) {
    return null;
  }

  return {
    id,
    playerId,
    playerName,
    streak,
    turnNo,
    createdAt,
  };
}

function sanitizePersistedActiveSession(value: unknown): PersistedActiveSession | null {
  if (!value || typeof value !== 'object') {
    return null;
  }

  const typed = value as Record<string, unknown>;
  const version = toFiniteNonNegativeInteger(typed.version, 0);
  const sessionId = typeof typed.sessionId === 'string' ? typed.sessionId.trim() : '';
  const status = typed.status === 'active' ? 'active' : null;
  const rawPhase =
    typed.phase === 'awaiting_draw' || typed.phase === 'awaiting_decision'
      ? typed.phase
      : 'awaiting_draw';
  const activeDrawnFlagRaw =
    typeof typed.activeDrawnFlag === 'string' ? typed.activeDrawnFlag.trim() : null;
  const activeDrawnFlag = activeDrawnFlagRaw && activeDrawnFlagRaw.length > 0 ? activeDrawnFlagRaw : null;
  const phase = rawPhase === 'awaiting_decision' && !activeDrawnFlag ? 'awaiting_draw' : rawPhase;
  const turnNo = Math.max(1, toFiniteNonNegativeInteger(typed.turnNo, 1));
  const drawPile = toStringArray(typed.drawPile).filter((flag) => flag.length > 0);
  const discardPile = toStringArray(typed.discardPile).filter((flag) => flag.length > 0);
  const deckSourceFlagsRaw = toStringArray(typed.deckSourceFlags).filter((flag) => flag.length > 0);
  const selectedPackIds = toStringArray(typed.selectedPackIds).filter((packId) => packId.length > 0);

  const players = Array.isArray(typed.players)
    ? typed.players
        .map((player) => sanitizePlayer(player))
        .filter((player): player is PersistedPlayerState => player !== null)
    : [];

  if (version !== ACTIVE_SESSION_STORAGE_VERSION || !sessionId || !status || players.length === 0) {
    return null;
  }

  const fallbackDeckFlags = dedupeStringArray([
    ...drawPile,
    ...discardPile,
    ...(activeDrawnFlag ? [activeDrawnFlag] : []),
  ]);
  const deckSourceFlags =
    deckSourceFlagsRaw.length > 0 ? dedupeStringArray(deckSourceFlagsRaw) : fallbackDeckFlags;

  if (deckSourceFlags.length === 0) {
    return null;
  }

  const activePlayerIndex = Math.min(
    players.length - 1,
    toFiniteNonNegativeInteger(typed.activePlayerIndex, 0)
  );

  const streakEvents = Array.isArray(typed.streakEvents)
    ? typed.streakEvents
        .map((event) => sanitizeStreakEvent(event))
        .filter((event): event is PersistedStreakEndedEvent => event !== null)
    : [];

  return {
    version,
    sessionId,
    status,
    players,
    turnNo,
    activePlayerIndex,
    phase,
    activeDrawnFlag,
    drawPile,
    discardPile,
    deckSourceFlags,
    selectedPackIds: selectedPackIds.length > 0 ? selectedPackIds : [...defaultSelectedPackIds],
    streakEvents,
  };
}

export async function loadActiveSessionFromStorage() {
  const database = getDatabase();
  const rows = await database
    .select({ value: appKv.value })
    .from(appKv)
    .where(eq(appKv.key, ACTIVE_SESSION_STORAGE_KEY))
    .limit(1);

  const serialized = rows[0]?.value;
  if (!serialized) {
    return null;
  }

  try {
    const parsed = JSON.parse(serialized);
    return sanitizePersistedActiveSession(parsed);
  } catch {
    return null;
  }
}

export async function saveActiveSessionToStorage(session: PersistedActiveSession) {
  const serialized = JSON.stringify(session);
  const database = getDatabase();

  await database
    .insert(appKv)
    .values({
      key: ACTIVE_SESSION_STORAGE_KEY,
      value: serialized,
    })
    .onConflictDoUpdate({
      target: appKv.key,
      set: {
        value: serialized,
      },
    });
}

export async function clearActiveSessionFromStorage() {
  const database = getDatabase();
  await database.delete(appKv).where(eq(appKv.key, ACTIVE_SESSION_STORAGE_KEY));
}

export const ACTIVE_SESSION_PERSISTENCE_VERSION = ACTIVE_SESSION_STORAGE_VERSION;
