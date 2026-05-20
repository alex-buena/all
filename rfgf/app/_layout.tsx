import { useEffect } from 'react';
import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import 'react-native-reanimated';

import { AppAnalyticsProvider } from '@/lib/analytics/provider';
import { initializeI18n } from '@/lib/i18n';
import { useAppBootstrapStore } from '@/stores/use-app-bootstrap-store';
import { useColorScheme } from '@/hooks/use-color-scheme';

export const unstable_settings = {
  anchor: 'index',
};

void initializeI18n();

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const bootstrap = useAppBootstrapStore((state) => state.bootstrap);
  const bootstrapError = useAppBootstrapStore((state) => state.error);

  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);

  useEffect(() => {
    if (bootstrapError) {
      console.error('[bootstrap] Failed to initialize app foundations:', bootstrapError);
    }
  }, [bootstrapError]);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AppAnalyticsProvider>
        <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
          <Stack>
            <Stack.Screen name="index" options={{ title: 'Red Flag Green Flag' }} />
            <Stack.Screen name="setup" options={{ title: 'Setup Players' }} />
            <Stack.Screen name="packs" options={{ title: 'Local Flags' }} />
            <Stack.Screen name="game" options={{ title: 'Game' }} />
            <Stack.Screen name="modal" options={{ presentation: 'modal', title: 'Modal' }} />
          </Stack>
          <StatusBar style="auto" />
        </ThemeProvider>
      </AppAnalyticsProvider>
    </GestureHandlerRootView>
  );
}
