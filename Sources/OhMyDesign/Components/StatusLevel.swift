import SwiftUI

// MARK: - StatusLevel

/// 状态语义等级，决定组件的图标 + 配色映射。
public nonisolated enum StatusLevel: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
    /// 不带状态倾向的中性提示，取内容 / 填充语义色而非状态色。
    case neutral
}
