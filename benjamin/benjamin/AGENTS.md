# Repository Guidelines

## Project Structure & Module Organization
- `benjamin/Sources` holds the SwiftUI app source (entry point in `BenjaminApp.swift` and views like `ContentView.swift`).
- `benjamin/Tests` contains unit tests (currently using Swift Testing with `@Test`).
- `benjamin/Resources` stores assets and preview content (`Assets.xcassets`, `Preview Content`).
- `Project.swift` and `Tuist.swift` define the Tuist project configuration; treat these as the source of truth for targets and settings.
- `benjamin.xcodeproj` and `benjamin.xcworkspace` are generated/managed by Tuist; avoid manual edits when working through Tuist.

## Build, Test, and Development Commands
- `tuist generate` creates or refreshes the Xcode project/workspace from `Project.swift`.
- `tuist build benjamin` builds the app target (useful for CI/local validation).
- `tuist test benjaminTests` runs unit tests for the test target.
- `xcodebuild -scheme benjamin -workspace benjamin.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 15' build` builds via Xcode’s CLI if you prefer not to use Tuist.

## Coding Style & Naming Conventions
- Swift files use 4-space indentation and standard SwiftUI formatting.
- Types and views use `UpperCamelCase` (e.g., `ContentView`); variables and functions use `lowerCamelCase`.
- File names should match their primary type (e.g., `ContentView.swift` contains `ContentView`).
- No formatter or linter is configured; keep formatting consistent with existing files.

## UI & Visual Language
- Use the Liquid Glass aesthetic across the app (translucent layers, soft highlights, and subtle depth).

## Testing Guidelines
- Tests are written with the Swift Testing framework (`import Testing`, `@Test`).
- Place tests in `benjamin/Tests` and group them by feature/type.
- Name test functions with clear intent, e.g., `@Test func rendersGreeting()`.
- No explicit coverage targets are defined; add tests for new logic and UI state handling.

## Commit & Pull Request Guidelines
- Use Conventional Commits for all changes, e.g., `feat(ui): add weekly snapshot form`, `fix(data): handle empty balances`.
- Keep simple changes to a single-line subject only; omit the body unless additional context is required.
- PRs should include a concise description of changes, testing notes, and screenshots for UI changes.
- Link relevant issues or tickets when available and call out any follow-up work.
