import Testing
import SwiftUI
@testable import OhMyDesign

#if os(iOS)
@Suite("触控目标 ≥ 44pt")
@MainActor
struct TouchTargetTests {
    private static let minimumHitTarget: CGFloat = 44

    private func renderedHeight<V: View>(_ view: V, width: CGFloat? = 320) -> CGFloat {
        let content: AnyView = if let width {
            AnyView(view.frame(width: width))
        } else {
            AnyView(view)
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // MARK: - Button 四种 style

    @Test("SolidButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func solidButtonMeetsMinimumTouchTarget() {
        let button = Button("Save") {}
            .buttonStyle(.solid(role: .primary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "SolidButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("LightButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func lightButtonMeetsMinimumTouchTarget() {
        let button = Button("Cancel") {}
            .buttonStyle(.light(role: .secondary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "LightButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("CoreBorderlessButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func borderlessButtonMeetsMinimumTouchTarget() {
        let button = Button("Learn more") {}
            .buttonStyle(.borderless(role: .primary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "CoreBorderlessButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("CircularGlassButtonStyle 默认档（.large）与显式 .regular 档均实测 ≥ 44pt")
    func circularGlassButtonMeetsMinimumTouchTarget() {
        let defaultButton = Button {} label: {
            Image(systemName: "paperplane")
        }
        .buttonStyle(.circularGlass)
        let regularButton = Button {} label: {
            Image(systemName: "paperplane")
        }
        .buttonStyle(.circularGlass(size: .regular))

        let defaultHeight = self.renderedHeight(defaultButton, width: nil)
        let regularHeight = self.renderedHeight(regularButton, width: nil)
        #expect(defaultHeight >= Self.minimumHitTarget, "CircularGlassButtonStyle 默认档实测高度 \(defaultHeight)pt < 44pt")
        #expect(regularHeight >= Self.minimumHitTarget, "CircularGlassButtonStyle .regular 档实测高度 \(regularHeight)pt < 44pt")
    }

    // MARK: - SearchField

    @Test("SearchField 在 .regular 档实测命中高度 ≥ 44pt")
    func searchFieldMeetsMinimumTouchTarget() {
        let field = SearchField(text: .constant(""))
        let height = self.renderedHeight(field)
        #expect(height >= Self.minimumHitTarget, "SearchField 实测高度 \(height)pt < 44pt")
    }

    // MARK: - ListRow

    @Test("ListRow 在 .regular 档实测命中高度 ≥ 44pt")
    func listRowMeetsMinimumTouchTarget() {
        let row = ListRow {
            Text("All issues")
        }
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "ListRow 实测高度 \(height)pt < 44pt")
    }

    // MARK: - Tree 行

    @Test("Tree 行在每一档实测命中高度 ≥ 44pt（密度只缩字形与缩进，不缩行距）", arguments: ControlSize.allCases)
    func treeRowMeetsMinimumTouchTarget(size: ControlSize) {
        let tree = Tree(
            [TreeJudgeNode(id: "leaf", children: nil)],
            children: \TreeJudgeNode.children,
            expanded: .constant([]),
            selection: .constant([])
        ) { node in
            Text(verbatim: node.id)
        }
        .controlSize(size)
        let height = self.renderedHeight(tree)
        #expect(height >= Self.minimumHitTarget, "\(size)：Tree 行实测高度 \(height)pt < 44pt")
    }

    @Test("带复选框的 Tree 行在每一档实测命中高度 ≥ 44pt", arguments: ControlSize.allCases)
    func treeCheckBoxRowMeetsMinimumTouchTarget(size: ControlSize) {
        let tree = Tree(
            [TreeJudgeNode(id: "leaf", children: nil)],
            children: \TreeJudgeNode.children,
            expanded: .constant([]),
            selection: .constant([]),
            checked: .constant([])
        ) { node in
            Text(verbatim: node.id)
        }
        .controlSize(size)
        let height = self.renderedHeight(tree)
        #expect(height >= Self.minimumHitTarget, "\(size)：带复选框的 Tree 行实测高度 \(height)pt < 44pt")
    }

    @Test("Tree 父行的展开控件在每一档实测命中高度 ≥ 44pt，不把偏离 chevron 的点击让给相邻复选框", arguments: ControlSize.allCases)
    func treeDisclosureMeetsMinimumTouchTarget(size: ControlSize) {
        let control = TreeDisclosureControl(hasChildren: true, isExpanded: false, metrics: .resolve(size)) {}
        let height = self.renderedHeight(control, width: nil)
        #expect(height >= Self.minimumHitTarget, "\(size)：Tree 展开控件实测高度 \(height)pt < 44pt")
    }

    // MARK: - CheckBox（Toggle 类）

    @Test("CheckBoxToggleStyle 实测命中高度 ≥ 44pt（Issue #123 修复：原先无 contentShape/minHeight）")
    func checkBoxMeetsMinimumTouchTarget() {
        let toggle = Toggle("Accept terms", isOn: .constant(false))
            .toggleStyle(CheckBoxToggleStyle())
        let height = self.renderedHeight(toggle, width: nil)
        #expect(height >= Self.minimumHitTarget, "CheckBoxToggleStyle 实测高度 \(height)pt < 44pt")
    }

    // MARK: - UnderlinedTabBar item

    @Test("UnderlinedTabBar 单项实测命中高度 ≥ 44pt（Issue #123 修复：原先无 minHeight）")
    func underlinedTabBarItemMeetsMinimumTouchTarget() {
        let bar = UnderlinedTabBar(
            items: ["全部"],
            selection: .constant("全部"),
            title: { $0 }
        )
        let height = self.renderedHeight(bar)
        #expect(height >= Self.minimumHitTarget, "UnderlinedTabBar item 实测高度 \(height)pt < 44pt")
    }

    // MARK: - SegmentedControl（只测整体容器；单段命中区域未覆盖）

    @Test("SegmentedControl 整体容器实测高度 ≥ 44pt")
    func segmentedControlContainerMeetsMinimumTouchTarget() {
        let control = SegmentedControl(
            items: ["A", "B"],
            selection: .constant("A"),
            title: { $0 }
        )
        let height = self.renderedHeight(control)
        #expect(height >= Self.minimumHitTarget, "SegmentedControl 容器实测高度 \(height)pt < 44pt")
    }

    // MARK: - semi-mobile-components epic 新交互组件（Phase 3 / #173 汇入）

    @Test("Rating 在 .regular 档实测命中高度 ≥ 44pt（星形视觉尺寸本身小于 44pt，靠 frame(minHeight:) 补足）")
    func ratingMeetsMinimumTouchTarget() {
        let rating = Rating(value: .constant(3))
            .controlSize(.regular)
        let height = self.renderedHeight(rating, width: nil)
        #expect(height >= Self.minimumHitTarget, "Rating 实测高度 \(height)pt < 44pt")
    }

    @Test("RadioGroup 单选项实测命中高度 ≥ 44pt")
    func radioGroupMeetsMinimumTouchTarget() {
        let group = RadioGroup(
            selection: .constant("basic"),
            options: [RadioOption(value: "basic", title: "Basic")]
        )
        let height = self.renderedHeight(group, width: nil)
        #expect(height >= Self.minimumHitTarget, "RadioGroup 单选项实测高度 \(height)pt < 44pt")
    }

    @Test("PinCode 在 .regular 档实测高度 ≥ 44pt（格子本身即 CoreControlMetrics.height(for:)，无需 contentShape 撑高）")
    func pinCodeMeetsMinimumTouchTarget() {
        let pinCode = PinCode(value: .constant("12"), length: 6)
            .controlSize(.regular)
        let height = self.renderedHeight(pinCode, width: nil)
        #expect(height >= Self.minimumHitTarget, "PinCode 实测高度 \(height)pt < 44pt")
    }

    @Test("TagInput 空态输入框实测高度 ≥ 44pt（TextField 自身 frame(minHeight:)，非 contentShape 撑高）")
    func tagInputMeetsMinimumTouchTarget() {
        let field = TagInput(tags: .constant([]), placeholder: "Add tag")
        let height = self.renderedHeight(field, width: 320)
        #expect(height >= Self.minimumHitTarget, "TagInput 空态实测高度 \(height)pt < 44pt")
    }

    @Test("ExtendedFloatButtonStyle 默认档（.large）与显式 .regular 档均实测 ≥ 44pt")
    func extendedFloatButtonMeetsMinimumTouchTarget() {
        let defaultButton = Button {} label: {
            Label("New", systemImage: "plus")
        }
        .buttonStyle(.extendedFloat)
        let regularButton = Button {} label: {
            Label("New", systemImage: "plus")
        }
        .buttonStyle(.extendedFloat(size: .regular))

        let defaultHeight = self.renderedHeight(defaultButton, width: nil)
        let regularHeight = self.renderedHeight(regularButton, width: nil)
        #expect(defaultHeight >= Self.minimumHitTarget, "ExtendedFloatButtonStyle 默认档实测高度 \(defaultHeight)pt < 44pt")
        #expect(regularHeight >= Self.minimumHitTarget, "ExtendedFloatButtonStyle .regular 档实测高度 \(regularHeight)pt < 44pt")
    }
}
#endif
