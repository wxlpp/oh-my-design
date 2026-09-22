# Issue #399 plan — overlays & levels (FR-B1…FR-B4)

## Files
- `Sources/OhMyDesign/Components/Toast/Toast.swift` — B1 danger icon `exclamationmark.circle`; B2 AX-size layout puts the icon inline in the title text (no icon column); decoration passes a per-presentation chrome to `floatingGlass`.
- `Sources/OhMyDesign/Modifier/FloatingGlassModifier.swift` — internal `FloatingGlassChrome` (border hairline/none, backing translucent/opaque, bleed edges). Public API unchanged; public init keeps today's chrome (`.floating`).
  - capsule / rounded toast, FloatButton: `.floating` (unchanged pixels)
  - full-width banner: `.edgeBanner(edge)` — no hairline, backing ignores the safe area on the anchored edge
  - HUD: `.hud` — opaque `surfaceRaised` backing, hairline kept
- `Sources/OhMyDesign/Modifier/SurfaceModifier.swift` — `var border` → `func border(at:)`; elevated `.content` → `.clear`; everything else unchanged (`.card` alias unchanged: FR names `.content` only).

## Public API
No signature change. Visual changes only → `docs/BREAKING-CHANGES.md` new section.

## Tests
- `Tests/OhMyDesignTests/LegacyOverlayRendering.swift`: verbatim copies of the pre-change `FloatingGlassModifier`, `ToastView` (+ decoration) and `SurfaceModifier` / border mapping.
- `ToastLevelVisualTests`: danger icon is `exclamationmark.circle`.
- `ToastAccessibilityLayoutTests` (iOS): at AX5 the longest word's laid-out line width ≥ its intrinsic width (Text.LayoutKey); control: legacy fails the same check. Regular sizes: capsule toast pixels == legacy (non-danger levels, light/dark, .large/.xxxLarge).
- `FloatingGlassChromeTests`: `.floating` == legacy pixels; banner has no hairline (== reference without stroke, != legacy); banner backing extends into a top safe-area inset; HUD interior pixels independent of text underneath (legacy control shows through).
- `SurfaceLevelTests`: exhaustive kind × level border table; pixels == legacy for every kind at base/raised and for non-content kinds at elevated; elevated `.content` differs only at the border.

## Docs
`docs/components/toast.md`, `surface.md`, `card.md`, `float-button.md` (no change expected), `BREAKING-CHANGES.md`; preview host: danger + long-word toast entries for the three presentations.
