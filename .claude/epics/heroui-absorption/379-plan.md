# Issue #379 plan — anchoredBadge modifier (PRD FR-8)

## Public API

```swift
public nonisolated enum AnchoredBadgeContent: Sendable, Equatable {
    case dot
    case count(Int, max: Int = 99)
    case text(String)
}

public nonisolated enum AnchoredBadgePlacement: Sendable, Equatable, CaseIterable {
    case topTrailing, topLeading, bottomTrailing, bottomLeading
}

public extension View {
    func anchoredBadge(
        _ content: AnchoredBadgeContent,
        placement: AnchoredBadgePlacement = .topTrailing
    ) -> some View
}
```

- `.count(n, max:)`: `n <= 0` hidden; `n > max` renders `"\(max)+"`.
- `.text("")` hidden (empty capsule carries no information).
- Colors: fill `statusDangerEmphasis`, foreground `contentOnEmphasis` (static, never reads accent / coreAccent).
- Placement maps to `Alignment` (`.topTrailing` …); badge center sits on the host's corner
  (overlay + `alignmentGuide` offset by half the badge size).
- Accessibility: badge view is `accessibilityHidden`; the host gets `accessibilityValue`:
  count → display string (`"99+"`), text → the text, dot → localized `"New"` (A-class chrome,
  `Text("New", bundle: .module)` + `en.lproj` key). Hidden content adds nothing.
- `.text(String)` is B-class caller copy, rendered verbatim (same as `Badge(_ text: String)`).
  Contract §4 recommends `LocalizedStringKey` for new B params; PRD FR-8 literally says
  `.text(String)` — PRD wins, tension reported for decision.

## Files

- `Sources/OhMyDesign/Modifier/AnchoredBadgeModifier.swift` — enums, internal `AnchoredBadgeModifier`, `View` extension, `#Preview`.
- `Sources/OhMyDesign/Resources/en.lproj/Localizable.strings` — `"New"`.
- `Tests/OhMyDesignTests/AnchoredBadgeTests.swift`.
- `docs/components/anchored-badge.md`; `docs/README.md` intro mention.
- `App/Sources/ComponentData.swift` (id `anchored-badge`) + `Previews.swift`.
- `docs/design-digest.md` + FLOORS (enums +2, enumcases +7, viewext +1 expected).

## Registration

Modifier struct is internal (the `SurfaceModifier` pattern), so per contract AD-2 there is no
public `View`/`ViewModifier` type to register ⇒ no `components[]` entry, no README table row
(a row would need a registry entry or an exclusion). Helper enums are not registered (same as
`SpinningPresentation`-style config enums outside the scanner). Func-side param is an enum,
not a bare `String` ⇒ `knownFunctionSideBareText` unchanged. No Bool parameters.

## Tests (Swift Testing, behavior)

1. `count(120, max: 99)` → `"99+"`; `count(99, max: 99)` → `"99"`; `count(0)` / `count(-3)` hidden.
2. `.dot` visible, no text; `.text("NEW")` → `"NEW"`; `.text("")` hidden.
3. placement → Alignment mapping for all four cases.
4. fill == `.statusDangerEmphasis`, foreground == `.contentOnEmphasis` (structural equality, no `resolve`).
5. accessibility value: count → `"99+"`, text → text, dot → non-nil, hidden → nil.
