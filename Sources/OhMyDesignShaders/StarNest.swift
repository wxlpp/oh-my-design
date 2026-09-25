//
//  StarNest.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 体积分形星云：一路穿行的星尘与暗物质。
///
/// 移植自「Star Nest」by Pablo Roman Andrioli（Kali），Shadertoy `XlfGRj`，作者在源码头声明 MIT；
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名见 `ACKNOWLEDGEMENTS.md`。
/// ⚠️ 成本随全屏像素 × 体积步数 × 迭代数线性增长。`.deep` 为 16 × 17，比上游的 20 × 17 少 4 个体积步，
/// 是 iPhone 15 Pro 全屏 60 Hz 帧预算内的上限。
/// 浅色外观下是浅底深星；要深色星空，在该区域写 `.environment(\.colorScheme, .dark)`（本件不替调用方翻转外观）。
public struct StarNest: View {

    /// 体积深度，同时决定渲染成本。⚠️ 语义枚举。
    public nonisolated enum Depth: Sendable, CaseIterable {
        case shallow, regular, deep

        var steps: (volsteps: Float, iterations: Float) {
            switch self {
            case .shallow: (10, 12)
            case .regular: (14, 15)
            case .deep: (16, 17)
            }
        }
    }

    private let tint: Color
    private let depth: Depth
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - depth: 体积深度（同时决定渲染成本）。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        depth: Depth = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.depth = depth
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.depth.steps
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignStarNest(
                .float2(size), .float(t),
                .float(p.volsteps), .float(p.iterations),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("StarNest") {
    VStack(spacing: 0) {
        ForEach(Array(StarNest.Depth.allCases.enumerated()), id: \.offset) { _, value in
            StarNest(depth: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
