//
//  SimplexNoise.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 双层 simplex 噪声的等高色带：三档颜色之间按阶梯过渡。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/simplex-noise.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
/// 噪声为 Ashima Arts / Stefan Gustavson 的 2D simplex（MIT），同见 `ACKNOWLEDGEMENTS.md`。
public struct SimplexNoise: View {

    /// 色带的阶梯感。⚠️ 语义枚举：承载上游的「每色阶梯数 + 过渡柔和度」，
    /// 这是本件与平滑渐变类背景（`FractalClouds`）的区别所在。
    public nonisolated enum Banding: Sendable, CaseIterable {
        case soft, regular, stepped

        var bands: (steps: Float, softness: Float) {
            switch self {
            case .soft: (1, 1)
            case .regular: (2, 0.5)
            case .stepped: (4, 0)
            }
        }
    }

    private let tint: Color
    private let banding: Banding
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - banding: 色带的阶梯感。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        banding: Banding = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.banding = banding
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.banding.bands
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignSimplexNoise(
                .float2(size), .float(t),
                .float(3), .float(p.steps), .float(p.softness),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("SimplexNoise") {
    VStack(spacing: 0) {
        ForEach(Array(SimplexNoise.Banding.allCases.enumerated()), id: \.offset) { _, value in
            SimplexNoise(banding: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
