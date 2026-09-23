import SwiftUI

// MARK: - 交互状态 / Interaction state

nonisolated struct TreeInteractionState<ID: Hashable>: Equatable {
    var focus: ID?
    var lastInteraction: TreeInteraction
    var selection: Set<ID>
    var expanded: Set<ID>
}

nonisolated struct TreeInteractionOutcome<ID: Hashable>: Equatable {
    var state: TreeInteractionState<ID>
    var result: KeyPress.Result
    var expansionMotion: MotionPresentation?
    var activated: ID?
}

// MARK: - 交互归约 / Interaction reducer

nonisolated enum TreeInteractionReducer {
    static func key<ID: Hashable>(
        _ key: TreeKey,
        modifiers: EventModifiers,
        state: TreeInteractionState<ID>,
        rows: [TreeRow<ID>],
        mode: TreeSelectionMode,
        activation: TreeActivation,
        motion: MotionPresentation,
        treeIDs: () -> Set<ID>,
        ancestors: (ID) -> [ID]
    ) -> TreeInteractionOutcome<ID> {
        var next = state
        guard let focused = TreeFocusing.effective(
            state.focus, visibleRows: rows, selection: state.selection, ancestors: ancestors
        ) else {
            return TreeInteractionOutcome(state: state, result: .ignored)
        }
        next.focus = focused
        let action = TreeKeyboard.action(
            for: key, modifiers: modifiers, rows: rows, focus: focused, expanded: state.expanded, mode: mode
        )
        let rowIDs = Set(rows.map(\.id))
        var expansionMotion: MotionPresentation?
        var activated: ID?
        switch action {
        case .unhandled:
            return TreeInteractionOutcome(state: next, result: .ignored)
        case .doNothing:
            break
        case .moveFocus(let id):
            next.focus = id
        case .moveFocusAndToggleSelection(let id):
            next.focus = id
            next.selection = TreeSelection.toggled(
                id, in: next.selection, rowIDs: rowIDs, treeIDs: treeIDs(), mode: mode
            )
        case .expand(let id):
            next.expanded = Self.expansion(id, to: .expanded, in: next.expanded)
            expansionMotion = motion
        case .collapse(let id):
            next.expanded = Self.expansion(id, to: .collapsed, in: next.expanded)
            expansionMotion = motion
        case .toggleSelection(let id):
            next.selection = TreeSelection.toggled(
                id, in: next.selection, rowIDs: rowIDs, treeIDs: treeIDs(), mode: mode
            )
        case .activate(let id):
            guard activation == .enabled else { return TreeInteractionOutcome(state: next, result: .ignored) }
            activated = id
        case .selectAllVisible:
            next.selection = TreeSelection.selectingAll(in: next.selection, rowIDs: rows.map(\.id))
        }
        next.lastInteraction = .keyboard
        return TreeInteractionOutcome(state: next, result: .handled, expansionMotion: expansionMotion, activated: activated)
    }

    static func pointerSelect<ID: Hashable>(
        _ id: ID,
        state: TreeInteractionState<ID>,
        rowIDs: Set<ID>,
        mode: TreeSelectionMode,
        treeIDs: () -> Set<ID>
    ) -> TreeInteractionState<ID> {
        var next = state
        next.focus = id
        next.lastInteraction = .pointer
        next.selection = TreeSelection.toggled(id, in: state.selection, rowIDs: rowIDs, treeIDs: treeIDs(), mode: mode)
        return next
    }

    static func pointerExpansion<ID: Hashable>(
        _ id: ID,
        to target: TreeExpansionTarget,
        state: TreeInteractionState<ID>,
        motion: MotionPresentation
    ) -> TreeInteractionOutcome<ID> {
        var next = state
        next.lastInteraction = .pointer
        next.expanded = Self.expansion(id, to: target, in: state.expanded)
        return TreeInteractionOutcome(state: next, result: .handled, expansionMotion: motion)
    }

    static func pointerCheck<ID: Hashable>(state: TreeInteractionState<ID>) -> TreeInteractionState<ID> {
        var next = state
        next.lastInteraction = .pointer
        return next
    }

    static func focusEntered<ID: Hashable>(
        via source: TreeInteraction,
        state: TreeInteractionState<ID>,
        rows: [TreeRow<ID>],
        ancestors: (ID) -> [ID]
    ) -> TreeInteractionState<ID> {
        guard source == .keyboard else { return state }
        var next = state
        next.lastInteraction = .keyboard
        next.focus = TreeFocusing.effective(state.focus, visibleRows: rows, selection: state.selection, ancestors: ancestors)
        return next
    }

    static func rowsChanged<ID: Hashable>(
        state: TreeInteractionState<ID>,
        from oldRows: [TreeRow<ID>],
        to newRows: [TreeRow<ID>]
    ) -> TreeInteractionState<ID> {
        guard state.focus != nil else { return state }
        var next = state
        next.focus = TreeFocusing.effective(state.focus, visibleRows: newRows, selection: state.selection) { hidden in
            TreeFocusing.ancestors(of: hidden, in: oldRows)
        }
        return next
    }

    static func expansion<ID: Hashable>(
        _ id: ID,
        to target: TreeExpansionTarget,
        in expanded: Set<ID>
    ) -> Set<ID> {
        var state = TreeExpansionState(persisted: expanded)
        switch target {
        case .expanded: state.expand(id)
        case .collapsed: state.collapse(id)
        }
        return state.persisted
    }
}

extension TreeInteractionOutcome {
    nonisolated init(state: TreeInteractionState<ID>, result: KeyPress.Result) {
        self.init(state: state, result: result, expansionMotion: nil, activated: nil)
    }

    nonisolated init(state: TreeInteractionState<ID>, result: KeyPress.Result, expansionMotion: MotionPresentation?) {
        self.init(state: state, result: result, expansionMotion: expansionMotion, activated: nil)
    }
}

nonisolated enum TreeExpansionTarget: Hashable, Sendable {
    case expanded
    case collapsed
}

nonisolated enum TreeActivation: Hashable, Sendable {
    case enabled
    case disabled
}

// MARK: - 右键菜单目标 / Context-menu targets

nonisolated enum TreeContextMenu {
    static func targets<ID: Hashable>(for id: ID, selection: Set<ID>, visibleIDs: Set<ID>) -> Set<ID> {
        Self.targets(for: id, selectedVisible: Self.selectedVisible(selection, visibleIDs: visibleIDs))
    }

    static func selectedVisible<ID: Hashable>(_ selection: Set<ID>, visibleIDs: Set<ID>) -> Set<ID> {
        selection.intersection(visibleIDs)
    }

    static func targets<ID: Hashable>(for id: ID, selectedVisible: Set<ID>) -> Set<ID> {
        selectedVisible.contains(id) ? selectedVisible : [id]
    }
}
