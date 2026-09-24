//
//  GlassSymbolStyle.swift
//  OhMyDesignShaders
//

import SwiftUI

// MARK: - GlassSymbolStyleConfiguration

/// 传给 `GlassSymbolStyle.makeBody` 的上下文：已渲染好的折射符号本体与背衬基色。
public struct GlassSymbolStyleConfiguration {
    public typealias Symbol = AnyView

    /// 已铺好渐变背衬并施加折射（含 Reduce Transparency 降级）的符号本体。
    public let symbol: Symbol
    /// 渐变背衬的基色，供 style 给附加层取色。
    public let tint: Color
}

// MARK: - GlassSymbolStyle

/// `GlassSymbol` 外观的扩展点，形态对齐 Apple `ButtonStyle` 与本仓的 `RatingStyle`：
/// 在符号本体周围加等级标签、进度环这类附加层，或改排布。
public protocol GlassSymbolStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = GlassSymbolStyleConfiguration
}

// MARK: - PlainGlassSymbolStyle

/// 默认外观：只渲染符号本体，不加任何附加层。
public struct PlainGlassSymbolStyle: GlassSymbolStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.symbol
    }
}

// MARK: - GlassSymbolStyle environment plumbing

extension EnvironmentValues {
    @Entry var glassSymbolStyle: any GlassSymbolStyle = PlainGlassSymbolStyle()
}

public extension View {
    /// 为子树中的所有 `GlassSymbol` 设置外观。
    ///
    /// - Parameter style: 任意符合 `GlassSymbolStyle` 协议的实现，内置的是 `PlainGlassSymbolStyle`。
    func glassSymbolStyle(_ style: some GlassSymbolStyle) -> some View {
        self.environment(\.glassSymbolStyle, style)
    }
}
