# Net Worth Tracker

## Overview
This app helps users track total net worth over time with a smooth, low-friction experience. Users add multiple accounts and record a weekly cash balance for each one. The app then aggregates those values into a single view so users can see whether their net worth is trending positive or negative.

## Core User Flow
1. Add accounts (e.g., checking, savings, brokerage).
2. Once per week, enter the current cash amount for each account.
3. View total net worth and trend direction over time.

## Key Features
- Multiple accounts with editable balances.
- Weekly snapshots to avoid daily noise and keep tracking lightweight.
- Clear trend visualization for total net worth.
- Designed for minimal input effort and fast updates.

## UX Principles
- Single, focused workflow: add accounts → log weekly amounts → review trend.
- Fast data entry with minimal taps and clear defaults.
- Calm, consistent visuals that emphasize the trend line and total.

## Data Model (High Level)
- Account: name, type, optional notes.
- Snapshot: date (week), account balances, computed total.

## Future Enhancements
- Reminders for weekly updates.
- Export to CSV for personal analysis.
- Optional categories or tags for accounts.
