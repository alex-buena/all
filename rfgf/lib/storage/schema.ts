import { sql } from 'drizzle-orm';
import { index, integer, sqliteTable, text, uniqueIndex } from 'drizzle-orm/sqlite-core';

export const sessionStatuses = ['active', 'ended'] as const;
export const profileStatuses = ['active', 'dumped'] as const;
export const flagSourceTypes = ['base', 'custom', 'shared'] as const;
export const decisionTypes = ['keep', 'dump'] as const;
export const eventTypes = [
  'session_started',
  'turn_started',
  'flag_drawn',
  'decision_keep',
  'decision_dump',
  'profile_reset',
  'session_ended',
] as const;

export const appKv = sqliteTable('app_kv', {
  key: text('key').primaryKey().notNull(),
  value: text('value').notNull(),
});

export const sessions = sqliteTable(
  'sessions',
  {
    id: text('id').primaryKey().notNull(),
    status: text('status', { enum: sessionStatuses }).notNull().default('active'),
    turnNo: integer('turn_no').notNull().default(1),
    activePlayerIndex: integer('active_player_index').notNull().default(0),
    startedAt: integer('started_at').notNull(),
    endedAt: integer('ended_at'),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [index('idx_sessions_status').on(table.status)]
);

export const sessionPlayers = sqliteTable(
  'session_players',
  {
    id: text('id').primaryKey().notNull(),
    sessionId: text('session_id')
      .notNull()
      .references(() => sessions.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    seatIndex: integer('seat_index').notNull(),
    currentProfileId: text('current_profile_id'),
    currentStreak: integer('current_streak').notNull().default(0),
    longestStreak: integer('longest_streak').notNull().default(0),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [
    uniqueIndex('ux_session_players_session_seat').on(table.sessionId, table.seatIndex),
    index('idx_session_players_session').on(table.sessionId),
    index('idx_session_players_current_profile').on(table.currentProfileId),
  ]
);

export const profiles = sqliteTable(
  'profiles',
  {
    id: text('id').primaryKey().notNull(),
    sessionId: text('session_id')
      .notNull()
      .references(() => sessions.id, { onDelete: 'cascade' }),
    playerId: text('player_id')
      .notNull()
      .references(() => sessionPlayers.id, { onDelete: 'cascade' }),
    status: text('status', { enum: profileStatuses }).notNull().default('active'),
    startedTurnNo: integer('started_turn_no').notNull(),
    endedTurnNo: integer('ended_turn_no'),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [
    index('idx_profiles_session_player').on(table.sessionId, table.playerId),
    uniqueIndex('ux_profiles_one_active_per_player')
      .on(table.playerId)
      .where(sql`${table.status} = 'active'`),
  ]
);

export const flagLibraryItems = sqliteTable(
  'flag_library_items',
  {
    id: text('id').primaryKey().notNull(),
    text: text('text').notNull(),
    normalizedText: text('normalized_text').notNull(),
    sourceType: text('source_type', { enum: flagSourceTypes }).notNull(),
    isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
    createdByPlayerId: text('created_by_player_id'),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [
    uniqueIndex('ux_flag_library_normalized_text').on(table.normalizedText),
    index('idx_flag_library_active').on(table.isActive, table.sourceType),
  ]
);

export const flagStats = sqliteTable('flag_stats', {
  flagId: text('flag_id')
    .primaryKey()
    .notNull()
    .references(() => flagLibraryItems.id, { onDelete: 'cascade' }),
  drawCount: integer('draw_count').notNull().default(0),
  keepCount: integer('keep_count').notNull().default(0),
  dumpCount: integer('dump_count').notNull().default(0),
  lastSeenAt: integer('last_seen_at'),
});

export const profileFlags = sqliteTable(
  'profile_flags',
  {
    id: text('id').primaryKey().notNull(),
    sessionId: text('session_id')
      .notNull()
      .references(() => sessions.id, { onDelete: 'cascade' }),
    playerId: text('player_id')
      .notNull()
      .references(() => sessionPlayers.id, { onDelete: 'cascade' }),
    profileId: text('profile_id')
      .notNull()
      .references(() => profiles.id, { onDelete: 'cascade' }),
    flagId: text('flag_id').references(() => flagLibraryItems.id, { onDelete: 'set null' }),
    flagTextSnapshot: text('flag_text_snapshot').notNull(),
    drawnTurnNo: integer('drawn_turn_no').notNull(),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [index('idx_profile_flags_profile_turn').on(table.profileId, table.drawnTurnNo)]
);

export const turns = sqliteTable(
  'turns',
  {
    id: text('id').primaryKey().notNull(),
    sessionId: text('session_id')
      .notNull()
      .references(() => sessions.id, { onDelete: 'cascade' }),
    turnNo: integer('turn_no').notNull(),
    actorPlayerId: text('actor_player_id')
      .notNull()
      .references(() => sessionPlayers.id, { onDelete: 'cascade' }),
    profileId: text('profile_id')
      .notNull()
      .references(() => profiles.id, { onDelete: 'cascade' }),
    drawnProfileFlagId: text('drawn_profile_flag_id').references(() => profileFlags.id, {
      onDelete: 'set null',
    }),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [
    uniqueIndex('ux_turns_session_turn').on(table.sessionId, table.turnNo),
    index('idx_turns_session_actor').on(table.sessionId, table.actorPlayerId),
  ]
);

export const turnDecisions = sqliteTable(
  'turn_decisions',
  {
    id: text('id').primaryKey().notNull(),
    turnId: text('turn_id')
      .notNull()
      .references(() => turns.id, { onDelete: 'cascade' }),
    decision: text('decision', { enum: decisionTypes }).notNull(),
    streakBefore: integer('streak_before').notNull(),
    streakAfter: integer('streak_after').notNull(),
    nextProfileId: text('next_profile_id').references(() => profiles.id, { onDelete: 'set null' }),
    decidedAt: integer('decided_at').notNull(),
  },
  (table) => [
    uniqueIndex('ux_turn_decisions_turn_id').on(table.turnId),
    index('idx_turn_decisions_decision').on(table.decision),
  ]
);

export const sessionEvents = sqliteTable(
  'session_events',
  {
    id: text('id').primaryKey().notNull(),
    sessionId: text('session_id')
      .notNull()
      .references(() => sessions.id, { onDelete: 'cascade' }),
    turnNo: integer('turn_no').notNull(),
    playerId: text('player_id').references(() => sessionPlayers.id, { onDelete: 'set null' }),
    eventType: text('event_type', { enum: eventTypes }).notNull(),
    eventPayload: text('event_payload'),
    createdAt: integer('created_at').notNull(),
  },
  (table) => [index('idx_session_events_session_turn').on(table.sessionId, table.turnNo)]
);

export type Session = typeof sessions.$inferSelect;
export type NewSession = typeof sessions.$inferInsert;
export type SessionPlayer = typeof sessionPlayers.$inferSelect;
export type NewSessionPlayer = typeof sessionPlayers.$inferInsert;
export type Profile = typeof profiles.$inferSelect;
export type NewProfile = typeof profiles.$inferInsert;
export type FlagLibraryItem = typeof flagLibraryItems.$inferSelect;
export type NewFlagLibraryItem = typeof flagLibraryItems.$inferInsert;
export type ProfileFlag = typeof profileFlags.$inferSelect;
export type NewProfileFlag = typeof profileFlags.$inferInsert;
export type Turn = typeof turns.$inferSelect;
export type NewTurn = typeof turns.$inferInsert;
export type TurnDecision = typeof turnDecisions.$inferSelect;
export type NewTurnDecision = typeof turnDecisions.$inferInsert;
export type SessionEvent = typeof sessionEvents.$inferSelect;
export type NewSessionEvent = typeof sessionEvents.$inferInsert;
