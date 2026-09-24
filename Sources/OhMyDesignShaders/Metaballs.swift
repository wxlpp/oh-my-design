//
//  Metaballs.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 一组彩色小球绕中心游走、彼此融合成黏连的有机形状。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/metaballs.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
public struct Metaballs: View {

    /// 小球的数量与大小。⚠️ 语义枚举，不暴露「个数 + 尺寸」两个裸旋钮。
    public nonisolated enum Count: Sendable, CaseIterable {
        case few, regular, many

        var balls: (count: Float, size: Float) {
            switch self {
            case .few: (5, 0.85)
            case .regular: (10, 0.8)
            case .many: (16, 0.8)
            }
        }
    }

    private let tint: Color
    private let count: Count
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - count: 小球的数量与大小。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        count: Count = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.count = count
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.count.balls
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignMetaballs(
                .float2(size), .float(t),
                .float(p.count), .float(p.size),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("Metaballs") {
    VStack(spacing: 0) {
        ForEach(Array(Metaballs.Count.allCases.enumerated()), id: \.offset) { _, value in
            Metaballs(count: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
