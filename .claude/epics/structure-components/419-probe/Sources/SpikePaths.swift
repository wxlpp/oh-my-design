import SwiftUI
import OhMyDesign

// MARK: - Row label

struct SpikeRowLabel: View {
    let node: SpikeNode
    let level: Int
    var focusBinding: FocusState<String?>.Binding?

    @Environment(SpikeState.self) private var state

    var body: some View {
        HStack(spacing: 6) {
            Text(self.node.name)
            if self.state.selection.contains(self.node.id) {
                Text("✓")
            }
        }
        .accessibilityIdentifier("row-\(self.node.id)")
        .background(self.state.focusedID == self.node.id ? Color.yellow.opacity(0.4) : Color.clear)
        .modifier(RowFocusable(id: self.node.id, focusBinding: self.focusBinding))
    }
}

// MARK: - Path A: recursive DisclosureGroup(isExpanded:)

struct DisclosureTreeView: View {
    let nodes: [SpikeNode]
    let level: Int
    var focusBinding: FocusState<String?>.Binding?

    @Environment(SpikeState.self) private var state

    var body: some View {
        ForEach(self.nodes) { node in
            if let kids = node.children {
                DisclosureGroup(isExpanded: self.state.binding(forExpanding: node.id)) {
                    DisclosureTreeView(nodes: kids, level: self.level + 1, focusBinding: self.focusBinding)
                        .modifier(NestedRestyle())
                } label: {
                    SpikeRowLabel(node: node, level: self.level, focusBinding: self.focusBinding)
                }
            } else {
                SpikeRowLabel(node: node, level: self.level, focusBinding: self.focusBinding)
            }
        }
    }
}

// MARK: - Path C: fully custom recursion

struct CustomTreeView: View {
    @Environment(SpikeState.self) private var state
    @FocusState private var focus: String?

    var rows: [SpikeTree.Row] { SpikeTree.visibleRows(expanded: self.state.expanded) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(self.rows) { row in
                HStack(spacing: 4) {
                    if row.node.isParent {
                        Text(self.state.expanded.contains(row.node.id) ? "▾" : "▸")
                    } else {
                        Text(" ")
                    }
                    SpikeRowLabel(node: row.node, level: row.level)
                }
                .padding(.leading, CGFloat(row.level - 1) * 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .focusable()
                .focused(self.$focus, equals: row.node.id)
            }
        }
        .onKeyPress(phases: .down) { press in self.handle(press) }
        .onChange(of: self.focus) { _, newValue in
            self.state.focusedID = newValue
            self.state.log("FOCUS", "focus=\(newValue ?? "<nil>")")
        }
        .onAppear {
            if self.focus == nil { self.focus = self.rows.first?.node.id }
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        TreeKeyHandler.handle(press, state: self.state, rows: self.rows, focus: { self.focus }, setFocus: { self.focus = $0 }, site: "C-custom")
    }

    private func unusedHandle(_ press: KeyPress) -> KeyPress.Result {
        let name = SpikeKey.name(press.key)
        let mods = press.modifiers
        let rows = self.rows
        let currentIndex = rows.firstIndex { $0.node.id == self.focus }

        func moveFocus(to index: Int, toggleSelect: Bool) {
            guard rows.indices.contains(index) else { return }
            let id = rows[index].node.id
            self.focus = id
            if toggleSelect { self.state.toggleSelection(id) }
        }

        switch name {
        case "downArrow":
            self.state.logKey(press, at: "C-custom", decision: "handled(down)")
            if let i = currentIndex { moveFocus(to: i + 1, toggleSelect: mods.contains(.shift)) }
            return .handled
        case "upArrow":
            self.state.logKey(press, at: "C-custom", decision: "handled(up)")
            if let i = currentIndex { moveFocus(to: i - 1, toggleSelect: mods.contains(.shift)) }
            return .handled
        case "rightArrow":
            self.state.logKey(press, at: "C-custom", decision: "handled(right)")
            guard let i = currentIndex else { return .handled }
            let row = rows[i]
            if row.node.isParent {
                if self.state.expanded.contains(row.node.id) {
                    moveFocus(to: i + 1, toggleSelect: false)
                } else {
                    self.state.binding(forExpanding: row.node.id).wrappedValue = true
                }
            }
            return .handled
        case "leftArrow":
            self.state.logKey(press, at: "C-custom", decision: "handled(left)")
            guard let i = currentIndex else { return .handled }
            let row = rows[i]
            if row.node.isParent, self.state.expanded.contains(row.node.id) {
                self.state.binding(forExpanding: row.node.id).wrappedValue = false
            } else if let parent = row.parentID {
                self.focus = parent
            }
            return .handled
        case "home":
            self.state.logKey(press, at: "C-custom", decision: "handled(home)")
            moveFocus(to: 0, toggleSelect: false)
            return .handled
        case "end":
            self.state.logKey(press, at: "C-custom", decision: "handled(end)")
            moveFocus(to: rows.count - 1, toggleSelect: false)
            return .handled
        case "space":
            self.state.logKey(press, at: "C-custom", decision: "handled(space)")
            if let id = self.focus { self.state.toggleSelection(id) }
            return .handled
        case "return":
            self.state.logKey(press, at: "C-custom", decision: "handled(return)")
            if let id = self.focus { self.state.activate(id) }
            return .handled
        default:
            if press.characters == "a", mods.contains(.control) || mods.contains(.command) {
                self.state.logKey(press, at: "C-custom", decision: "handled(selectAll)")
                self.state.selection = Set(SpikeTree.visibleRows(expanded: self.state.expanded).map(\.node.id))
                self.state.log("SELECT", "selectAll -> \(self.state.selection.sorted())")
                return .handled
            }
            if let ch = press.characters.first, ch.isLetter || ch.isNumber {
                self.state.logKey(press, at: "C-custom", decision: "handled(typeAhead)")
                self.state.typeAheadBuffer = String(ch)
                let start = (currentIndex ?? -1) + 1
                let order = Array(rows.indices[start...]) + Array(rows.indices[..<start])
                if let hit = order.first(where: { rows[$0].node.name.lowercased().hasPrefix(String(ch).lowercased()) }) {
                    moveFocus(to: hit, toggleSelect: false)
                }
                return .handled
            }
            self.state.logKey(press, at: "C-custom", decision: "ignored")
            return .ignored
        }
    }
}

// MARK: - Nested restyle probe

struct NestedRestyle: ViewModifier {
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.environment["SPIKE_RESTYLE_NESTED"] == "1" {
            content.disclosureGroupStyle(.core)
        } else {
            content
        }
    }
}

// MARK: - Shared key handler (W3C recommended model)

enum TreeKeyHandler {
    @MainActor
    static func handle(
        _ press: KeyPress,
        state: SpikeState,
        rows: [SpikeTree.Row],
        focus: () -> String?,
        setFocus: @escaping (String?) -> Void,
        site: String
    ) -> KeyPress.Result {
        let name = SpikeKey.name(press.key)
        let mods = press.modifiers
        let current = focus()
        let currentIndex = rows.firstIndex { $0.node.id == current }

        func moveFocus(to index: Int, toggleSelect: Bool) {
            guard rows.indices.contains(index) else { return }
            let id = rows[index].node.id
            setFocus(id)
            if toggleSelect { state.toggleSelection(id) }
        }

        switch name {
        case "downArrow":
            state.logKey(press, at: site, decision: "handled(down)")
            if let i = currentIndex { moveFocus(to: i + 1, toggleSelect: mods.contains(.shift)) }
            return .handled
        case "upArrow":
            state.logKey(press, at: site, decision: "handled(up)")
            if let i = currentIndex { moveFocus(to: i - 1, toggleSelect: mods.contains(.shift)) }
            return .handled
        case "rightArrow":
            state.logKey(press, at: site, decision: "handled(right)")
            guard let i = currentIndex else { return .handled }
            let row = rows[i]
            if row.node.isParent {
                if state.expanded.contains(row.node.id) {
                    moveFocus(to: i + 1, toggleSelect: false)
                } else {
                    state.binding(forExpanding: row.node.id).wrappedValue = true
                }
            }
            return .handled
        case "leftArrow":
            state.logKey(press, at: site, decision: "handled(left)")
            guard let i = currentIndex else { return .handled }
            let row = rows[i]
            if row.node.isParent, state.expanded.contains(row.node.id) {
                state.binding(forExpanding: row.node.id).wrappedValue = false
            } else if let parent = row.parentID {
                setFocus(parent)
            }
            return .handled
        case "home":
            state.logKey(press, at: site, decision: "handled(home)")
            moveFocus(to: 0, toggleSelect: false)
            return .handled
        case "end":
            state.logKey(press, at: site, decision: "handled(end)")
            moveFocus(to: rows.count - 1, toggleSelect: false)
            return .handled
        case "space":
            state.logKey(press, at: site, decision: "handled(space)")
            if let id = current { state.toggleSelection(id) }
            return .handled
        case "return":
            state.logKey(press, at: site, decision: "handled(return)")
            if let id = current { state.activate(id) }
            return .handled
        default:
            if press.characters.lowercased() == "a", mods.contains(.control) || mods.contains(.command) {
                state.logKey(press, at: site, decision: "handled(selectAll)")
                state.selection = Set(rows.map(\.node.id))
                state.log("SELECT", "selectAll -> \(state.selection.sorted())")
                return .handled
            }
            if let ch = press.characters.first, ch.isLetter || ch.isNumber {
                state.logKey(press, at: site, decision: "handled(typeAhead)")
                state.typeAheadBuffer = String(ch)
                let start = (currentIndex ?? -1) + 1
                let order = Array(rows.indices[start...]) + Array(rows.indices[..<start])
                if let hit = order.first(where: { rows[$0].node.name.lowercased().hasPrefix(String(ch).lowercased()) }) {
                    moveFocus(to: hit, toggleSelect: false)
                }
                return .handled
            }
            state.logKey(press, at: site, decision: "ignored")
            return .ignored
        }
    }
}

// MARK: - Per-row focusability for the A-keys pane

struct RowFocusable: ViewModifier {
    let id: String
    var focusBinding: FocusState<String?>.Binding?

    func body(content: Content) -> some View {
        if let binding = self.focusBinding {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .focusable()
                .focused(binding, equals: self.id)
        } else {
            content
        }
    }
}

// MARK: - A-keys: recursive DisclosureGroup + the shared W3C key layer

struct DisclosureKeysPane: View {
    @Environment(SpikeState.self) private var state
    @FocusState private var focus: String?

    var rows: [SpikeTree.Row] { SpikeTree.visibleRows(expanded: self.state.expanded) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                DisclosureTreeView(nodes: SpikeTree.roots, level: 1, focusBinding: self.$focus)
                    .modifier(NestedRestyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .disclosureGroupStyle(.core)
        }
        .onKeyPress(phases: .down) { press in
            TreeKeyHandler.handle(press, state: self.state, rows: self.rows, focus: { self.focus }, setFocus: { self.focus = $0 }, site: "A-keys")
        }
        .onChange(of: self.focus) { _, newValue in
            self.state.focusedID = newValue
            self.state.log("FOCUS", "focus=\(newValue ?? "<nil>")")
        }
        .onAppear {
            self.focus = self.rows.first?.node.id
        }
    }
}
