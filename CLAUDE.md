# Kraft — working rules

Sticky-note life planner for macOS 26 (SwiftUI, Swift 6.3, Command Line Tools only — no Xcode).
The owner writes English and Arabic. Visual identity is the most important part: read `DESIGN.md` first.

## Build / test / look
- `CONFIG=debug ./scripts/bundle.sh` → `build/Kraft.app` (fonts copied in; Molhim is git-ignored in `Resources/PrivateFonts/`, never commit it).
- `./scripts/test.sh` → Swift Testing (KraftCore). Put logic in `KraftCore` so it is testable.
- Visual check: `KRAFT_SNAPSHOT=$PWD/snapshots build/Kraft.app/Contents/MacOS/Kraft -ApplePersistenceIgnoreState YES`
  writes PNGs and quits. Add your own shots in your area's `Snapshot+<Area>.swift`. Then Read the PNGs.
  Offscreen renders can't draw system materials / Liquid Glass. Avoid `.blendMode(.softLight)` on large layers (dithers).
- `./scripts/snapshots.sh` renders every shot in English (`snapshots/en/`) and Arabic RTL (`snapshots/ar/`).
- Never `pkill Kraft` / `killall Kraft` — other sessions run their own builds. If you launch yours, kill it by PID.

## Design rules
- UI text: system font only (SF Pro / SF Arabic). Handwriting fonts only on paper (`Hand`, `FontRegistry`).
- Reuse the kit: `Tok` tokens, `GlossyTag` / `GlossyButtonStyle` / `EmbossedLabel` (ref-5 tags), `DieCutSticker` (ref-6/7),
  `PaperSurface`, `StickyCard`, `WashiTape`, `PushPin`, `PaperClip`, `PaidStamp`, `GrainOverlay`. Extend them, don't fork them.
- No grey default-looking controls where a kit piece fits; no gradient blobs, generic cards or "AI slop". Native macOS behaviour
  (menus, shortcuts, sheets, popovers, ⌘Z) is welcome. Calm motion only; respect Reduce Motion (`Motion.enabled`, `accessibilityReduceMotion`).
- Light appearance first.

## Code rules
- All data flows through `StickyStore` (`add`, `update(_:actionName:coalesce:)`, `delete`, `toggleChecklistItem`, `setDone`).
  Board UI state is `BoardModel`; long-lived services are `AppServices.shared`.
- Immutable updates (copy, change, write back). Swift 6 strict concurrency; UI is `@MainActor`.
- User-facing strings: SwiftUI literals (`Text("Due")`, `Button("Copy")`) or `String(localized: "…")` for String values,
  with a key in both `Resources/Localization/{en,ar}.lproj/Localizable.strings` (the Localization tests fail otherwise).
  Interpolate Strings only; numbers and dates go through `@Environment(\.kraftFormat)` (UI language + digit setting).
  Use leading/trailing, never left/right, so RTL works.
- Files stay under ~400 lines; split by feature.
- Conventional commits (`feat:`, `fix:` …) ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
