import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - PR 1 合入态（b00dc03）的 Tree 原样拷贝 / Legacy copy
// 唯一改动：chevron 的 RTL 旋转与生产代码同步修正（本 PR 另修的缺陷，不属 .automatic 外观迁移）。

struct Legacy429Tree<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    // MARK: - Init
    init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        children: KeyPath<Data.Element, Data?>,
        expanded: Binding<Set<ID>>,
        selection: Binding<Set<ID>>,
        selectionMode: TreeSelectionMode = .single,
        checked: Binding<Set<ID>>? = nil,
        onActivate: ((ID) -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.children = children
        self._expanded = expanded
        self._selection = selection
        self.selectionMode = selectionMode
        self.checked = checked
        self.onActivate = onActivate
        self.content = content
    }

    @Binding private var expanded: Set<ID>
    @Binding private var selection: Set<ID>
    @State private var focus: ID?
    @State private var lastInteraction: TreeInteraction = .pointer
    @State private var pointerClaimsFocus = false
    @FocusState private var isFocused: Bool
    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let rows = self.visibleRows
        let metrics = TreeRowMetrics.resolve(self.controlSize)
        return VStack(alignment: .leading, spacing: metrics.rowSpacing) {
            Legacy429TreeBranch(data: self.data, level: 1, context: self.context(rows: rows, metrics: metrics))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Legacy429TreeNestedStyle())
        .focusable()
        .focused(self.$isFocused)
        .onKeyPress(phases: .down) { press in self.handle(press, rows: rows) }
        .onChange(of: rows) { oldRows, newRows in
            self.commit(TreeInteractionReducer.rowsChanged(state: self.interactionState, from: oldRows, to: newRows))
        }
        .onChange(of: self.isFocused) { _, focused in self.focusChanged(focused, rows: rows) }
        .coreAnimation(.selection, value: self.selection)
    }

    // MARK: - 交互接线 / Interaction wiring

    private var interactionState: TreeInteractionState<ID> {
        TreeInteractionState(
            focus: self.focus,
            lastInteraction: self.lastInteraction,
            selection: self.selection,
            expanded: self.expanded
        )
    }

    private func commit(_ next: TreeInteractionState<ID>, expansionMotion: MotionPresentation? = nil) {
        if next.focus != self.focus { self.focus = next.focus }
        if next.lastInteraction != self.lastInteraction { self.lastInteraction = next.lastInteraction }
        if next.selection != self.selection { self.selection = next.selection }
        if next.expanded != self.expanded {
            withAnimation(expansionMotion.flatMap(CoreMotionToken.treeExpansion(for:))) {
                self.expanded = next.expanded
            }
        }
    }

    private func handle(_ press: KeyPress, rows: [TreeRow<ID>]) -> KeyPress.Result {
        let outcome = TreeInteractionReducer.key(
            TreeKeyboard.key(for: press.key),
            modifiers: press.modifiers,
            state: self.interactionState,
            rows: rows,
            mode: self.selectionMode,
            activation: self.onActivate == nil ? .disabled : .enabled,
            motion: self.motionPresentation,
            treeIDs: { self.treeIDs },
            ancestors: self.ancestors(of:)
        )
        self.commit(outcome.state, expansionMotion: outcome.expansionMotion)
        if let activated = outcome.activated { self.onActivate?(activated) }
        return outcome.result
    }

    private func focusChanged(_ focused: Bool, rows: [TreeRow<ID>]) {
        let source: TreeInteraction = self.pointerClaimsFocus ? .pointer : .keyboard
        self.pointerClaimsFocus = false
        guard focused else { return }
        self.commit(TreeInteractionReducer.focusEntered(
            via: source, state: self.interactionState, rows: rows, ancestors: self.ancestors(of:)
        ))
    }

    private func select(_ id: ID, rows: [TreeRow<ID>]) {
        if !self.isFocused {
            self.pointerClaimsFocus = true
            self.isFocused = true
        }
        self.commit(TreeInteractionReducer.pointerSelect(
            id,
            state: self.interactionState,
            rowIDs: Set(rows.map(\.id)),
            mode: self.selectionMode,
            treeIDs: { self.treeIDs }
        ))
    }

    private func setExpansion(_ id: ID, to target: TreeExpansionTarget) {
        let outcome = TreeInteractionReducer.pointerExpansion(
            id, to: target, state: self.interactionState, motion: self.motionPresentation
        )
        self.commit(outcome.state, expansionMotion: outcome.expansionMotion)
    }

    // MARK: - 派生 / Derived

    private var visibleRows: [TreeRow<ID>] {
        TreeFlatten.rows(self.data, id: self.id, children: self.children, expanded: self.expanded)
    }

    private var treeIDs: Set<ID> {
        TreeFlatten.allIDs(self.data, id: self.id, children: self.children)
    }

    private func ancestors(of hidden: ID) -> [ID] {
        TreeFlatten.ancestorIDs(of: hidden, in: self.data, id: self.id, children: self.children)
    }

    private func context(rows: [TreeRow<ID>], metrics: TreeRowMetrics) -> Legacy429TreeContext<Data, ID, RowContent> {
        Legacy429TreeContext(
            id: self.id,
            children: self.children,
            expanded: self.expanded,
            selection: self.selection,
            checked: self.checked,
            focus: self.focus,
            metrics: metrics,
            showsFocusRing: TreeFocusing.showsRing(
                containerFocused: self.isFocused, lastInteraction: self.lastInteraction
            ),
            select: { id in self.select(id, rows: rows) },
            setExpansion: { id, target in self.setExpansion(id, to: target) },
            notePointerCheck: { self.commit(TreeInteractionReducer.pointerCheck(state: self.interactionState)) },
            content: self.content
        )
    }

    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let children: KeyPath<Data.Element, Data?>
    private let selectionMode: TreeSelectionMode
    private let checked: Binding<Set<ID>>?
    private let onActivate: ((ID) -> Void)?
    private let content: (Data.Element) -> RowContent
}

// MARK: - 递归上下文 / Recursion context

struct Legacy429TreeContext<Data: RandomAccessCollection, ID: Hashable, RowContent: View> {
    let id: KeyPath<Data.Element, ID>
    let children: KeyPath<Data.Element, Data?>
    let expanded: Set<ID>
    let selection: Set<ID>
    let checked: Binding<Set<ID>>?
    let focus: ID?
    let metrics: TreeRowMetrics
    let showsFocusRing: Bool
    let select: (ID) -> Void
    let setExpansion: (ID, TreeExpansionTarget) -> Void
    let notePointerCheck: () -> Void
    let content: (Data.Element) -> RowContent

    func expansion(of elementID: ID) -> Binding<Bool> {
        Binding(
            get: { self.expanded.contains(elementID) },
            set: { newValue in self.setExpansion(elementID, newValue ? .expanded : .collapsed) }
        )
    }

    func checkState(of leafID: ID, in checked: Binding<Set<ID>>) -> Binding<Bool> {
        Binding(
            get: { checked.wrappedValue.contains(leafID) },
            set: { newValue in
                self.notePointerCheck()
                checked.wrappedValue = TreeChecking.applying(
                    newValue, toLeaves: [leafID], in: checked.wrappedValue
                )
            }
        )
    }
}

// MARK: - 递归分支 / Recursive branch

struct Legacy429TreeBranch<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let data: Data
    let level: Int
    let context: Legacy429TreeContext<Data, ID, RowContent>

    var body: some View {
        ForEach(self.data, id: self.context.id) { element in
            if let kids = element[keyPath: self.context.children], !kids.isEmpty {
                DisclosureGroup(isExpanded: self.context.expansion(of: element[keyPath: self.context.id])) {
                    Legacy429TreeBranch(data: kids, level: self.level + 1, context: self.context)
                        .modifier(Legacy429TreeNestedStyle())
                } label: {
                    Legacy429TreeRowView(element: element, level: self.level, hasChildren: true, context: self.context)
                }
            } else {
                Legacy429TreeRowView(element: element, level: self.level, hasChildren: false, context: self.context)
            }
        }
    }
}

// MARK: - 逐层重施样式 / Per-level restyling

struct Legacy429TreeNestedStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.disclosureGroupStyle(Legacy429TreeDisclosureGroupStyle())
    }
}

// MARK: - Legacy429TreeDisclosureGroupStyle

struct Legacy429TreeDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: TreeRowMetrics.resolve(self.controlSize).rowSpacing) {
            configuration.label
            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 行 / Row

struct Legacy429TreeRowView<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let element: Data.Element
    let level: Int
    let hasChildren: Bool
    let context: Legacy429TreeContext<Data, ID, RowContent>

    @Environment(\.coreAccent) private var resolvedAccent

    var body: some View {
        let elementID = self.element[keyPath: self.context.id]
        let isExpanded = self.context.expanded.contains(elementID)
        let isSelected = self.context.selection.contains(elementID)
        let isFocused = self.context.showsFocusRing && self.context.focus == elementID
        return HStack(spacing: CoreSpacing.xs) {
            Legacy429TreeDisclosureControl(hasChildren: self.hasChildren, isExpanded: isExpanded, metrics: self.context.metrics) {
                self.context.setExpansion(elementID, isExpanded ? .collapsed : .expanded)
            }
            if let checked = self.context.checked {
                self.checkBox(checked)
            }
            self.context.content(self.element)
        }
        .padding(.horizontal, CoreSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: self.context.metrics.rowHeight)
        .background(
            CoreShape.rounded(CoreRadius.small)
                .fill(isSelected ? Color.accentSubtleBackground(from: self.resolvedAccent) : Color.clear)
        )
        .contentShape(Rectangle())
        .padding(.leading, CGFloat(self.level - 1) * self.context.metrics.indentation)
        .onTapGesture { self.context.select(elementID) }
        .focusRing(visible: isFocused, cornerRadius: CoreRadius.small)
        .accessibilityValue(self.expansionValue(isExpanded: isExpanded))
        .accessibilityAddTraits(TreeRowAccessibility.traits(isSelected: isSelected))
    }

    @ViewBuilder
    private func checkBox(_ checked: Binding<Set<ID>>) -> some View {
        let leaves = TreeFlatten.descendantLeafIDs(
            of: self.element, id: self.context.id, children: self.context.children
        )
        Toggle(
            sources: leaves.map { self.context.checkState(of: $0, in: checked) },
            isOn: \.self
        ) {
            EmptyView()
        }
        .toggleStyle(CheckBoxToggleStyle())
        .labelsHidden()
        .environment(
            \.checkBoxLayout,
            CheckBoxLayout(glyph: self.context.metrics.checkBoxGlyph, minHeight: self.context.metrics.rowHeight)
        )
    }

    private func expansionValue(isExpanded: Bool) -> Text {
        guard self.hasChildren else { return Text(verbatim: "") }
        return Text(
            LocalizedStringKey(TreeRowAccessibility.expansionValueKey(isExpanded: isExpanded)),
            bundle: .module
        )
    }
}

// MARK: - 展开控件 / Disclosure control

struct Legacy429TreeDisclosureControl: View {
    let hasChildren: Bool
    let isExpanded: Bool
    let metrics: TreeRowMetrics
    let toggle: () -> Void

    @Environment(\.coreMotionPresentation) private var motionPresentation

    var body: some View {
        let isExpanded = self.isExpanded
        if self.hasChildren {
            Button(action: self.toggle) {
                self.chevron
                    .rotationEffect(.degrees(self.chevronRotation(isExpanded: isExpanded)))
                    .animation(
                        CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation),
                        value: isExpanded
                    )
                    .modifier(Legacy429TreeDisclosureSlot(metrics: self.metrics))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(LocalizedStringKey(TreeRowAccessibility.chevronLabelKey(isExpanded: isExpanded)), bundle: .module)
            )
        } else {
            self.chevron
                .hidden()
                .modifier(Legacy429TreeDisclosureSlot(metrics: self.metrics))
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: self.metrics.chevronSize))
            .foregroundStyle(.tint)
    }

    private func chevronRotation(isExpanded: Bool) -> Double {
        isExpanded ? 90 : 0
    }
}

struct Legacy429TreeDisclosureSlot: ViewModifier {
    let metrics: TreeRowMetrics

    func body(content: Content) -> some View {
        content
            .frame(width: self.metrics.disclosureWidth, height: self.metrics.rowHeight)
            .contentShape(Rectangle())
    }
}


// MARK: - `.automatic` 与 PR 1 合入态逐像素一致

nonisolated struct TreeParityCase: CustomTestStringConvertible, Sendable {
    let expanded: Set<String>
    let selection: Set<String>
    let checked: Set<String>?
    let scheme: ColorScheme
    let size: ControlSize
    let direction: LayoutDirection

    var testDescription: String {
        "expanded=\(self.expanded.sorted()) selection=\(self.selection.sorted()) "
            + "checked=\(self.checked.map { $0.sorted().description } ?? "nil") \(self.scheme) \(self.size) \(self.direction)"
    }

    static let all: [TreeParityCase] = {
        var out: [TreeParityCase] = []
        for expanded: Set<String> in [[], ["a", "a1"]] {
            for selection: Set<String> in [[], ["a1x"]] {
                for checked: Set<String>? in [nil, ["a1x"]] {
                    for scheme: ColorScheme in [.light, .dark] {
                        for size: ControlSize in [.small, .regular] {
                            for direction: LayoutDirection in [.leftToRight, .rightToLeft] {
                                out.append(TreeParityCase(
                                    expanded: expanded, selection: selection, checked: checked,
                                    scheme: scheme, size: size, direction: direction
                                ))
                            }
                        }
                    }
                }
            }
        }
        return out
    }()
}

@Suite("Tree .automatic 与 PR 1 合入态（b00dc03）逐像素一致")
@MainActor
struct TreeAutomaticParityTests {
    private static func pixels(_ view: some View, _ sample: TreeParityCase) -> TreePixels {
        TreePixels.render(
            view.controlSize(sample.size).environment(\.layoutDirection, sample.direction),
            scheme: sample.scheme
        )
    }

    @Test("整棵树：展开 × 选中 × 复选框 × 明暗 × 档位 × 书写方向", arguments: TreeParityCase.all)
    func wholeTreeMatchesTheLegacyRendering(_ sample: TreeParityCase) {
        let legacy = Self.pixels(
            Legacy429Tree(
                TreeJudgeFixture.roots, id: \.id, children: \.children,
                expanded: .constant(sample.expanded), selection: .constant(sample.selection),
                selectionMode: .multiple, checked: sample.checked.map { Binding.constant($0) }
            ) { node in Text(verbatim: node.id) },
            sample
        )
        let current = Self.pixels(
            Tree(
                TreeJudgeFixture.roots, id: \.id, children: \.children,
                expanded: .constant(sample.expanded), selection: .constant(sample.selection),
                selectionMode: .multiple, checked: sample.checked.map { Binding.constant($0) }
            ) { node in Text(verbatim: node.id) }
                .treeStyle(.automatic),
            sample
        )
        #expect(current.height > 0 && current.height == legacy.height, "高度不同：新 \(current.height)px，旧 \(legacy.height)px")
        expectBitmapsEqual(current.bytes, legacy.bytes, "\(sample.testDescription)：.automatic 与 PR 1 合入态画得不一样")
    }

    @Test("单行：第 3 层、选中、焦点指示画在本行（整棵树的托管判据画不出焦点环）", arguments: [ColorScheme.light, .dark])
    func focusedSelectedThirdLevelRowMatchesTheLegacyRendering(_ scheme: ColorScheme) {
        let metrics = TreeRowMetrics.resolve(.regular)
        let legacy = TreePixels.render(
            Legacy429TreeRowView(
                element: TreeJudgeFixture.node("a1x"), level: 3, hasChildren: false,
                context: Legacy429TreeContext<[TreeJudgeNode], String, Text>(
                    id: \.id, children: \.children, expanded: [], selection: ["a1x"], checked: nil,
                    focus: "a1x", metrics: metrics, showsFocusRing: true,
                    select: { _ in }, setExpansion: { _, _ in }, notePointerCheck: {},
                    content: { Text(verbatim: $0.id) }
                )
            )
            .padding(8),
            scheme: scheme
        )
        let current = TreePixels.render(
            TreeRowHost(
                element: TreeJudgeFixture.node("a1x"), level: 3, hasChildren: false,
                context: TreeContext<[TreeJudgeNode], String, Text>(
                    id: \.id, children: \.children, expanded: [], selection: ["a1x"], checked: nil,
                    focus: "a1x", metrics: metrics, showsFocusIndicator: true,
                    select: { _ in }, setExpansion: { _, _ in }, notePointerCheck: {},
                    content: { Text(verbatim: $0.id) }
                )
            )
            .padding(8),
            scheme: scheme
        )
        expectBitmapsEqual(current.bytes, legacy.bytes, "\(scheme)：第 3 层选中 + 焦点行与 PR 1 合入态画得不一样")
    }
}
