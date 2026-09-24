# Issue #377 plan — Toast: title/description/action, ToastDuration, state machine

Contract: PRD FR-6 (`.claude/prds/heroui-absorption.md`).

## Files

- `Sources/OhMyDesign/Components/Toast/Toast.swift` — API + view.
- `Sources/OhMyDesign/Components/Toast/ToastClock.swift` (new, internal) — injectable clock
  (`ToastClock` protocol, `SystemToastClock`) used by `ToastHost`.
- `Sources/OhMyDesign/Components/Button/AsyncButton.swift` — call site follows the rename.
- Tests: `ToastHostTests.swift` (rewritten on a manual clock), `ToastActionConcurrencyTests.swift` (new),
  `ToastPresentationRenderTests.swift` (AX5 / action not truncated), `AsyncButtonTests.swift` (rename).
- Docs / ledgers: `docs/components/toast.md`, `docs/BREAKING-CHANGES.md`, `docs/component-registry.json`
  (Toast `textParams` + notes), `ComponentTextParamGuard` alias/buckets, `scripts/design-digest.py` output,
  `App/Sources/ComponentData.swift` + `Previews.swift`, `scripts/downstream-probe`.

## Public API (final)

```swift
public nonisolated struct ToastItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let level: StatusLevel
    public let duration: ToastDuration
    public let action: ToastAction?
    public init(id: UUID = UUID(), title: String, description: String? = nil,
                level: StatusLevel = .info, duration: ToastDuration = ToastDefaults.duration,
                action: ToastAction? = nil)
}

public nonisolated struct ToastAction: Sendable {
    public let label: String
    public init(_ label: String, action: @escaping @MainActor @Sendable () -> Void)
    @MainActor public func perform()
}

public nonisolated enum ToastDuration: Sendable, Equatable {
    case seconds(TimeInterval)   // <= 0 / NaN -> ToastDefaults default seconds
    case persistent              // blocks the queue until dismissed
}

public nonisolated enum ToastDefaults { public static let duration: ToastDuration = .seconds(3) }

@MainActor @Observable public final class ToastHost {
    public private(set) var queue: [ToastItem]
    public private(set) var isDismissing: Bool
    public init()
    public func show(_ title: String, description: String? = nil, level: StatusLevel = .info,
                     duration: ToastDuration = ToastDefaults.duration)
    public func show(_ item: ToastItem)
    public func dismiss(_ id: ToastItem.ID)
    public func dismissAll()
}
```

Internal: `ToastHost.init(clock:)`, `pause(_:)` / `resume(_:)` with a reason set (press, drag),
`performAction(of:)`. Display timer and exit timer are two distinct fields.

`seconds(.infinity)` is treated as `.persistent` (a non-finite sleep is not schedulable) — not
spelled out by the PRD; reported as a decision point.

## Tests (Swift Testing, manual clock, no real sleeps except one SystemToastClock smoke test)

1. show on empty starts displaying; show while displaying appends.
2. auto dismiss after duration -> dismissing -> exit wait -> advance; duration counts from display start.
3. non-positive / NaN seconds fall back to the default.
4. pause (press) freezes the timer; resume continues with the remaining time.
5. drag pause + press pause overlap: resumes only after both released; cancel path = resume.
6. `.persistent` never auto-dismisses and blocks the queue until dismissed.
7. `dismissAll()` while displaying / while dismissing / with a queue; `show` right after displays and
   auto-dismisses on its own timer (stale exit timer does not fire into the new item).
8. dismiss current / queued / unknown / repeated.
9. action: `performAction` runs the handler then dismisses; ToastItem with action built off the main
   actor (`Task.detached`), shown + performed on main (`MainActor.assertIsolated` inside the handler).
10. render: title + description + action renders for all presentations; AX5 action label not truncated
    (ink of the action text measured vs. its ideal width).

## Registry / ledgers

- Toast `textParams`: `message` -> `title` (B), + `description` (B), + `label` (B, `ToastAction`).
- `ComponentTextParamGuard.ownerAliases` + `ToastAction`; function-side bucket `ToastHost.show#message`
  -> `ToastHost.show#title` / `#description`.
- digest regenerated; counts reported old -> new.
