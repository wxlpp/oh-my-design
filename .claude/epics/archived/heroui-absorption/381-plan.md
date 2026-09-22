# Issue #381 plan — `.coreCircular` + pressable ButtonStyles (FR-10, FR-11)

## Files

- `Sources/OhMyDesign/Components/Style/CoreCircularProgressViewStyle.swift` (new)
- `Sources/OhMyDesign/Components/Button/styles/PressableButtonStyles.swift` (new; row + card)
- `Tests/OhMyDesignTests/CoreCircularProgressViewStyleTests.swift` (new)
- `Tests/OhMyDesignTests/PressableButtonStyleTests.swift` (new)
- `Tests/OhMyDesignTests/CoreControlStyleTintTests.swift` (add `.coreCircular` tint pixel case)
- `Tests/OhMyDesignTests/ComponentRegistryGuard.swift` (`knownStyleAnnotationRows`: add the new style types to README style-annotation rows — tightens, not loosens)
- docs: `docs/components/core-control-styles.md` (+ `.coreCircular` section), `docs/components/pressable-button-styles.md` (new, states the intentional exception to 《按钮样式模式》), `docs/README.md` (index rows), `CLAUDE.md` 《按钮样式模式》 one sentence
- `docs/design-digest.md` regenerated via `scripts/design-digest.py` (+FLOORS)
- App: `App/Sources/ComponentData.swift` (two gallery entries), `App/Sources/Previews.swift`

## Public API

```swift
public struct CoreCircularProgressViewStyle: ProgressViewStyle { public init() }
public extension ProgressViewStyle where Self == CoreCircularProgressViewStyle {
    static var coreCircular: CoreCircularProgressViewStyle { get }
}
public struct PressableRowButtonStyle: ButtonStyle { public init() }
public struct PressableCardButtonStyle: ButtonStyle { public init() }
public extension ButtonStyle where Self == PressableRowButtonStyle { static var pressableRow: PressableRowButtonStyle { get } }
public extension ButtonStyle where Self == PressableCardButtonStyle { static var pressableCard: PressableCardButtonStyle { get } }
```

No Bool inputs; no role; no controlSize-driven layout.

## Behaviour

- `.coreCircular`: determinate → track circle (`surfaceCanvasInset`) + trimmed arc filled via `.tint`, starts at 12 o'clock, clamped 0…1; diameter from `CoreControlMetrics.height(for: controlSize)` (ring size only, the ring is the style's own glyph); stroke `CoreSpacing.xs`. `fractionCompleted == nil` → system `.circular` (explicit, no recursion). A11y: combined element + percent value, same as `.core`.
- `.pressableRow`: label + full-rect content shape; pressed && enabled → `Color.pressedBackground` behind the label. Disabled → opacity 0.4 (existing button-style precedent), no pressed fill.
- `.pressableCard`: pressed && enabled → `scaleEffect(CoreButtonMetrics.pressedScale)`; under reduce motion → no scale, opacity dim instead. Disabled → opacity 0.4, no feedback.
- Resolution logic lives in internal pure helpers so tests can assert pressed/enabled/reduce-motion combinations directly (ButtonStyle `Configuration` is not constructible).

## Tests (Swift Testing, behaviour)

- circular: `.tint(.red)` vs `.tint(.blue)` arc pixels; tinted pixel count grows with fraction (0.25 < 0.75); out-of-range clamp; nil renders fallback (no track ring).
- pressable: helper truth tables (row fill, card scale/opacity incl. reduce motion, disabled); rendered size of label wrapped by the style body equals bare label size (does not change layout); row pressed render differs from unpressed.

## Registry / guards

Style implementations do not enter `components[]` (contract). README style-annotation rows get the new types registered in `knownStyleAnnotationRows`. Digest FLOORS updated by real delta. MainActor exemptions must not grow.
