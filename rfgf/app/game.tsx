import { useMemo } from 'react';
import { useRouter } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { useGameStore } from '@/stores/use-game-store';

function sectionTitle(label: string) {
  return <Text style={styles.sectionTitle}>{label}</Text>;
}

export default function GameScreen() {
  const router = useRouter();

  const status = useGameStore((state) => state.status);
  const players = useGameStore((state) => state.players);
  const activePlayerIndex = useGameStore((state) => state.activePlayerIndex);
  const turnNo = useGameStore((state) => state.turnNo);
  const phase = useGameStore((state) => state.phase);
  const activeDrawnFlag = useGameStore((state) => state.activeDrawnFlag);
  const streakEvents = useGameStore((state) => state.streakEvents);
  const drawFlag = useGameStore((state) => state.drawFlag);
  const keepDating = useGameStore((state) => state.keepDating);
  const dumpPerson = useGameStore((state) => state.dumpPerson);
  const resetSession = useGameStore((state) => state.resetSession);

  const activePlayer = players[activePlayerIndex];
  const roundNo = useMemo(() => {
    if (players.length === 0) {
      return 1;
    }

    return Math.floor((turnNo - 1) / players.length) + 1;
  }, [players.length, turnNo]);

  if (status !== 'active' || players.length === 0 || !activePlayer) {
    return (
      <View style={styles.emptyState}>
        <Text style={styles.emptyTitle}>No Active Session</Text>
        <Text style={styles.emptyText}>Create a game first and then return here.</Text>
        <Pressable style={styles.primaryButton} onPress={() => router.replace('/')}>
          <Text style={styles.primaryButtonText}>Go Home</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.metaRow}>
        <Text style={styles.metaLabel}>Round {roundNo}</Text>
        <Text style={styles.metaLabel}>Turn {turnNo}</Text>
      </View>

      <View style={styles.activePlayerCard}>
        <Text style={styles.activePlayerLabel}>Active Player</Text>
        <Text style={styles.activePlayerName}>{activePlayer.name}</Text>
        <Text style={styles.activePlayerStreak}>Current streak: {activePlayer.streak}</Text>
      </View>

      {sectionTitle('Players and Current Person Flags')}
      {players.map((player, index) => (
        <View
          key={player.id}
          style={[styles.playerCard, index === activePlayerIndex && styles.activePlayerBorder]}>
          <View style={styles.playerHeaderRow}>
            <Text style={styles.playerName}>
              {player.name} {index === activePlayerIndex ? '(Active)' : ''}
            </Text>
            <Text style={styles.playerStreak}>Streak {player.streak}</Text>
          </View>
          <Text style={styles.flagsLabel}>Current person flags:</Text>
          {player.currentFlags.length === 0 ? (
            <Text style={styles.emptyFlags}>No flags yet.</Text>
          ) : (
            player.currentFlags.map((flag, flagIndex) => (
              <Text key={`${player.id}-${flag}-${flagIndex}`} style={styles.flagItem}>
                - {flag}
              </Text>
            ))
          )}
        </View>
      ))}

      {sectionTitle('Turn Flow')}
      {phase === 'awaiting_draw' ? (
        <View style={styles.turnCard}>
          <Text style={styles.turnHeadline}>Next up: {activePlayer.name}</Text>
          <Text style={styles.turnText}>
            Show this player profile context, then tap draw for the next random public flag.
          </Text>

          <Text style={styles.flagsLabel}>Current flags before draw:</Text>
          {activePlayer.currentFlags.length === 0 ? (
            <Text style={styles.emptyFlags}>No flags yet for this person.</Text>
          ) : (
            activePlayer.currentFlags.map((flag, index) => (
              <Text key={`active-before-${index}-${flag}`} style={styles.flagItem}>
                - {flag}
              </Text>
            ))
          )}

          <Pressable style={styles.primaryButton} onPress={drawFlag}>
            <Text style={styles.primaryButtonText}>Tap to Draw</Text>
          </Pressable>
        </View>
      ) : (
        <View style={styles.turnCard}>
          <Text style={styles.turnHeadline}>Drawn Flag</Text>
          <Text style={styles.drawnFlag}>{activeDrawnFlag}</Text>
          <Text style={styles.turnText}>
            Discuss, then {activePlayer.name} chooses whether to keep dating this person or dump and
            reset.
          </Text>
          <View style={styles.decisionRow}>
            <Pressable style={styles.keepButton} onPress={keepDating}>
              <Text style={styles.keepButtonText}>Keep Dating</Text>
            </Pressable>
            <Pressable style={styles.dumpButton} onPress={dumpPerson}>
              <Text style={styles.dumpButtonText}>Dump Person</Text>
            </Pressable>
          </View>
        </View>
      )}

      {sectionTitle('Streak End Events')}
      <View style={styles.eventsCard}>
        {streakEvents.length === 0 ? (
          <Text style={styles.emptyFlags}>No streaks ended yet.</Text>
        ) : (
          streakEvents.slice(0, 6).map((event) => (
            <Text key={event.id} style={styles.eventItem}>
              {event.playerName} ended streak {event.streak} on turn {event.turnNo}
            </Text>
          ))
        )}
      </View>

      <Pressable
        style={styles.endSessionButton}
        onPress={() => {
          resetSession();
          router.replace('/');
        }}>
        <Text style={styles.endSessionButtonText}>End Session</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 36,
    gap: 12,
    backgroundColor: '#eef1f4',
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  metaLabel: {
    fontSize: 14,
    color: '#374151',
    fontWeight: '600',
  },
  activePlayerCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#1d4ed8',
    backgroundColor: '#eff6ff',
    padding: 12,
    gap: 4,
  },
  activePlayerLabel: {
    fontSize: 12,
    color: '#1d4ed8',
    textTransform: 'uppercase',
    fontWeight: '700',
  },
  activePlayerName: {
    fontSize: 24,
    color: '#111827',
    fontWeight: '700',
  },
  activePlayerStreak: {
    fontSize: 14,
    color: '#1f2937',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
    marginTop: 4,
  },
  playerCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 4,
  },
  activePlayerBorder: {
    borderColor: '#1d4ed8',
  },
  playerHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  playerName: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  playerStreak: {
    fontSize: 13,
    color: '#4b5563',
    fontWeight: '600',
  },
  flagsLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#374151',
    marginTop: 2,
  },
  emptyFlags: {
    fontSize: 13,
    color: '#6b7280',
  },
  flagItem: {
    fontSize: 14,
    color: '#111827',
    lineHeight: 20,
  },
  turnCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#111827',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 8,
  },
  turnHeadline: {
    fontSize: 19,
    fontWeight: '700',
    color: '#111827',
  },
  turnText: {
    fontSize: 14,
    lineHeight: 20,
    color: '#374151',
  },
  drawnFlag: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    backgroundColor: '#f9fafb',
    paddingHorizontal: 10,
    paddingVertical: 12,
    fontSize: 18,
    fontWeight: '700',
    color: '#111827',
  },
  decisionRow: {
    flexDirection: 'row',
    gap: 8,
  },
  primaryButton: {
    marginTop: 4,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: 'center',
    backgroundColor: '#111827',
  },
  primaryButtonText: {
    color: '#ffffff',
    fontWeight: '700',
    fontSize: 15,
  },
  keepButton: {
    flex: 1,
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: '#065f46',
  },
  keepButtonText: {
    color: '#ffffff',
    fontWeight: '700',
  },
  dumpButton: {
    flex: 1,
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: '#b91c1c',
  },
  dumpButtonText: {
    color: '#ffffff',
    fontWeight: '700',
  },
  eventsCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 6,
  },
  eventItem: {
    fontSize: 14,
    color: '#111827',
  },
  endSessionButton: {
    marginTop: 8,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#9ca3af',
    backgroundColor: '#ffffff',
    paddingVertical: 12,
    alignItems: 'center',
  },
  endSessionButtonText: {
    color: '#374151',
    fontWeight: '700',
  },
  emptyState: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 40,
    gap: 10,
    backgroundColor: '#eef1f4',
  },
  emptyTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: '#111827',
  },
  emptyText: {
    fontSize: 15,
    color: '#4b5563',
  },
});
