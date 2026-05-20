import { getLocales } from 'expo-localization';
import i18next from 'i18next';
import ICU from 'i18next-icu';
import { initReactI18next } from 'react-i18next';

import { AppLanguage, defaultNamespace, fallbackLanguage, resources } from '@/lib/i18n/resources';

let initializationPromise: Promise<void> | null = null;

function isSupportedLanguage(language: string): language is AppLanguage {
  return Object.prototype.hasOwnProperty.call(resources, language);
}

function resolveInitialLanguage(): AppLanguage {
  const locale = getLocales()[0];
  const candidates = [locale?.languageTag, locale?.languageCode]
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.toLowerCase());

  for (const candidate of candidates) {
    if (isSupportedLanguage(candidate)) {
      return candidate;
    }

    const baseLanguage = candidate.split('-')[0];
    if (isSupportedLanguage(baseLanguage)) {
      return baseLanguage;
    }
  }

  return fallbackLanguage;
}

export function initializeI18n() {
  if (initializationPromise) {
    return initializationPromise;
  }

  initializationPromise = i18next
    .use(ICU)
    .use(initReactI18next)
    .init({
      resources,
      lng: resolveInitialLanguage(),
      fallbackLng: fallbackLanguage,
      defaultNS: defaultNamespace,
      ns: [defaultNamespace],
      interpolation: {
        escapeValue: false,
      },
      react: {
        useSuspense: false,
      },
      returnNull: false,
    })
    .then(() => undefined);

  return initializationPromise;
}

export { i18next };
