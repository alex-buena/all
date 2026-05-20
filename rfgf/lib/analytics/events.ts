import type { PostHog } from 'posthog-react-native';

interface AnalyticsEventMap {
  tracking_permission_status: {
    can_ask_again: boolean;
    status: string;
  };
}

type AnalyticsEventName = keyof AnalyticsEventMap;

export function captureAnalyticsEvent<Name extends AnalyticsEventName>(
  posthog: PostHog,
  name: Name,
  properties: AnalyticsEventMap[Name]
) {
  posthog.capture(name, properties);
}
