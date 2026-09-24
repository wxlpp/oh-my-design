//
//  SmokeRing.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 被多层噪声扰动的烟环，环心与环边各取一档颜色。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/smoke-ring.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
public struct SmokeRing: View {

    /// 环的粗细与噪声细节。⚠️ 语义枚举。
    public nonisolated enum Thickness: Sendable, CaseIterable {
        case thin, regular, thick

        var ring: (thickness: Float, radius: Float, innerShape: Float, noiseScale: Float, iterations: Float) {
            switch self {
            case .thin: (0.35, 0.25, 0.7, 3, 6)
            case .regular: (0.6, 0.25, 0.9, 3, 7)
            case .thick: (0.9, 0.2, 1.2, 2.5, 8)
            }
        }
    }

    private let tint: Color
    private let thickness: Thickness
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.accent`（Metal 读不到 `.tint`，只能走参数，见 `Plasma`）。
    ///   - thickness: 环的粗细与噪声细节。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .accent,
        thickness: Thickness = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.thickness = thickness
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.thickness.ring
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignSmokeRing(
                .float2(size), .float(t),
                .float(p.thickness), .float(p.radius), .float(p.innerShape),
                .float(p.noiseScale), .float(p.iterations),
                .color(ramp.low), .color(ramp.high), .color(ramp.mid)
            )
        }
    }
}

#Preview("SmokeRing") {
    VStack(spacing: 0) {
        ForEach(Array(SmokeRing.Thickness.allCases.enumerated()), id: \.offset) { _, value in
            SmokeRing(thickness: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
