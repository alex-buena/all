import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import DraggableFlatList, { RenderItemParams } from 'react-native-draggable-flatlist';

import {
  defaultSelectedPackIds,
  flagPacks,
  getFlagsForPacks,
  localFlagsPackId,
} from '@/constants/packs';
import { loadSetupPreferences, saveSetupPreferences } from '@/lib/setup/setup-preferences-storage';
import { useGameStore } from '@/stores/use-game-store';
import { useLocalFlagsStore } from '@/stores/use-local-flags-store';

interface SetupPlayer {
  id: string;
  name: string;
}

function createSetupPlayer(name: string): SetupPlayer {
  return {
    id: `setup_player_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    name,
  };
}

function initialPlayers() {
  return [createSetupPlayer('Player 1'), createSetupPlayer('Player 2')];
}

function normalizePlayerNames(playerNames: string[]) {
  return playerNames.map((name) => name.trim()).filter((name, index, values) => {
    return name.length > 0 && values.indexOf(name) === index;
  });
}

export default function SetupScreen() {
  const router = useRouter();
  const startSession = useGameStore((state) => state.startSession);
  const localFlags = useLocalFlagsStore((state) => state.flags);
  const localFlagsStatus = useLocalFlagsStore((state) => state.status);
  const localFlagsError = useLocalFlagsStore((state) => state.error);
  const loadLocalFlags = useLocalFlagsStore((state) => state.loadFlags);
  const [playerInputs, setPlayerInputs] = useState<SetupPlayer[]>(initialPlayers);
  const [selectedPackIds, setSelectedPackIds] = useState<string[]>([...defaultSelectedPackIds]);

  useEffect(() => {
    void loadLocalFlags();
  }, [loadLocalFlags]);

  useEffect(() => {
    let isCancelled = false;

    const hydrateSetupPreferences = async () => {
      let preferences;
      try {
        preferences = await loadSetupPreferences();
      } catch {
        return;
      }

      if (isCancelled) {
        return;
      }

      if (preferences.playerNames.length >= 2) {
        setPlayerInputs(preferences.playerNames.map((name) => createSetupPlayer(name)));
      }

      if (preferences.selectedPackIds.length > 0) {
        setSelectedPackIds(preferences.selectedPackIds);
      }
    };

    void hydrateSetupPreferences();

    return () => {
      isCancelled = true;
    };
  }, []);

  const sessionPlayers = useMemo(() => {
    return normalizePlayerNames(playerInputs.map((player) => player.name));
  }, [playerInputs]);

  const availablePacks = useMemo(() => {
    return [
      ...flagPacks,
      {
        id: localFlagsPackId,
        title: 'My Local Flags',
        description: 'Flags created on this device.',
        flags: localFlags,
      },
    ];
  }, [localFlags]);
  const availablePackIds = useMemo(
    () => new Set(availablePacks.map((pack) => pack.id)),
    [availablePacks]
  );

  useEffect(() => {
    setSelectedPackIds((previous) => {
      const deduped = Array.from(new Set(previous));
      const filtered = deduped.filter((packId) => availablePackIds.has(packId));

      if (filtered.length === deduped.length) {
        return deduped;
      }

      if (filtered.length > 0) {
        return filtered;
      }

      return defaultSelectedPackIds.filter((packId) => availablePackIds.has(packId));
    });
  }, [availablePackIds]);

  const selectedPacks = useMemo(
    () => availablePacks.filter((pack) => selectedPackIds.includes(pack.id)),
    [availablePacks, selectedPackIds]
  );
  const selectedFlags = useMemo(() => getFlagsForPacks(selectedPacks), [selectedPacks]);
  const selectedFlagCount = selectedFlags.length;
  const canStart = sessionPlayers.length >= 2 && selectedFlagCount > 0;

  const renderPlayerRow = ({ item, drag, isActive, getIndex }: RenderItemParams<SetupPlayer>) => {
    const index = getIndex() ?? 0;

    return (
      <View style={[styles.playerRow, isActive && styles.playerRowActive]}>
        <Pressable onLongPress={drag} delayLongPress={120} style={styles.dragHandle}>
          <Text style={styles.dragHandleText}>Drag</Text>
        </Pressable>
        <TextInput
          value={item.name}
          onChangeText={(text) => {
            setPlayerInputs((previous) =>
              previous.map((player) => (player.id === item.id ? { ...player, name: text } : player))
            );
          }}
          placeholder={`Player ${index + 1}`}
          placeholderTextColor="#9ca3af"
          style={styles.input}
        />
        <Pressable
          onPress={() => {
            setPlayerInputs((previous) => {
              if (previous.length <= 2) {
                return previous;
              }
              return previous.filter((player) => player.id !== item.id);
            });
          }}
          style={styles.removeButton}>
          <Text style={styles.removeButtonText}>Remove</Text>
        </Pressable>
      </View>
    );
  };

  return (
    <DraggableFlatList
      data={playerInputs}
      onDragEnd={({ data }) => setPlayerInputs(data)}
      keyExtractor={(item) => item.id}
      renderItem={renderPlayerRow}
      activationDistance={8}
      animationConfig={{
        damping: 60,
        stiffness: 800,
        mass: 0.15,
        overshootClamping: true,
        energyThreshold: 1,
      }}
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={styles.container}
      ItemSeparatorComponent={() => <View style={styles.rowSeparator} />}
      ListHeaderComponent={
        <>
          <Text style={styles.title}>Setup Players</Text>
          <Text style={styles.subtitle}>
            Add at least 2 players, then drag rows to set the turn order.
          </Text>
        </>
      }
      ListFooterComponent={
        <View style={styles.footer}>
          <View style={styles.packSection}>
            <Text style={styles.packSectionTitle}>Choose Packs</Text>
            <Text style={styles.packSectionMeta}>
              Selected {selectedPackIds.length} packs • {selectedFlagCount} total flags
            </Text>
            <Pressable style={styles.managePacksButton} onPress={() => router.push('/packs')}>
              <Text style={styles.managePacksButtonText}>Manage Local Flags</Text>
            </Pressable>
            {localFlagsStatus === 'loading' && (
              <Text style={styles.packStatusText}>Loading local flags...</Text>
            )}
            {localFlagsStatus === 'error' && localFlagsError && (
              <Text style={styles.packErrorText}>{localFlagsError}</Text>
            )}
            <View style={styles.packList}>
              {availablePacks.map((pack) => {
                const isSelected = selectedPackIds.includes(pack.id);
                const isLocalPack = pack.id === localFlagsPackId;
                return (
                  <Pressable
                    key={pack.id}
                    style={[styles.packCard, isSelected && styles.packCardSelected]}
                    onPress={() => {
                      setSelectedPackIds((previous) => {
                        if (previous.includes(pack.id)) {
                          return previous.filter((value) => value !== pack.id);
                        }
                        return [...previous, pack.id];
                      });
                    }}>
                    <View style={styles.packTitleRow}>
                      <Text style={[styles.packTitle, isSelected && styles.packTitleSelected]}>
                        {pack.title}
                      </Text>
                      {isLocalPack && (
                        <Text style={[styles.customTag, isSelected && styles.customTagSelected]}>
                          Local
                        </Text>
                      )}
                    </View>
                    <Text style={[styles.packDescription, isSelected && styles.packDescriptionSelected]}>
                      {pack.description}
                    </Text>
                    <Text style={[styles.packCount, isSelected && styles.packCountSelected]}>
                      {pack.flags.length} flags
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          <Pressable
            style={styles.addButton}
            onPress={() => {
              setPlayerInputs((previous) => [
                ...previous,
                createSetupPlayer(`Player ${previous.length + 1}`),
              ]);
            }}>
            <Text style={styles.addButtonText}>Add Player</Text>
          </Pressable>

          <Pressable
            style={[styles.startButton, !canStart && styles.startButtonDisabled]}
            disabled={!canStart}
            onPress={() => {
              void saveSetupPreferences({
                playerNames: sessionPlayers,
                selectedPackIds,
              });
              startSession(sessionPlayers, selectedFlags, selectedPackIds);
              router.replace('/game');
            }}>
            <Text style={styles.startButtonText}>Start Game</Text>
          </Pressable>

          <Pressable style={styles.backButton} onPress={() => router.back()}>
            <Text style={styles.backButtonText}>Back</Text>
          </Pressable>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 20,
    paddingTop: 24,
    paddingBottom: 48,
    gap: 12,
    backgroundColor: '#f5f6f7',
  },
  title: {
    fontSize: 30,
    fontWeight: '700',
    color: '#111827',
  },
  subtitle: {
    fontSize: 15,
    color: '#4b5563',
    marginBottom: 12,
  },
  playerRow: {
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
  },
  playerRowActive: {
    opacity: 0.85,
  },
  rowSeparator: {
    height: 10,
  },
  dragHandle: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#9ca3af',
    paddingHorizontal: 10,
    paddingVertical: 10,
    backgroundColor: '#ffffff',
  },
  dragHandleText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#374151',
  },
  input: {
    flex: 1,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: '#111827',
  },
  removeButton: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#ef4444',
    paddingHorizontal: 10,
    paddingVertical: 10,
    backgroundColor: '#fff5f5',
  },
  removeButtonText: {
    color: '#b91c1c',
    fontWeight: '600',
    fontSize: 13,
  },
  footer: {
    marginTop: 4,
    gap: 8,
  },
  packSection: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 8,
  },
  packSectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  packSectionMeta: {
    fontSize: 13,
    color: '#4b5563',
  },
  managePacksButton: {
    alignSelf: 'flex-start',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#111827',
    paddingHorizontal: 10,
    paddingVertical: 8,
    backgroundColor: '#ffffff',
  },
  managePacksButtonText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#111827',
  },
  packStatusText: {
    fontSize: 12,
    color: '#4b5563',
  },
  packErrorText: {
    fontSize: 12,
    color: '#b91c1c',
    fontWeight: '600',
  },
  packList: {
    gap: 8,
  },
  packCard: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#d1d5db',
    padding: 10,
    backgroundColor: '#f9fafb',
    gap: 2,
  },
  packTitleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  packCardSelected: {
    borderColor: '#111827',
    backgroundColor: '#111827',
  },
  packTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#111827',
  },
  packTitleSelected: {
    color: '#ffffff',
  },
  customTag: {
    fontSize: 10,
    fontWeight: '700',
    color: '#111827',
    borderWidth: 1,
    borderColor: '#111827',
    borderRadius: 999,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  customTagSelected: {
    color: '#ffffff',
    borderColor: '#ffffff',
  },
  packDescription: {
    fontSize: 13,
    color: '#4b5563',
  },
  packDescriptionSelected: {
    color: '#e5e7eb',
  },
  packCount: {
    marginTop: 2,
    fontSize: 12,
    fontWeight: '600',
    color: '#6b7280',
  },
  packCountSelected: {
    color: '#d1d5db',
  },
  addButton: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#111827',
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
  addButtonText: {
    fontWeight: '600',
    color: '#111827',
    fontSize: 15,
  },
  startButton: {
    marginTop: 8,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    backgroundColor: '#111827',
  },
  startButtonDisabled: {
    backgroundColor: '#9ca3af',
  },
  startButtonText: {
    color: '#ffffff',
    fontWeight: '700',
    fontSize: 16,
  },
  backButton: {
    marginTop: 8,
    alignItems: 'center',
    paddingVertical: 10,
  },
  backButtonText: {
    color: '#6b7280',
    fontWeight: '600',
  },
});
