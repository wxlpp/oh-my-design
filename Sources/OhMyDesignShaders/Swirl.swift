//
//  Swirl.swift
//  OhMyDesignShaders
//

import OhMyDesign
import SwiftUI

/// 从中心旋出的彩色条带，可扭成漩涡，带轻微噪声扰动。
///
/// 移植自 paper-design/shaders 的 `packages/shaders/src/shaders/swirl.ts` @ `43cd68d`（Apache-2.0），
/// 修改逐项写在 `OhMyDesignShaders.metal` 的分节头；署名与许可全文见 `ACKNOWLEDGEMENTS.md`。
/// 噪声为 Ashima Arts / Stefan Gustavson 的 2D simplex（MIT），同见 `ACKNOWLEDGEMENTS.md`。
public struct Swirl: View {

    /// 条带数与扭转强度。⚠️ 语义枚举。
    public nonisolated enum Bands: Sendable, CaseIterable {
        case few, regular, many

        var swirl: (count: Float, twist: Float) {
            switch self {
            case .few: (2, 0.3)
            case .regular: (4, 0.4)
            case .many: (7, 0.5)
            }
        }
    }

    private let tint: Color
    private let bands: Bands
    private let motion: ShaderMotion

    var originOverride: Date?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 调色基色，三档斜坡由它推导。默认 `Color.accent`（Metal 读不到 `.tint`，只能走参数，见 `Plasma`）。
    ///   - bands: 条带数与扭转强度。
    ///   - motion: 运动速度档位。
    public init(
        tint: Color = .accent,
        bands: Bands = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.bands = bands
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let p = self.bands.swirl
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion, originOverride: self.originOverride) { size, t in
            library.ohMyDesignSwirl(
                .float2(size), .float(t),
                .float(p.count), .float(p.twist), .float(0.2), .float(0.5),
                .float(0.3), .float(0.2), .float(0.4),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("Swirl") {
    VStack(spacing: 0) {
        ForEach(Array(Swirl.Bands.allCases.enumerated()), id: \.offset) { _, value in
            Swirl(bands: value)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: value)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
