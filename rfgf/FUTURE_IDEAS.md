# Future Ideas (Post-v1 Backlog)

## Purpose
- Keep speculative and expansion ideas out of the core v1 rules.
- Use this file as the canonical backlog for post-v1 concepts.

## Flag Insights & Metadata
- Per-flag `draw_count`.
- Per-flag `deal_breaker_count` (times the active player dumped after drawing it).
- Per-flag `deal_breaker_rate = deal_breaker_count / draw_count`.
- Reliability guardrail: only show rates after minimum sample size (for example, `>= 20 draws`).
- UX framing: show as community/table reaction, not objective truth.

## Fun Insight Features
- `Controversy Score`: flags with near 50/50 keep vs dump outcomes.
- `Instant Dump Rate`: dumped on the same turn the flag appears.
- `Streak Killer Score`: how often a flag ends long keep streaks.
- `Survivor Score`: how often a flag remains on a profile for 3+ turns.
- `Combo Danger`: top two-flag combinations that trigger dumps.
- `Redemption Flags`: flags that look risky but are often kept.
- `Table Personality`: classify sessions as strict/chill/chaotic from behavior.
- `Player Taste Profile`: each player's most common personal deal-breakers.
- `Most Polarizing Flag`: highest disagreement across players.
- `Tonight's Hall of Fame`: most drawn, most dumped, most survived flags.

## Social & UGC
- Local sharing of custom flags with nearby friends/devices.
- Private friend-group packs.
- Optional public/community packs (with moderation later).

## Collaboration Modes (Planned)
- Mode 1: local flag creation (any player can create custom flags on device).
- Mode 2: live session contribution (everyone in a session with the app can add flags to that session pool).
- Mode 3: friend sharing (players can share their already-created local flags with friends).
- Backend direction for these modes: Convex (post-v1) for realtime session state and sync.

## Content Expansion
- Themed packs (work, travel, chaotic, wholesome, archetypes, etc.).
- Rotating "pack of the week" experiments.

## Monetization Alignment
- Keep core loop free.
- Monetize optional content and premium tools.
- See `/Users/sandi/codespace/free-klink/rfgf/MONETIZATION_IDEAS.md` for monetization options.
