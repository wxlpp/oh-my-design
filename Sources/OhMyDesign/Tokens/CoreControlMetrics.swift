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

    /// 紧凑 chip 的横向 padding（pt）。逐档严格递增；mini / small 约为 chip 高度的 0.35 倍，
    /// 避免文字压进 capsule 两端的圆弧。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt。
    public static func compactHorizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 6
        case .small: return 7
        case .regular: return CoreSpacing.sm
        case .large: return CoreSpacing.md
        case .extraLarge: return CoreSpacing.lg
        @unknown default:
            return CoreSpacing.sm
        }
    }

    /// 紧凑 chip 的纵向 padding（pt）。mini 与 small 同为 `xxs`，保证 mini 档描边不贴字；
    /// 默认字号下 chip 高度的五档节奏由 `compactMinHeight(for:)` 决定，padding 负责 Dynamic Type 放大后的留白。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func compactVerticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xxs
        case .small: return CoreSpacing.xxs
        case .regular: return CoreSpacing.xs
        case .large: return CoreSpacing.xs
        case .extraLarge: return CoreSpacing.xs
        @unknown default:
            return CoreSpacing.xs
        }
    }

    /// 紧凑 chip 的最小高度（pt），让五档高度在默认字号下近似等距递增。
    /// `.regular` 返回 `nil`：该档不设下限，保持由字号与 padding 自然撑开的原外观。
    /// 两个平台的系统字号行高不同（iOS `footnote` 行高 16pt、macOS 13pt），因此按平台各取一张表，
    /// 使相邻档的步长都落在 regular 自然高度的两侧。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的最小高度，单位 pt；`.regular` 为 `nil`。
    public static func compactMinHeight(for controlSize: ControlSize) -> CGFloat? {
        #if os(macOS)
        switch controlSize {
        case .mini: return 17
        case .small: return 19
        case .regular: return nil
        case .large: return 25
        case .extraLarge: return 29
        @unknown default:
            return nil
        }
        #else
        switch controlSize {
        case .mini: return 18
        case .small: return 21
        case .regular: return nil
        case .large: return 28
        case .extraLarge: return 32
        @unknown default:
            return nil
        }
        #endif
    }

    /// 紧凑圆角矩形 chip（`Tag`）的圆角半径（pt），与 chip 高度之比约 0.25；`.regular` 为 `CoreRadius.small`。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的圆角半径，单位 pt。
    public static func compactCornerRadius(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 4
        case .small: return 5
        case .regular: return CoreRadius.small
        case .large: return 7
        case .extraLarge: return 8
        @unknown default:
            return CoreRadius.small
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

    static func avatarGroupOverlap(forDiameter diameter: CGFloat) -> CGFloat {
        -diameter / 4
    }

    static func avatarCountFontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .caption2
        case .small:      .caption2
        case .regular:    .caption
        case .large:      .footnote
        case .extraLarge: .subheadline
        @unknown default: .caption
        }
    }
}
