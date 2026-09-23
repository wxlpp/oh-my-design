import OSLog
import SwiftUI

// MARK: - TagGroupSelectionMode

/// `TagGroup` 的选择模式。
public nonisolated enum TagGroupSelectionMode: Hashable, Sendable, CaseIterable {
    /// 纯展示：标签不是按钮，不可聚焦；绑定里已选的项照样画出选中态。
    case none
    /// 单选：点未选项把数据内已选集合替换为该项，点已选项取消（允许空选）。
    case single
    /// 多选：点击逐项切换。
    case multiple
}

// MARK: - TagGroup

/// 基于 `Tag` + `FlowLayout` 的可选标签组（filter chips）。
///
/// 选中态的底色与描边从环境 `coreAccent` 派生；标签内容色由 `color` 决定，不随选中变化。
/// 选择只计当前 `data` 里存在的 ID：绑定里不在数据中的 ID 原样保留，组件永不增删它们。
/// 切换 `selectionMode` 不改写绑定；外部写入的多个数据内 ID 照样渲染，下一次点选才归一。
/// `data` 内的 ID 必须唯一；DEBUG 构建检测到重复时输出一条运行期警告。
public struct TagGroup<Data: RandomAccessCollection, ID: Hashable, Label: View>: View {
    // MARK: - Init

    /// 创建标签组。
    ///
    /// - Parameters:
    ///   - data: 标签数据源。
    ///   - id: 从元素取稳定 ID 的 key path；ID 在 `data` 内必须唯一。
    ///   - selection: 已选 ID 集合的双向绑定。
    ///   - selectionMode: 选择模式，默认 `.multiple`。
    ///   - disabled: 禁用的 ID 集合；禁用项不可切换，但已选时仍显示选中态。
    ///   - color: 标签内容色，同 `Tag(color:)`：驱动文字与未选态衬底。
    ///   - spacing: 标签之间与行之间的间距，默认 `CoreSpacing.xs`。
    ///   - label: 由元素生成标签主体，常为 `Text` 或 `Label`。
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<Set<ID>>,
        selectionMode: TagGroupSelectionMode = .multiple,
        disabled: Set<ID> = [],
        color: Color,
        spacing: CGFloat = CoreSpacing.xs,
        @ViewBuilder label: @escaping (Data.Element) -> Label
    ) {
        self.data = data
        self.id = id
        self._selection = selection
        self.selectionMode = selectionMode
        self.disabled = disabled
        self.color = color
        self.spacing = spacing
        self.label = label
    }

    @Binding private var selection: Set<ID>
    @Environment(\.coreAccent) private var resolvedAccent
    @Environment(\.coreMotionPresentation) private var motionPresentation

    public var body: some View {
        #if DEBUG
        let _ = TagGroupSelection.warnOnDuplicateIDs(self.data.map { $0[keyPath: self.id] })
        #endif
        FlowLayout(spacing: self.spacing) {
            ForEach(self.data, id: self.id) { element in
                self.item(element)
                    .transition(self.motionPresentation.collectionItemTransition)
            }
        }
        .animation(
            CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation),
            value: self.data.map { $0[keyPath: self.id] }
        )
        .coreAnimation(.selection, value: self.selection)
    }

    @ViewBuilder
    private func item(_ element: Data.Element) -> some View {
        let itemID = element[keyPath: self.id]
        let selected = self.selection.contains(itemID)
        let tag = Tag(color: self.color) { self.label(element) }
            .environment(\.tagSelectionChrome, selected ? self.selectedChrome : nil)
        switch self.selectionMode {
        case .none:
            tag
                .opacity(TagGroupItemButtonStyle.opacity(
                    isEnabled: !self.disabled.contains(itemID), isPressed: false
                ))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(TagGroupSelection.traits(selected: selected, mode: .none))
        case .single, .multiple:
            Button {
                self.toggle(itemID)
            } label: {
                tag.contentShape(TagGroupHitShape())
            }
            .buttonStyle(TagGroupItemButtonStyle())
            .disabled(self.disabled.contains(itemID))
            .accessibilityAddTraits(TagGroupSelection.traits(selected: selected, mode: self.selectionMode))
        }
    }

    private var selectedChrome: TagSelectionChrome {
        TagSelectionChrome(
            fill: .accentSubtleBackground(from: self.resolvedAccent),
            stroke: .accentSelectedBorder(from: self.resolvedAccent)
        )
    }

    private func toggle(_ itemID: ID) {
        self.selection = TagGroupSelection.toggled(
            itemID,
            in: self.selection,
            dataIDs: Set(self.data.map { $0[keyPath: self.id] }),
            disabled: self.disabled,
            mode: self.selectionMode
        )
    }

    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let selectionMode: TagGroupSelectionMode
    private let disabled: Set<ID>
    private let color: Color
    private let spacing: CGFloat
    private let label: (Data.Element) -> Label
}

// MARK: - Identifiable convenience init

public extension TagGroup where Data.Element: Identifiable, ID == Data.Element.ID {
    /// 以元素自身的 `id` 作标识的便利构造。
    ///
    /// - Parameters:
    ///   - data: 标签数据源，元素须 `Identifiable`。
    ///   - selection: 已选 ID 集合的双向绑定。
    ///   - selectionMode: 选择模式，默认 `.multiple`。
    ///   - disabled: 禁用的 ID 集合。
    ///   - color: 标签内容色。
    ///   - spacing: 标签间距，默认 `CoreSpacing.xs`。
    ///   - label: 由元素生成标签主体。
    init(
        _ data: Data,
        selection: Binding<Set<ID>>,
        selectionMode: TagGroupSelectionMode = .multiple,
        disabled: Set<ID> = [],
        color: Color,
        spacing: CGFloat = CoreSpacing.xs,
        @ViewBuilder label: @escaping (Data.Element) -> Label
    ) {
        self.init(
            data,
            id: \.id,
            selection: selection,
            selectionMode: selectionMode,
            disabled: disabled,
            color: color,
            spacing: spacing,
            label: label
        )
    }
}

// MARK: - 选择归约 / Selection reducer

enum TagGroupSelection {
    static func toggled<ID: Hashable>(
        _ id: ID,
        in selection: Set<ID>,
        dataIDs: Set<ID>,
        disabled: Set<ID>,
        mode: TagGroupSelectionMode
    ) -> Set<ID> {
        guard dataIDs.contains(id), !disabled.contains(id) else { return selection }
        switch mode {
        case .none:
            return selection
        case .multiple:
            return selection.symmetricDifference([id])
        case .single:
            let outside = selection.subtracting(dataIDs)
            return selection.contains(id) ? outside : outside.union([id])
        }
    }

    static func duplicateIDs<ID: Hashable>(_ ids: [ID]) -> Set<ID> {
        var seen: Set<ID> = []
        var duplicates: Set<ID> = []
        for id in ids where !seen.insert(id).inserted {
            duplicates.insert(id)
        }
        return duplicates
    }

    static func warnOnDuplicateIDs<ID: Hashable>(_ ids: [ID]) {
        let duplicates = Self.duplicateIDs(ids)
        guard !duplicates.isEmpty else { return }
        Self.logger.warning("TagGroup: IDs must be unique within data; duplicated: \(String(describing: duplicates), privacy: .public)")
    }

    private static let logger = Logger(subsystem: "OhMyDesign", category: "TagGroup")

    static func traits(selected: Bool, mode: TagGroupSelectionMode) -> AccessibilityTraits {
        let selectedTrait: AccessibilityTraits = selected ? .isSelected : []
        switch mode {
        case .none:
            return selectedTrait
        case .single, .multiple:
            return selectedTrait.union(.isButton)
        }
    }
}

// MARK: - 命中区 / Hit area

struct TagGroupHitShape: Shape {
    static let minimumSide: CGFloat = 44

    nonisolated func path(in rect: CGRect) -> Path {
        let dx = max(0, (Self.minimumSide - rect.width) / 2)
        let dy = max(0, (Self.minimumSide - rect.height) / 2)
        return Path(rect.insetBy(dx: -dx, dy: -dy))
    }
}

// MARK: - 按钮样式 / Item button style

struct TagGroupItemButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(Self.opacity(isEnabled: self.isEnabled, isPressed: configuration.isPressed))
    }

    static func opacity(isEnabled: Bool, isPressed: Bool) -> Double {
        guard isEnabled else { return 0.4 }
        return isPressed ? 0.7 : 1
    }
}

// MARK: - Preview

private struct TagGroupPreviewItem: Identifiable, Hashable {
    let id: String
}

private struct TagGroupPreviewContent: View {
    @State private var multiple: Set<String> = ["Swift", "Rust"]
    @State private var single: Set<String> = ["Weekly"]

    private let languages = ["Swift", "Kotlin", "Rust", "TypeScript", "Go", "Python"]
        .map(TagGroupPreviewItem.init(id:))
    private let ranges = ["Daily", "Weekly", "Monthly", "Yearly"].map(TagGroupPreviewItem.init(id:))

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            TagGroup(self.languages, selection: self.$multiple, disabled: ["Go"], color: .contentPrimary) {
                Text($0.id)
            }
            TagGroup(self.ranges, selection: self.$single, selectionMode: .single, color: .contentPrimary) {
                Text($0.id)
            }
            .coreAccent(.blue)
        }
        .padding(CoreSpacing.lg)
        .frame(width: 320)
    }
}

#Preview("TagGroup · light") {
    TagGroupPreviewContent()
        .preferredColorScheme(.light)
}

#Preview("TagGroup · dark") {
    TagGroupPreviewContent()
        .preferredColorScheme(.dark)
}
