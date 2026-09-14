import SwiftUI

// MARK: - coreAccent 环境入口 / Themeable accent

public extension EnvironmentValues {
    /// 子树的强调色。默认 `Color.inkPrimary`（墨色：浅色下黑、深色下白）。
    ///
    /// 组件应读本键而非静态的 `Color.accent`——后者是环境不可达时的回退值，不跟随主题。
    ///
    /// ⚠️ 在 `View` 内部**不要**把注入属性也命名为 `coreAccent`——`self.coreAccent`
    /// 会解析到下面的 `View.coreAccent(_:on:)` modifier 而非本属性。用别的名字
    /// （本仓用 `resolvedAccent`）。`ButtonStyle` 不是 `View`，不受影响。
    @Entry var coreAccent: Color = .inkPrimary

    /// 压在 accent 之上的前景色（on-accent）。`nil` = 按 accent 在当前外观下的相对
    /// 亮度自动选黑 / 白（L < 0.5 → `.white`，否则 `.black`）；显式值由
    /// `View.coreAccent(_:on:)` 的 `on` 参数写入，覆盖自动选择。
    @Entry var coreAccentOn: Color? = nil
}

public extension View {
    /// 为子树设置强调色，`accentHover` / `accentPressed` / `accentDisabled` /
    /// `accentSubtleBackground` 四个派生态自动跟随。
    ///
    /// ⚠️ 本 modifier **不设** `.tint(_:)`：`.core` 系统控件 style（`ProgressView` /
    /// `Label` / `DisclosureGroup`）走 `.tint` 通路，两条通路刻意分开，调用方要同时
    /// 改就写两个 modifier。
    ///
    /// - Parameters:
    ///   - color: 新的强调色。
    ///   - on: 压在 accent 之上的前景色（on-accent）。默认 `nil` = 按 `color` 在当前
    ///     外观下的相对亮度自动选黑 / 白——`.solid(role: .primary)` 按钮与
    ///     `InkSegmentedControlStyle` 选中段文字随之。饱和色 accent（如系统蓝）在明暗
    ///     两档都自动得到可读前景；显式传值则原样使用（两档同值）。
    func coreAccent(_ color: Color, on: Color? = nil) -> some View {
        self.environment(\.coreAccent, color)
            .environment(\.coreAccentOn, on)
    }
}

// MARK: - on-accent 派生（单一来源）/ On-accent derivation

extension Color {
    /// 派生压 `accent` 之上的前景色。
    ///
    /// 墨色（黑 / 白极性）accent 走 `contentOnAccent`（`systemBackground`），与 `#356`
    /// 之前的静态 token 逐字节一致；其余颜色按相对亮度
    /// `L = 0.2126R + 0.7152G + 0.0722B` 分档：L < 0.5 → `.white`，否则 `.black`。
    /// ⚠️ 只判解析后 RGB 三通道全部落在 0 / 1 的 ±0.001 内（纯黑 / 纯白极性）——
    /// 饱和色路径不受影响，`CoreAccentOnAccentTests` 蓝 / 黄两组断言钉着这一点。
    /// ⚠️ 不能判「通道 == 0 / == 1 精确相等」：iOS 上 `label` 深色档经色彩空间换算
    /// 解析出的通道不是精确 1.0（实测 isInk 漏判、派生落到 `.black`，iOS 腿
    /// `derivationMatchesReckoning` 红）；三系数在 Float 单精度下相加也不保证
    /// 恰为 1.0。±0.001 容差只吞视觉上就是黑 / 白的颜色（chroma ≤ 0.001）。
    static func onAccent(for accent: Color, in environment: EnvironmentValues) -> Color {
        let resolved = accent.resolve(in: environment)
        let epsilon: Float = 0.001
        let isInk = (abs(resolved.red) < epsilon && abs(resolved.green) < epsilon
            && abs(resolved.blue) < epsilon)
            || (abs(resolved.red - 1) < epsilon && abs(resolved.green - 1) < epsilon
                && abs(resolved.blue - 1) < epsilon)
        if isInk { return .contentOnAccent }
        let luminance = 0.2126 * resolved.red + 0.7152 * resolved.green + 0.0722 * resolved.blue
        return luminance < 0.5 ? .white : .black
    }
}
