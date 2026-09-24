import SwiftUI

// MARK: - 交互状态 / Interaction state

nonisolated struct TreeInteractionState<ID: Hashable>: Equatable {
    var focus: ID?
    var lastInteraction: TreeInteraction
    var selection: Set<ID>
    var expansion: TreeExpansionState<ID>

    var expanded: Set<ID> { self.expansion.effective }

    init(focus: ID?, lastInteraction: TreeInteraction, selection: Set<ID>, expansion: TreeExpansionState<ID>) {
        self.focus = focus
        self.lastInteraction = lastInteraction
        self.selection = selection
        self.expansion = expansion
    }

    init(focus: ID?, lastInteraction: TreeInteraction, selection: Set<ID>, expanded: Set<ID>) {
        self.init(
            focus: focus, lastInteraction: lastInteraction, selection: selection,
            expansion: TreeExpansionState(persisted: expanded)
        )
    }
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
            next.focus = nil
            return TreeInteractionOutcome(state: next, result: .ignored)
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
            next.expansion.set(id, to: .expanded)
            expansionMotion = motion
        case .collapse(let id):
            next.expansion.set(id, to: .collapsed)
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

    static func pointerClick<ID: Hashable>(
        _ id: ID,
        behavior: TreeRowClickBehavior,
        state: TreeInteractionState<ID>,
        rows: [TreeRow<ID>],
        mode: TreeSelectionMode,
        motion: MotionPresentation,
        treeIDs: () -> Set<ID>
    ) -> TreeInteractionOutcome<ID> {
        guard let row = rows.first(where: { $0.id == id }) else { return TreeInteractionOutcome(state: state, result: .ignored) }
        let rowIDs = Set(rows.map(\.id))
        guard behavior == .selectAndToggleExpansion, row.hasChildren else {
            return TreeInteractionOutcome(
                state: Self.pointerSelect(id, state: state, rowIDs: rowIDs, mode: mode, treeIDs: treeIDs), result: .handled
            )
        }
        var next = state
        next.focus = id
        next.lastInteraction = .pointer
        switch mode {
        case .single:
            next.selection = TreeSelection.replacing(with: id, in: state.selection, treeIDs: treeIDs())
        case .multiple:
            next.selection = TreeSelection.toggled(id, in: state.selection, rowIDs: rowIDs, treeIDs: treeIDs(), mode: mode)
        }
        next.expansion.set(id, to: state.expanded.contains(id) ? .collapsed : .expanded)
        return TreeInteractionOutcome(state: next, result: .handled, expansionMotion: motion)
    }

    static func pointerToggle<ID: Hashable>(
        _ id: ID,
        state: TreeInteractionState<ID>,
        rows: [TreeRow<ID>],
        motion: MotionPresentation
    ) -> TreeInteractionOutcome<ID> {
        guard rows.contains(where: { $0.id == id }) else { return TreeInteractionOutcome(state: state, result: .ignored) }
        return Self.pointerExpansion(
            id, to: state.expanded.contains(id) ? .collapsed : .expanded, state: state, motion: motion
        )
    }

    static func pointerExpansion<ID: Hashable>(
        _ id: ID,
        to target: TreeExpansionTarget,
        state: TreeInteractionState<ID>,
        motion: MotionPresentation
    ) -> TreeInteractionOutcome<ID> {
        var next = state
        next.lastInteraction = .pointer
        next.expansion.set(id, to: target)
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

extension TreeExpansionState {
    nonisolated mutating func set(_ id: ID, to target: TreeExpansionTarget) {
        switch target {
        case .expanded: self.expand(id)
        case .collapsed: self.collapse(id)
        }
    }
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
