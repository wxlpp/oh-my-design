//
//  ColorPanels.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 一组半透明彩色面板绕中轴翻转，像透视中的百叶。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/color-panels.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
public struct ColorPanels: View {

    /// 面板质感。⚠️ 语义枚举；上游的「边缘高光」开关折进本枚举，不单独暴露为 Bool。
    public nonisolated enum Style: Sendable, CaseIterable {
        case soft, regular, crisp

        var panels: (edges: Float, blur: Float, gradient: Float) {
            switch self {
            case .soft: (0, 0.4, 1)
            case .regular: (0, 0.1, 0.5)
            case .crisp: (1, 0, 0)
            }
        }
    }

    private let tint: Color
    private let style: Style
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - style: 面板质感。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        style: Style = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.style = style
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.style.panels
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignColorPanels(
                .float2(size), .float(t),
                .float(3), .float(0), .float(0), .float(1.1),
                .float(p.edges), .float(p.blur), .float(1), .float(0.3), .float(p.gradient),
                .color(ramp.low), .color(ramp.mid.opacity(0.45)), .color(ramp.high.opacity(0.45))
            )
        }
    }
}

#Preview("ColorPanels") {
    VStack(spacing: 0) {
        ForEach(Array(ColorPanels.Style.allCases.enumerated()), id: \.offset) { _, value in
            ColorPanels(style: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
