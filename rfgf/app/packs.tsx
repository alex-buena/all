import { useEffect, useState } from 'react';
import { useRouter } from 'expo-router';
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { useLocalFlagsStore } from '@/stores/use-local-flags-store';

export default function LocalFlagsScreen() {
  const router = useRouter();
  const flags = useLocalFlagsStore((state) => state.flags);
  const status = useLocalFlagsStore((state) => state.status);
  const error = useLocalFlagsStore((state) => state.error);
  const loadFlags = useLocalFlagsStore((state) => state.loadFlags);
  const addFlag = useLocalFlagsStore((state) => state.addFlag);
  const updateFlag = useLocalFlagsStore((state) => state.updateFlag);
  const deleteFlag = useLocalFlagsStore((state) => state.deleteFlag);

  const [newFlagText, setNewFlagText] = useState('');
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [editingText, setEditingText] = useState('');
  const [saving, setSaving] = useState(false);
  const [deletingIndex, setDeletingIndex] = useState<number | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  useEffect(() => {
    void loadFlags();
  }, [loadFlags]);

  const addNewFlag = async () => {
    setSaving(true);
    setSubmitError(null);

    try {
      await addFlag(newFlagText);
      setNewFlagText('');
    } catch (addError) {
      setSubmitError(addError instanceof Error ? addError.message : 'Failed to add flag.');
    } finally {
      setSaving(false);
    }
  };

  const startEditing = (index: number) => {
    setEditingIndex(index);
    setEditingText(flags[index] ?? '');
    setSubmitError(null);
  };

  const cancelEditing = () => {
    setEditingIndex(null);
    setEditingText('');
    setSubmitError(null);
  };

  const saveEdit = async () => {
    if (editingIndex === null) {
      return;
    }

    setSaving(true);
    setSubmitError(null);

    try {
      await updateFlag(editingIndex, editingText);
      cancelEditing();
    } catch (editError) {
      setSubmitError(editError instanceof Error ? editError.message : 'Failed to update flag.');
    } finally {
      setSaving(false);
    }
  };

  const requestDelete = (index: number, text: string) => {
    Alert.alert('Delete local flag?', `"${text}" will be removed from this device.`, [
      {
        text: 'Cancel',
        style: 'cancel',
      },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          void (async () => {
            setDeletingIndex(index);
            setSubmitError(null);
            try {
              await deleteFlag(index);
              if (editingIndex === index) {
                cancelEditing();
              }
            } catch (deleteError) {
              setSubmitError(
                deleteError instanceof Error ? deleteError.message : 'Failed to delete flag.'
              );
            } finally {
              setDeletingIndex(null);
            }
          })();
        },
      },
    ]);
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>My Local Flags</Text>
      <Text style={styles.subtitle}>
        Add your own flags here. This list stays on your device and can be included as one deck in
        setup.
      </Text>

      <View style={styles.actionsRow}>
        <Pressable style={styles.secondaryButton} onPress={() => router.back()}>
          <Text style={styles.secondaryButtonText}>Back to Setup</Text>
        </Pressable>
      </View>

      <View style={styles.editorCard}>
        <Text style={styles.editorTitle}>Add Local Flag</Text>
        <View style={styles.addRow}>
          <TextInput
            style={[styles.input, styles.addInput]}
            value={newFlagText}
            onChangeText={setNewFlagText}
            placeholder="Type a new flag"
            placeholderTextColor="#9ca3af"
          />
          <Pressable
            style={[styles.primaryButton, saving && styles.disabledButton]}
            disabled={saving || status === 'loading'}
            onPress={() => {
              void addNewFlag();
            }}>
            <Text style={styles.primaryButtonText}>Add</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.listCard}>
        <Text style={styles.listTitle}>Local Flags ({flags.length})</Text>
        {status === 'loading' && <Text style={styles.emptyText}>Loading local flags...</Text>}
        {status === 'error' && error && <Text style={styles.errorText}>{error}</Text>}
        {status !== 'loading' && flags.length === 0 && (
          <Text style={styles.emptyText}>No local flags yet.</Text>
        )}

        {flags.map((flag, index) => {
          const isEditing = editingIndex === index;
          return (
            <View key={`${flag}-${index}`} style={styles.flagRow}>
              {isEditing ? (
                <>
                  <TextInput
                    style={styles.input}
                    value={editingText}
                    onChangeText={setEditingText}
                    placeholder="Edit flag"
                    placeholderTextColor="#9ca3af"
                  />
                  <View style={styles.rowActions}>
                    <Pressable
                      style={[styles.smallButton, saving && styles.disabledButton]}
                      disabled={saving}
                      onPress={() => {
                        void saveEdit();
                      }}>
                      <Text style={styles.smallButtonText}>{saving ? 'Saving...' : 'Save'}</Text>
                    </Pressable>
                    <Pressable style={styles.smallGhostButton} onPress={cancelEditing}>
                      <Text style={styles.smallGhostButtonText}>Cancel</Text>
                    </Pressable>
                  </View>
                </>
              ) : (
                <>
                  <Text style={styles.flagText}>{flag}</Text>
                  <View style={styles.rowActions}>
                    <Pressable style={styles.smallButton} onPress={() => startEditing(index)}>
                      <Text style={styles.smallButtonText}>Edit</Text>
                    </Pressable>
                    <Pressable
                      style={[
                        styles.smallDangerButton,
                        deletingIndex === index && styles.disabledButton,
                      ]}
                      disabled={deletingIndex === index}
                      onPress={() => requestDelete(index, flag)}>
                      <Text style={styles.smallDangerButtonText}>
                        {deletingIndex === index ? 'Deleting...' : 'Delete'}
                      </Text>
                    </Pressable>
                  </View>
                </>
              )}
            </View>
          );
        })}
      </View>

      {submitError && <Text style={styles.errorText}>{submitError}</Text>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 32,
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
  },
  actionsRow: {
    gap: 8,
  },
  editorCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 8,
  },
  editorTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  addRow: {
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
  },
  addInput: {
    flex: 1,
  },
  listCard: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    padding: 12,
    gap: 8,
  },
  listTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#111827',
  },
  flagRow: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    backgroundColor: '#f9fafb',
    padding: 10,
    gap: 8,
  },
  flagText: {
    fontSize: 14,
    color: '#111827',
    lineHeight: 20,
  },
  rowActions: {
    flexDirection: 'row',
    gap: 8,
  },
  input: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#d1d5db',
    backgroundColor: '#ffffff',
    paddingHorizontal: 10,
    paddingVertical: 10,
    color: '#111827',
    fontSize: 15,
  },
  primaryButton: {
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 11,
    alignItems: 'center',
    backgroundColor: '#111827',
  },
  primaryButtonText: {
    color: '#ffffff',
    fontWeight: '700',
    fontSize: 14,
  },
  secondaryButton: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#111827',
    paddingVertical: 11,
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
  secondaryButtonText: {
    color: '#111827',
    fontWeight: '700',
    fontSize: 14,
  },
  smallButton: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#111827',
    paddingHorizontal: 10,
    paddingVertical: 8,
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
  smallButtonText: {
    color: '#111827',
    fontSize: 12,
    fontWeight: '700',
  },
  smallGhostButton: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d1d5db',
    paddingHorizontal: 10,
    paddingVertical: 8,
    alignItems: 'center',
    backgroundColor: '#ffffff',
  },
  smallGhostButtonText: {
    color: '#4b5563',
    fontSize: 12,
    fontWeight: '700',
  },
  smallDangerButton: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ef4444',
    paddingHorizontal: 10,
    paddingVertical: 8,
    alignItems: 'center',
    backgroundColor: '#fff5f5',
  },
  smallDangerButtonText: {
    color: '#b91c1c',
    fontSize: 12,
    fontWeight: '700',
  },
  disabledButton: {
    opacity: 0.6,
  },
  emptyText: {
    fontSize: 13,
    color: '#6b7280',
  },
  errorText: {
    fontSize: 13,
    color: '#b91c1c',
    fontWeight: '600',
  },
});
