import { PropsWithChildren, useEffect } from 'react';
import { Platform } from 'react-native';
import { usePathname } from 'expo-router';
import {
  getTrackingPermissionsAsync,
  requestTrackingPermissionsAsync,
} from 'expo-tracking-transparency';
import { PostHogProvider, usePostHog } from 'posthog-react-native';

import { captureAnalyticsEvent } from '@/lib/analytics/events';

const POSTHOG_API_KEY = process.env.EXPO_PUBLIC_POSTHOG_KEY;
const POSTHOG_HOST = process.env.EXPO_PUBLIC_POSTHOG_HOST ?? 'https://us.i.posthog.com';

function AnalyticsEffects() {
  const posthog = usePostHog();
  const pathname = usePathname();

  useEffect(() => {
    if (!pathname) {
      return;
    }

    void posthog.screen(pathname);
  }, [pathname, posthog]);

  useEffect(() => {
    if (Platform.OS !== 'ios') {
      return;
    }

    let mounted = true;

    const syncTrackingPermission = async () => {
      try {
        let permission = await getTrackingPermissionsAsync();

        if (permission.status === 'undetermined') {
          permission = await requestTrackingPermissionsAsync();
        }

        if (!mounted) {
          return;
        }

        captureAnalyticsEvent(posthog, 'tracking_permission_status', {
          status: permission.status,
          can_ask_again: permission.canAskAgain,
        });
      } catch {
        // No-op: tracking permission checks should never block app flow.
      }
    };

    void syncTrackingPermission();

    return () => {
      mounted = false;
    };
  }, [posthog]);

  return null;
}

export function AppAnalyticsProvider({ children }: PropsWithChildren) {
  if (!POSTHOG_API_KEY) {
    return <>{children}</>;
  }

  return (
    <PostHogProvider
      apiKey={POSTHOG_API_KEY}
      options={{
        host: POSTHOG_HOST,
        captureAppLifecycleEvents: true,
      }}
      autocapture={{
        captureTouches: true,
        captureScreens: false,
      }}>
      <AnalyticsEffects />
      {children}
    </PostHogProvider>
  );
}
