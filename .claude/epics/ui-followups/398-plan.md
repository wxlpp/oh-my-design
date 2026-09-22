# Issue #398 plan — status visuals (PRD FR-A1 / FR-A2 / FR-A3, #384 items 1 / 3 / 4)

## Public API

```swift
public extension Color {
    // Layer 2 (SystemBackgroundColors.swift)
    static var systemGray5: Color            // iOS UIColor.systemGray5 / macOS NSColor.unemphasizedSelectedContentBackgroundColor
    // Layer 3 (StatusColors.swift)
    static var statusNeutralSubtle: Color     // -> .systemGray5
}
```

macOS has no `systemGray5`; `unemphasizedSelectedContentBackgroundColor` is opaque in both appearances
(light `#DCDCDC`, dark `#464646`) and sits one step above `windowBackgroundColor` (`#FFFFFF` / `#1E1E1E`),
which is the same role `systemGray5` plays over `systemBackground` on iOS.

No other public API changes. `Timeline.nodeColor(for:)` (internal) gains a `ColorScheme` parameter.

## FR-A1 neutral Banner background

- `bannerPalette(for: .neutral).background` = `.statusNeutralSubtle` (was `.tertiaryFill`, translucent).
- Tests (both legs, system colors only): palette token identity; `statusNeutralSubtle` resolves α = 1 in light / dark;
  a neutral banner rendered over two different opaque backdrops has identical background pixels (old token differs → mutation kills).
- iOS leg: `statusNeutralSubtle` resolves to `UIColor.systemGray5` in light / dark.

## FR-A2 rounded Banner container

- `BannerBody` background: `CoreShape.rounded(CoreRadius.medium)` fill; Bordered strokes with `.bordered(style:shape:)` on the same shape. No `clipShape` (content never clipped).
- Tests:
  - geometry: icon / text / actions / dismiss glyph frames lie inside the rounded path — regular + AX5, multi-action (iOS leg for AX5, like the existing AX5 test).
  - regression (honest rebase): legacy fixture copied from git (`Rectangle`) vs new — pixels **outside the four corner squares** are byte-identical, pixels inside the corner squares differ (both legs for neutral, catalog leg for the four status levels). Corner square side = the continuous-corner extent of `CoreRadius.medium` (measured, justified in code).
  - rounded fixture (legacy body + same rounded shape) vs new: byte-identical (full frame).
  - existing size test unchanged.

## FR-A3 Timeline warning dot contrast

- `nodeColor(for: .warning, in: .light)` = `statusAttentionForeground` (`#9A6700`, the same color the light Banner warning icon uses);
  dark stays `statusAttentionEmphasis`; other levels unchanged in both schemes.
- `TimelineNodeView` reads `@Environment(\.colorScheme)`.
- Tests: token mapping table (both legs, asset names); iOS leg: resolved non-text contrast of light warning dot vs
  `systemGroupedBackground` and `systemBackground` ≥ 3:1 (reported value); dark warning unchanged;
  full vertical Timeline pixels vs legacy copy: dark identical, light identical except inside the warning dot box.

## Files

- `Sources/OhMyDesign/Colors/SystemBackgroundColors.swift`, `StatusColors.swift`
- `Sources/OhMyDesign/Components/Banner/Banner.swift`, `Timeline/Timeline.swift`
- `Tests/OhMyDesignTests/BannerTests.swift`, `TimelineTests.swift`
- `docs/components/banner.md`, `timeline.md`, `docs/component-registry.json` (Timeline notes), `docs/BREAKING-CHANGES.md`,
  `docs/design-digest.md` + `scripts/design-digest.py` FLOORS (colors 120 → 122)
- `App/Sources/ComponentData.swift`: Banner five levels Plain / Bordered + white-card group; Timeline five levels.

## Verification

swift build / test, mainactor ratchet, downstream-probe, iOS xcodebuild test (xcresult top-level), preview host build, screenshots light / dark.
