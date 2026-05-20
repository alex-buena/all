# Project Memory

- Stack: Tuist-managed SwiftUI iOS app (`meet` target).
- Map screen implementation uses native Apple Maps (`MapKit` / `MKMapView`) + `SwiftyH3`.
- Initial camera start is Paul-Lincke-Ufer 5, Berlin (`52.4920058, 13.4351562`).
- H3 overlay runs at fixed resolution `10` and is generated from the current viewport (plus padding) as a **continuous mask texture** with transparent holes for visited hexes.
- Rendering uses one `MKPolygon` mask overlay with interior hole polygons (visited cells) instead of per-cell overlays.
- Visited cells are currently tracked from map interaction (current map center on region changes) and persisted in `UserDefaults` under `visited_h3_cells_res10`.
- Overlay style is intentionally simple: subtle repeated texture fill with punched-out visited hex holes.
- Important runtime detail: do not subclass `MKPolygon`; use plain `MKPolygon` / `MKMultiPolygon` only (subclassing caused selector crashes previously).
- Map interaction mode: perspective + rotation are enabled (`isPitchEnabled = true`, `isRotateEnabled = true`) using realistic elevation style.
- Overlay refresh now runs from both `regionDidChange` and continuous `mapViewDidChangeVisibleRegion`, using a throttled live queue (no trailing-only debounce) plus single-flight overlay builds with "latest request wins" coalescing.
- Overlay signature is based on padded map rect + visited revision (camera heading/pitch removed from signature to avoid unnecessary rebuild churn).
- Performance guardrails: larger coverage padding (`overlayPaddingFactor=2.1`), cached visited-cell geometry (center + boundary), and capped visible hole count (`maxHoleCells=1400`) to keep rendering responsive without changing resolution.

- POI interaction:
  - Native map POIs are selected via `MKMapFeatureAnnotation` (`mapView(_:didSelect:)`).
  - Place detail lookup uses `MKMapItemRequest(mapFeatureAnnotation:)`.
  - After MapKit lookup, the app now runs async Foursquare enrichment (search by selected place name + coordinate, then details by `fsq_place_id`).
  - Bottom card shows both: native Apple debug fields (`MKMapItem`) and Foursquare enrichment fields (hours, socials, description, ratings/review snippets when present).
  - Custom viewport fetching and viewport debug panel were removed.

- Native MapKit place-data limitations (current SDK in this environment):
  - Public `MKMapItem` fields do not expose opening hours, social profiles, review snippets, ratings, or rich free-text descriptions.
  - If richer Apple-provided UI is desired, use built-in map-item detail presentation APIs (`MKSelectionAccessory` / `MKMapItemDetailViewController`) rather than custom raw field extraction.

- Current repo state: no Mapbox package/dependency is used.
- Current repo state: local Git repository is initialized (`.git` present).
- Current repo state: MapKit is primary map provider; Foursquare is used as secondary enrichment source.
- `.gitignore` now targets this Tuist/Xcode setup: ignores generated `*.xcodeproj`/`*.xcworkspace`, build/derived artifacts, `Tuist/.build`, IDE junk, and local debug dumps like `foursquare_full_output_*.txt`.
- Foursquare implementation file: `meet/Sources/FoursquarePlaceService.swift`.
- Foursquare token resolution order in app: env (`FOURSQUARE_API_KEY`/`FSQ_API_KEY`) first, then Info.plist keys.
- Foursquare auth header must be sent as `Authorization: Bearer <token>` for current Places API behavior (raw token value without `Bearer` returns `401 Invalid request token` in this environment on 2026-02-16).
- `Project.swift` currently includes both Foursquare keys for local testing.

- Build settings use automatic signing for `iphoneos` (`Apple Development`, `DEVELOPMENT_TEAM=9DB3G7Q9U4`) and disable signing for `iphonesimulator`.
- Signing team must stay aligned with the Personal Team provisioning profile: `ALEXANDER CHRISTIAN FREY (9DB3G7Q9U4)` for bundle ID `dev.tuist.meet`.
- If a generated project shows a different `DEVELOPMENT_TEAM`, run `tuist generate` to resync `meet.xcodeproj` from `Project.swift`.
- Local environment caveat (2026-02-16): `xcodebuild` currently reports `No Account for Team "9DB3G7Q9U4"` and no matching iOS development profile for `dev.tuist.meet`; this surfaces in Xcode UI as team `Unknown Name` until the Apple ID account is re-added/reauthenticated in Xcode Accounts.

- Dependency workflow for native setup:
  - Run `tuist install` after dependency changes.
  - Run `tuist generate` before opening/building the workspace.
  - If `tuist clean` was run, rerun `tuist install` before `tuist generate` (external dependencies are removed from `Tuist/.build`).

- Reliable local build commands:
  - `tuist build meet` (works; command is deprecated by Tuist but currently functional).
  - `tuist xcodebuild build -workspace meet.xcworkspace -scheme meet -configuration Debug -destination 'generic/platform=iOS Simulator'` (works).
