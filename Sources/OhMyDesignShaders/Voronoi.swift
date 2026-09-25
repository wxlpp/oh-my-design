//
//  Voronoi.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 缓慢漂移的 Voronoi 细胞：浅色细胞、较深的间隙线与向边缘渐强的内光。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/voronoi.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
/// 两趟边界算法出自 Inigo Quilez 的 Shadertoy `ldl3W8`（MIT），上游注释原样保留在 `.metal` 分节头。
public struct Voronoi: View {

    /// 细胞大小。⚠️ 语义枚举，同时决定间隙与内光强度。
    public nonisolated enum CellSize: Sendable, CaseIterable {
        case large, regular, small

        var cells: (cells: Float, distortion: Float, gap: Float, glow: Float) {
            switch self {
            case .large: (2.5, 0.35, 0.03, 0.6)
            case .regular: (4, 0.4, 0.04, 0.7)
            case .small: (5.5, 0.45, 0.05, 0.8)
            }
        }
    }

    private let tint: Color
    private let cellSize: CellSize
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.dataAccent`（为什么不是 `.tint` / `accent`，见 `Plasma`）。
    ///   - cellSize: 细胞大小。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .dataAccent,
        cellSize: CellSize = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.cellSize = cellSize
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.cellSize.cells
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignVoronoi(
                .float2(size), .float(t),
                .float(p.cells), .float(p.distortion), .float(p.gap), .float(p.glow),
                .color(ramp.mid), .color(ramp.low), .color(ramp.high)
            )
        }
    }
}

#Preview("Voronoi") {
    VStack(spacing: 0) {
        ForEach(Array(Voronoi.CellSize.allCases.enumerated()), id: \.offset) { _, value in
            Voronoi(cellSize: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
