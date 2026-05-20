# Project Memory

## Game
- Name: `Red Flag Green Flag`
- Genre: lightweight party conversation game

## Locked Mechanics (v1)
- There is one shared deck of neutral `flags` (no objective red/green classification).
- Each player has a current "person they are dating."
- Draw flow is sequential with one active player at a time.
- On a player's turn, they draw exactly one random flag.
- Draws are random only.
- Flags are public to all players.
- After that draw, the table discusses and the active player immediately decides:
  - keep dating current person, or
  - dump and start a new person.
- Keep behavior: drawn flag stays on that player's current person profile.
- Dump behavior: reset only that player's current person/profile state.
- No hard win condition; game is endless and social.

## Tracking/UX Direction
- Track and display each player's current streak (consecutive rounds continuing the same person).
- Show current round count.
- Show when players choose to end a streak (restart).
- For each player, always show the full current list of flags on the person they are dating.
- On the turn handoff/draw screen, keep previously drawn flags visible for context before the next draw.

## Product Direction
- Monetization/paywall may be considered later, but not part of v1.
- Monetization strategy notes live in `/Users/sandi/codespace/free-klink/rfgf/MONETIZATION_IDEAS.md`.
- Post-v1 feature/insight backlog lives in `/Users/sandi/codespace/free-klink/rfgf/FUTURE_IDEAS.md`.
- Planned post-v1 collaboration model includes: local creation, live session contribution, and friend sharing of custom flags.
- Product positioning target: flashy, Gen Z-forward party experience with very fast interaction loops.
- Preferred post-v1 backend direction: Convex for realtime multi-device collaboration features.
- Analytics quality is a core requirement from early v1.
- Translation/localization readiness is a core requirement from early v1.

## Technical Choices (Current)
- Data layer:
  - Local persistence uses SQLite + Drizzle ORM (`drizzle-orm/expo-sqlite`).
  - Convex remains the post-v1 backend for realtime/multi-device collaboration.
- Localization stack:
  - `expo-localization` for locale and layout direction.
  - `i18next` + `react-i18next` for translation runtime in React Native.
  - `i18next-icu` for pluralization and message formatting.
- Analytics and tracking stack:
  - `posthog-react-native` for product analytics events, funnels, and feature flags.
  - `expo-tracking-transparency` for iOS ATT consent gating before tracking where required.
- Foundation implementation status:
  - Bootstrapping modules added for i18n + SQLite init + app startup store (`zustand`).
  - Root app layout now initializes foundations and wraps app in analytics provider.
  - PostHog config is env-driven (`EXPO_PUBLIC_POSTHOG_KEY`, `EXPO_PUBLIC_POSTHOG_HOST`).
  - ATT permission prompt text configured via `expo-tracking-transparency` plugin in `app.json`.
  - `.env.example` added with analytics env keys.
  - Drizzle schema is defined in `lib/storage/schema.ts`.
  - Drizzle migrations are generated via `drizzle-kit` into `/drizzle` and applied at runtime with `drizzle-orm/expo-sqlite/migrator`.
  - Migration history is managed by Drizzle's internal migrations table (not custom `app_kv` versioning).
  - Babel/Metro are configured for Drizzle Expo migrations (`babel-plugin-inline-import` for `.sql`, Metro `sourceExts` includes `sql` and `assetExts` includes `wasm` for expo-sqlite web builds).
  - Current schema includes sessions, players, profiles, profile flags, turns, decisions, events, flag library, and flag stats.
- Main wireframe game loop is implemented with Zustand store in `stores/use-game-store.ts`.
- Active routes are now `index` (home), `setup` (player setup), and `game` (core loop).
- Core loop phases implemented: `awaiting_draw` -> `awaiting_decision` -> next player turn.
- Active game loop state is now persisted/restored via SQLite `app_kv` key `active_game_session_v1` (hydrated at app bootstrap).
- Setup screen now supports drag-and-drop player order before start; turn order follows this arranged list.
- Root app tree is wrapped in `GestureHandlerRootView` to support drag/gesture interactions.
- Drag reorder list is tuned for fast snap (separator-based spacing + tighter spring config) to reduce post-drop settling.
- Setup now includes multi-select flag pack selection before game start.
- Current example packs: `Core`, `Spicy`, and `Vacation`.
- Deck generation uses the union of selected packs (deduped by normalized flag text).
- Local flag management is now supported via a dedicated `/packs` screen (`My Local Flags`).
- Local flags persistence is stored in SQLite `app_kv` under key `local_flags_v1`.
- Setup pack selection now includes built-in packs plus one `My Local Flags` selectable collection.
- Product decision: v1 does not support creating multiple custom packs; only one local custom-flag collection is supported.
- Setup now persists and restores last-started player names + last selected packs via SQLite `app_kv` key `setup_preferences_v1`.

## Experience Guidelines (Gen Z Bar Context)
- Conversation-first: the app should spark talk, not replace talk.
- One-device table mode first: assume one shared phone as host.
- Minimal interaction cost: a round should take 1-2 taps in-app, then people talk.
- Fast setup: no account, no onboarding flow, no required profile creation.
- Public readability: large text, high contrast, low-light friendly UI.
- Social pacing: reveal flag quickly, then get out of the way for discussion.
- Humor + variety: prioritize surprising, funny, awkward, and relatable flags.
- Instant reset loop: restarting a person must be obvious and frictionless.
- Endless casual sessions: support dropping in/out without breaking play.
- Avoid over-gamification: no heavy scoring, ranking, or competitive pressure in v1.
- Visual style target: bold, flashy, and memorable (not plain template UI).
- Performance target: smooth animations and responsive taps under bar-like conditions.

## Animation Direction
- Motion quality is a core requirement, not polish-only.
- Animation style: snappy and expressive, with short transitions that keep flow fast.
- Prioritize turn moments: draw reveal, keep/dump decision feedback, streak updates, turn handoff.
- Pair key actions with subtle haptic feedback.
- Maintain smoothness on mid-range devices (avoid heavy JS-thread-driven animation work).
- Respect reduced-motion accessibility settings.

## Analytics Standards
- Use a defined tracking plan (event names + property schema + ownership) before broad instrumentation.
- Track core loop events first: draw, keep, dump, restart, round progress, session start/end.
- Use consistent naming and typed payloads to reduce analytics drift.
- Avoid collecting PII by default; respect consent requirements by platform/region.
- Build for offline capture and delayed flush to handle bar/low-connectivity environments.

## Localization Standards
- Externalize all user-facing strings from day one.
- Use ICU-style messages for pluralization/select logic (no string concatenation for grammar).
- Support locale fallbacks and missing-key handling.
- Test pseudo-localization and long-string expansion to catch layout issues early.
- Design UI for future RTL and variable text lengths.

## MVP Product Guidelines
- Core screens: lobby/setup, round/reveal, continue-or-restart decision, streak/round tracker.
- Core data shown at all times: current round number + each player's current streak.
- Profile visibility: player's current person view includes all accumulated flags (full history for that person).
- Draw screen behavior: show the active player's existing flags plus one clear `Tap to Draw` action.
- Input model: random draw only, one flag on each active-player turn.
- Turn pacing model: draw -> discuss -> immediate keep/dump decision -> pass turn.
- Defaults: no paywall, no IAP, no ads in v1.

## Out of Scope (v1)
- Multi-device synchronization.
- Competitive leaderboard or winner logic.
- Complex moderation systems (basic content curation only).
- Monetization features.

## Future Concepts (Post-v1)
- See `/Users/sandi/codespace/free-klink/rfgf/FUTURE_IDEAS.md` for detailed post-v1 concepts and experiments.

## Validation Criteria (Early Playtests)
- Players can start a game in under 30 seconds.
- Players spend most of the session talking, not tapping.
- No rule confusion about continue vs restart.
- At least one full table wants "one more round" after 10 minutes.
