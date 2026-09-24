import SwiftUI

// MARK: - TreeStyle

/// `Tree` 的行外观预设：`.automatic`（默认）或 `.navigator`。
///
/// 这是一个**封闭**的外观配置，不是样式协议：第三方不能新增外观。
/// 用 `.treeStyle(.navigator)` 设置；不要写 `TreeStyle.navigator`，也不要把它存成属性。
public struct TreeStyle {
    let appearance: TreeAppearance

    /// 默认外观：圆角选中块、内容区起于缩进之后、焦点环。
    nonisolated public static var automatic: TreeStyle { TreeStyle(appearance: .automatic) }

    /// 导航器外观（VS Code Explorer 式）：整行选中、悬停高亮、缩进参考线、中性色 chevron。
    nonisolated public static var navigator: TreeStyle { TreeStyle(appearance: .navigator) }
}

nonisolated enum TreeAppearance: Hashable, Sendable {
    case automatic
    case navigator
}

extension EnvironmentValues {
    @Entry var treeStyle: TreeStyle = .automatic
}

public extension View {
    /// 为子树中的所有 `Tree` 设置行外观。
    ///
    /// - Parameter style: 行外观预设，`.automatic` 或 `.navigator`。
    /// - Returns: 子树中 `Tree` 按该外观绘制行的视图。
    func treeStyle(_ style: TreeStyle) -> some View {
        self.environment(\.treeStyle, style)
    }
}

// MARK: - 行配置 / Row configuration

struct TreeRowConfiguration<Label: View> {
    let label: Label
    let disclosure: TreeDisclosureControl
    let checkBox: TreeRowCheckBox?
    let level: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let showsFocusIndicator: Bool
    let isHovered: Bool
    let metrics: TreeRowMetrics
}

// MARK: - 默认外观 / Automatic

struct AutomaticTreeRow<Label: View>: View {
    let configuration: TreeRowConfiguration<Label>

    @Environment(\.coreAccent) private var resolvedAccent

    var body: some View {
        let configuration = self.configuration
        return HStack(spacing: CoreSpacing.xs) {
            configuration.disclosure
            if let checkBox = configuration.checkBox {
                checkBox
            }
            configuration.label
        }
        .padding(.horizontal, CoreSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: configuration.metrics.rowHeight)
        .background(
            CoreShape.rounded(CoreRadius.small)
                .fill(configuration.isSelected ? Color.accentSubtleBackground(from: self.resolvedAccent) : Color.clear)
        )
        .padding(.leading, CGFloat(configuration.level - 1) * configuration.metrics.indentation)
        .focusRing(visible: configuration.showsFocusIndicator, cornerRadius: CoreRadius.small)
    }
}

// MARK: - 导航器外观 / Navigator

struct NavigatorTreeRow<Label: View>: View {
    let configuration: TreeRowConfiguration<Label>

    @Environment(\.coreAccent) private var resolvedAccent

    var body: some View {
        let configuration = self.configuration
        return HStack(spacing: CoreSpacing.xs) {
            configuration.disclosure
                .tint(Color.contentSecondary)
            if let checkBox = configuration.checkBox {
                checkBox
            }
            configuration.label
        }
        .padding(.leading, CGFloat(configuration.level - 1) * configuration.metrics.indentation)
        .padding(.horizontal, CoreSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: configuration.metrics.rowHeight)
        .background {
            TreeIndentGuides(level: configuration.level, metrics: configuration.metrics)
        }
        .background(self.fill)
        .overlay {
            if configuration.showsFocusIndicator {
                Rectangle()
                    .strokeBorder(self.resolvedAccent, lineWidth: CoreBorderWidth.thin)
            }
        }
    }

    private var fill: Color {
        if self.configuration.isSelected { return Color.accentSelectedRowBackground(from: self.resolvedAccent) }
        if self.configuration.isHovered { return Color.quaternaryFill }
        return Color.clear
    }
}

// MARK: - 缩进参考线 / Indent guides

nonisolated enum TreeIndentGuide {
    static func centerX(ofAncestorLevel level: Int, metrics: TreeRowMetrics) -> CGFloat {
        CoreSpacing.xs + CGFloat(level - 1) * metrics.indentation + metrics.disclosureWidth / 2
    }
}

struct TreeIndentGuides: View {
    let level: Int
    let metrics: TreeRowMetrics

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(1..<max(self.level, 1), id: \.self) { ancestor in
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: CoreBorderWidth.hairline)
                    .padding(
                        .leading,
                        TreeIndentGuide.centerX(ofAncestorLevel: ancestor, metrics: self.metrics) - CoreBorderWidth.hairline / 2
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.top, -self.metrics.rowSpacing)
    }
}
