export const fallbackLanguage = 'en';
export const defaultNamespace = 'common';

export const resources = {
  en: {
    common: {
      tabs: {
        home: 'Home',
        explore: 'Explore',
      },
    },
  },
} as const;

export type AppLanguage = keyof typeof resources;
