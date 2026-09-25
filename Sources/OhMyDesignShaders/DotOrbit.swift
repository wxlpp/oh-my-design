//
//  DotOrbit.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 点阵中的每个点绕各自的格心公转，点色在两档之间按格随机取。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/dot-orbit.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
public struct DotOrbit: View {

    /// 点的疏密与公转幅度。⚠️ 语义枚举。
    public nonisolated enum Density: Sendable, CaseIterable {
        case sparse, regular, dense

        var dots: (cells: Float, size: Float, sizeRange: Float, spreading: Float) {
            switch self {
            case .sparse: (3, 0.75, 0.5, 0.9)
            case .regular: (5, 0.75, 0.5, 0.95)
            case .dense: (8, 0.75, 0.5, 1.0)
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - density: 点的疏密与公转幅度。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        density: Density = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.density = density
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.density.dots
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignDotOrbit(
                .float2(size), .float(t),
                .float(p.cells), .float(p.size), .float(p.sizeRange), .float(p.spreading),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("DotOrbit") {
    VStack(spacing: 0) {
        ForEach(Array(DotOrbit.Density.allCases.enumerated()), id: \.offset) { _, value in
            DotOrbit(density: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
