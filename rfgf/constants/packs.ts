import { baseFlags } from '@/constants/flags';

export interface FlagPack {
  id: string;
  title: string;
  description: string;
  flags: string[];
}

const spicyFlags: string[] = [
  'Flirts with the waiter for fun',
  'Sends late-night voice notes instead of texts',
  'Has an ex in their close friends story',
  'Thinks jealousy is romantic',
  'Always posts thirst traps before bed',
  'Owns handcuffs and calls them decorative',
  'Refuses to define the relationship for months',
  'Has a safe word and is proud of it',
  'Loves public displays of affection constantly',
  'Believes every date should end in a makeout session',
  'Keeps a list of their best kisses',
  'Calls everyone babe by accident',
  'Still follows all their exes closely',
  'Wants matching tattoos on the third date',
  'Says "lets keep it casual" but acts married',
  'Sends spicy memes during family dinner',
  'Gets turned on by people who can parallel park',
  'Owns suspiciously expensive silk sheets',
  'Thinks dirty talk should start at brunch',
  'Books hotel stays for staycations every month',
  'Has a locked notes app folder called chaos',
  'Wants to roleplay every holiday',
  'Always checks chemistry within the first 10 minutes',
  'Insists first dates should include tequila shots',
  'Leaves lipstick marks as a signature move',
];

const vacationFlags: string[] = [
  'Plans a weekend trip for every public holiday',
  'Wants to wake up at 5am to catch sunrise hikes',
  'Cannot travel without a ring light',
  'Only books flights with perfect seat maps',
  'Brings 14 outfit changes for a 3-day trip',
  'Talks about points and miles at dinner',
  'Has a color-coded travel itinerary',
  'Always misses at least one train',
  'Insists on trying every local pastry',
  'Gets seasick but still books boat tours',
  'Will not check luggage under any condition',
  'Takes 200 photos before eating',
  'Treats airport lounges like sacred places',
  'Forgets adapters in every country',
  'Wants every trip to include a museum and a beach',
  'Needs one full day for souvenir shopping',
  'Prefers road trips with no fixed destination',
  'Keeps every boarding pass as a memory',
  'Books hostels to make random friends',
  'Loves red-eye flights and functions anyway',
  'Always overpacks snacks for flights',
  'Tries to learn local phrases before arrival',
  'Has three favorite travel pillows',
  'Uses vacation days the moment they are approved',
  'Wants matching travel hoodies for the couple',
];

export const builtInFlagPacks: FlagPack[] = [
  {
    id: 'core',
    title: 'Core',
    description: 'Balanced everyday chaos.',
    flags: baseFlags,
  },
  {
    id: 'spicy',
    title: 'Spicy',
    description: 'Flirty, bold, and a little risky.',
    flags: spicyFlags,
  },
  {
    id: 'vacation',
    title: 'Vacation',
    description: 'Travel and trip energy.',
    flags: vacationFlags,
  },
];

export const flagPacks = builtInFlagPacks;

export const defaultSelectedPackIds: string[] = ['core'];
export const localFlagsPackId = 'local';

export function normalizeFlagText(value: string) {
  return value.trim().toLowerCase();
}

export function dedupeFlags(flags: string[]) {
  const seen = new Set<string>();
  const deduped: string[] = [];

  for (const flag of flags) {
    const cleaned = flag.trim();
    const normalized = normalizeFlagText(cleaned);
    if (!normalized || seen.has(normalized)) {
      continue;
    }

    seen.add(normalized);
    deduped.push(cleaned);
  }

  return deduped;
}

export function getFlagsForPacks(packs: Pick<FlagPack, 'flags'>[]) {
  return dedupeFlags(packs.flatMap((pack) => pack.flags));
}

export function getBuiltInFlagsForPackIds(packIds: string[]) {
  const selectedPacks = builtInFlagPacks.filter((pack) => packIds.includes(pack.id));

  return getFlagsForPacks(selectedPacks);
}
