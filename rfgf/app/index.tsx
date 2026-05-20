import { useRouter } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useGameStore } from '@/stores/use-game-store';

export default function HomeScreen() {
  const router = useRouter();
  const status = useGameStore((state) => state.status);
  const players = useGameStore((state) => state.players);
  const turnNo = useGameStore((state) => state.turnNo);
  const resetSession = useGameStore((state) => state.resetSession);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Red Flag Green Flag</Text>
      <Text style={styles.subtitle}>
        Quick wireframe build. One player draws, everyone discusses, then that player keeps dating
        or dumps and resets.
      </Text>

      <Pressable style={styles.primaryButton} onPress={() => router.push('/setup')}>
        <Text style={styles.primaryButtonText}>New Game</Text>
      </Pressable>

      {status === 'active' && (
        <>
          <Pressable style={styles.secondaryButton} onPress={() => router.push('/game')}>
            <Text style={styles.secondaryButtonText}>Resume Session</Text>
          </Pressable>
          <Text style={styles.sessionMeta}>
            {players.length} players active, current turn {turnNo}
          </Text>
          <Pressable style={styles.ghostButton} onPress={resetSession}>
            <Text style={styles.ghostButtonText}>Reset Session</Text>
          </Pressable>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 32,
    gap: 16,
    backgroundColor: '#f5f6f7',
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    color: '#1a1a1a',
  },
  subtitle: {
    fontSize: 16,
    lineHeight: 22,
    color: '#4b5563',
  },
  primaryButton: {
    marginTop: 8,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    backgroundColor: '#111827',
  },
  primaryButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButton: {
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#111827',
    backgroundColor: '#ffffff',
  },
  secondaryButtonText: {
    color: '#111827',
    fontSize: 16,
    fontWeight: '600',
  },
  sessionMeta: {
    color: '#374151',
    fontSize: 14,
  },
  ghostButton: {
    paddingVertical: 10,
    alignItems: 'center',
  },
  ghostButtonText: {
    color: '#6b7280',
    fontSize: 14,
    fontWeight: '600',
  },
});
