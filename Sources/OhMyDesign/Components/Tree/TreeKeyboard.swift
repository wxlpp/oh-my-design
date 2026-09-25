import SwiftUI

// MARK: - TreeKey

nonisolated enum TreeKey: Hashable, Sendable {
    case up
    case down
    case left
    case right
    case home
    case end
    case space
    case enter
    case character(Character)
}

// MARK: - TreeKeyAction

nonisolated enum TreeKeyAction<ID: Hashable>: Equatable {
    case moveFocus(ID)
    case moveFocusAndToggleSelection(ID)
    case expand(ID)
    case collapse(ID)
    case toggleSelection(ID)
    case toggleCheck(ID)
    case activate(ID)
    case selectAllVisible
    case doNothing
    case unhandled
}

// MARK: - TreeCheckColumn

nonisolated enum TreeCheckColumn: Hashable, Sendable {
    case present
    case absent
}

// MARK: - TreeKeyboard

nonisolated enum TreeKeyboard {
    static func key(for key: KeyEquivalent) -> TreeKey {
        switch key.character {
        case KeyEquivalent.upArrow.character: .up
        case KeyEquivalent.downArrow.character: .down
        case KeyEquivalent.leftArrow.character: .left
        case KeyEquivalent.rightArrow.character: .right
        case KeyEquivalent.home.character: .home
        case KeyEquivalent.end.character: .end
        case KeyEquivalent.space.character: .space
        case KeyEquivalent.return.character: .enter
        default: .character(key.character)
        }
    }

    // 白名单取交集，不要改成 `modifiers.isEmpty`：macOS 方向键自带 `.numericPad | .function`。
    static func selectionModifiers(_ modifiers: EventModifiers) -> EventModifiers {
        modifiers.intersection([.shift, .control, .option, .command])
    }

    static func action<ID: Hashable>(
        for key: TreeKey,
        modifiers: EventModifiers,
        rows: [TreeRow<ID>],
        focus: ID,
        expanded: Set<ID>,
        mode: TreeSelectionMode,
        checkColumn: TreeCheckColumn = .absent
    ) -> TreeKeyAction<ID> {
        let pressed = Self.selectionModifiers(modifiers)
        guard let index = rows.firstIndex(where: { $0.id == focus }) else { return .unhandled }
        let row = rows[index]

        switch key {
        case .down, .up:
            guard pressed.isEmpty || pressed == .shift else { return .unhandled }
            let target = key == .down ? index + 1 : index - 1
            guard rows.indices.contains(target) else { return .doNothing }
            if pressed == .shift {
                return mode == .multiple
                    ? .moveFocusAndToggleSelection(rows[target].id)
                    : .moveFocus(rows[target].id)
            }
            return .moveFocus(rows[target].id)

        case .right:
            guard pressed.isEmpty else { return .unhandled }
            guard row.hasChildren else { return .doNothing }
            guard expanded.contains(row.id) else { return .expand(row.id) }
            guard rows.indices.contains(index + 1) else { return .doNothing }
            return .moveFocus(rows[index + 1].id)

        case .left:
            guard pressed.isEmpty else { return .unhandled }
            if row.hasChildren, expanded.contains(row.id) { return .collapse(row.id) }
            guard let parent = row.parent else { return .doNothing }
            return .moveFocus(parent)

        case .home:
            guard pressed.isEmpty, let first = rows.first else { return .unhandled }
            return .moveFocus(first.id)

        case .end:
            guard pressed.isEmpty, let last = rows.last else { return .unhandled }
            return .moveFocus(last.id)

        case .space:
            if pressed == .option {
                return checkColumn == .present ? .toggleCheck(row.id) : .unhandled
            }
            guard pressed.isEmpty else { return .unhandled }
            return .toggleSelection(row.id)

        case .enter:
            guard pressed.isEmpty else { return .unhandled }
            return .activate(row.id)

        case .character(let character):
            let selectsAll = pressed.contains(.control) || pressed.contains(.command)
            guard String(character).lowercased() == "a", selectsAll else { return .unhandled }
            return mode == .multiple ? .selectAllVisible : .unhandled
        }
    }
}
