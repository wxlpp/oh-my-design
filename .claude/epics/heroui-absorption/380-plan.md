# Issue #380 plan — TagGroup (PRD FR-9)

## Public API

```swift
public nonisolated enum TagGroupSelectionMode: Hashable, Sendable, CaseIterable {
    case none, single, multiple
}

public struct TagGroup<Data: RandomAccessCollection, ID: Hashable, Label: View>: View {
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<Set<ID>>,
        selectionMode: TagGroupSelectionMode = .multiple,
        disabled: Set<ID> = [],
        color: Color,
        spacing: CGFloat = CoreSpacing.xs,
        @ViewBuilder label: @escaping (Data.Element) -> Label
    )
}

public extension TagGroup where Data.Element: Identifiable, ID == Data.Element.ID {
    init(_ data: Data, selection:, selectionMode:, disabled:, color:, spacing:, label:)
}
```

- `color` is the caller's content colour, forwarded to `Tag` unchanged (drives the label
  foreground and the unselected 12 % tint). Selection never recolours the label.
- Selected chrome: fill `Color.accentSubtleBackground(from: coreAccent)`, 2pt (`CoreBorderWidth.thick`) stroke
  `Color.accentSelectedBorder(from: coreAccent)` (new derivation in `InteractionColors.swift`;
  static `borderSelected` rewired to it so both share one source). `coreAccent` read from the
  environment (`resolvedAccent`).
- Selection is rendered in every mode (the binding is the truth; the mode only governs input).
  `.none`: tags are plain views (no button, no focus); a selected one still carries
  `.isSelected` so VoiceOver reads the state it shows.
- Disabled items: `.disabled(true)` on the button, 0.4 opacity, selection chrome still drawn.

## Selection reducer (internal, pure, `nonisolated static`)

`TagGroupSelection.toggled(_ id, in selection, dataIDs, disabled, mode) -> Set<ID>`
- `.none`, `id ∉ dataIDs`, `id ∈ disabled` → unchanged.
- `.multiple` → symmetric toggle of `id`.
- `.single`: `id` selected → `selection − dataIDs` (clears the in-data selection, which
  normalises an externally written multi-selection); `id` unselected → `(selection − dataIDs) ∪ {id}`.
- Unknown IDs (`selection − dataIDs`) are never touched. Changing the mode never writes.

## Hit area

Internal `Shape` `TagGroupHitShape`: path = rect expanded vertically to ≥ 44pt tall, used as
`contentShape` on each button. Layout size stays the Tag's (no row growth). Known limit: with the
default 4pt row spacing, adjacent rows' expanded hit areas overlap; the later row wins there.

## Files

- `Sources/OhMyDesign/Components/TagGroup/TagGroup.swift` — enum, view, reducer, hit shape, `#Preview`.
- `Sources/OhMyDesign/Components/Tag/Tag.swift` — internal `@Entry tagSelectionChrome` read by
  `Tag.body` (fill replaces the tint, stroke overlay), so radius/size stay single-sourced.
- `Sources/OhMyDesign/Colors/InteractionColors.swift` / `BorderColors.swift` — `accentSelectedBorder(from:)`.
- `Tests/OhMyDesignTests/TagGroupTests.swift`.
- `docs/components/tag-group.md`, `docs/README.md` row, `docs/component-registry.json`,
  `docs/design-digest.md` (+ FLOORS), `App/Sources/ComponentData.swift` (id `tag-group`).

## Tests

1. Reducer: multiple toggle; single select replaces only in-data IDs; single tap-selected clears;
   external multi-selection normalised on next tap; unknown IDs preserved in every path;
   disabled / `.none` / unknown `id` → unchanged.
2. Mode switch does not write the binding (host harness: render with `.multiple`, switch to
   `.single` / `.none`, binding unchanged).
3. Render: selected vs unselected differ; selected differs under `.coreAccent(.red)` vs `.green`
   (both schemes, macOS-resolvable system colours); unselected identical under the two accents.
4. Disabled + selected renders the selected chrome (differs from disabled + unselected).
5. Hit shape: height ≥ 44 for 18/24/32pt rects, unchanged for 50pt; layout height of the group
   equals the plain `FlowLayout` of `Tag`s (visual not inflated).
6. Accessibility traits helper: button + selected in single/multiple, not button in `.none`.

## Registration

`components[]` entry `TagGroup`: contract §1 walk (grandfather / deprecation no; step 1 none;
step 2 enumeration with sources, sibling-scope exclusions, landing noted in notes).
`textParams`: none (labels come from the caller's `@ViewBuilder`). Digest / FLOORS by real values.
