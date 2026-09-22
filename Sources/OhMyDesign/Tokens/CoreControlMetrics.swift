import CoreGraphics
import SwiftUI

// MARK: - CoreControlMetrics

/// 控件尺寸 token，按 SwiftUI `ControlSize`（mini / small / regular / large / extraLarge）
/// 暴露查询 helper：常规控件（height / horizontalPadding / verticalPadding / font / iconSize）、
/// 紧凑 chip（Badge / Tag 用的 compact 系列）与头像（avatarDiameter 等）。
public nonisolated enum CoreControlMetrics {
    // MARK: - height

    /// 控件高度（pt）。用于 capsule / pill / SegmentedControl / SearchField 等需要固定外框
    /// 高度的场景。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的推荐外框高度，单位 pt。
    public static func height(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 28
        case .small: return 32
        case .regular: return 44
        case .large: return 50
        case .extraLarge: return 56
        @unknown default:
            return 44
        }
    }

    // MARK: - horizontalPadding

    /// 控件横向 padding（pt）。包裹 label 的左右内边距，配合 `height(for:)` 决定外框宽度。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func horizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.sm
        case .small: return CoreSpacing.md
        case .regular: return CoreSpacing.lg
        case .large: return CoreSpacing.lg
        case .extraLarge: return CoreSpacing.xl
        @unknown default:
            return CoreSpacing.lg
        }
    }

    // MARK: - verticalPadding

    /// 控件纵向 padding（pt）。包裹 label 的上下内边距。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func verticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xs
        case .small: return CoreSpacing.xs
        case .regular: return CoreSpacing.md
        case .large: return CoreSpacing.lg
        case .extraLarge: return CoreSpacing.lg
        @unknown default:
            return CoreSpacing.md
        }
    }

    // MARK: - font

    /// 控件 label 推荐字号 token。直接返回 `CoreTypography.Token`，调用方经
    /// `.coreFont(_:)` 施加。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 `CoreTypography.Token`。
    public static func fontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .footnote
        case .small:      .footnote
        case .regular:    .callout
        case .large:      .body
        case .extraLarge: .title2
        @unknown default: .callout
        }
    }

    // MARK: - iconSize

    /// 控件内联 icon 边长（pt），比对应字号大 1.0–1.2 倍以与 label 文字视觉等重。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 icon 边长，单位 pt。
    public static func iconSize(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 12
        case .small: return 14
        case .regular: return 16
        case .large: return 20
        case .extraLarge: return 24
        @unknown default:
            return 16
        }
    }

    // MARK: - compact chip（Badge / Tag）

    /// 紧凑 chip（`Badge` / `Tag`）的 label 字号 token。`.regular` 档为 `.footnote`。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 `CoreTypography.Token`，五档互异、逐档增大。
    public static func compactFontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .caption2
        case .small:      .caption
        case .regular:    .footnote
        case .large:      .subheadline
        case .extraLarge: .callout
        @unknown default: .footnote
        }
    }

    /// 紧凑 chip 的横向 padding（pt）。逐档严格递增：macOS 上 `caption2` / `caption` / `footnote`
    /// 同为 10pt，只靠字号撑不出五档差异。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func compactHorizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xxs
        case .small: return CoreSpacing.xs
        case .regular: return CoreSpacing.sm
        case .large: return CoreSpacing.md
        case .extraLarge: return CoreSpacing.lg
        @unknown default:
            return CoreSpacing.sm
        }
    }

    /// 紧凑 chip 的纵向 padding（pt）。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func compactVerticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.none
        case .small: return CoreSpacing.xxs
        case .regular: return CoreSpacing.xs
        case .large: return CoreSpacing.xs
        case .extraLarge: return CoreSpacing.sm
        @unknown default:
            return CoreSpacing.xs
        }
    }

    /// 紧凑 chip 内联图标边长（pt），如 `Tag` 的关闭钮。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的图标边长，单位 pt。
    public static func compactIconSize(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 10
        case .small: return 12
        case .regular: return 14
        case .large: return 16
        case .extraLarge: return 18
        @unknown default:
            return 14
        }
    }

    // MARK: - avatar

    /// 头像直径（pt）。`Avatar` 的 `.automatic` 与 `AvatarGroup` 共用这张表。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的头像直径，单位 pt。
    public static func avatarDiameter(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 20
        case .small: return 24
        case .regular: return 32
        case .large: return 40
        case .extraLarge: return 48
        @unknown default:
            return 32
        }
    }

    /// 头像首字母字号（pt），按直径线性缩放。
    ///
    /// - Parameter diameter: 头像直径，单位 pt。
    /// - Returns: 首字母字号，单位 pt。
    public static func avatarInitialFontSize(forDiameter diameter: CGFloat) -> CGFloat {
        diameter * 7 / 12
    }

    /// `AvatarGroup` 交叠形态下相邻头像的间距（pt，负值即交叠量）。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的负间距，单位 pt。
    public static func avatarGroupOverlap(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini, .small: return -6
        case .regular: return -8
        case .large, .extraLarge: return -10
        @unknown default:
            return -8
        }
    }
}
