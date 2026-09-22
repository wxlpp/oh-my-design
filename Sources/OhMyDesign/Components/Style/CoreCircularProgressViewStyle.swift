import SwiftUI

// MARK: - CoreCircularProgressViewStyle

/// 系统 `ProgressView` 的 OhMyDesign 环形外观——确定态画一条从 12 点方向顺时针增长的圆弧，
/// 强调色经 `ShapeStyle.tint` 取值，所以 `.tint(_:)` 对它生效；不确定态回退系统环形 spinner。
public struct CoreCircularProgressViewStyle: ProgressViewStyle {
    @Environment(\.controlSize) private var controlSize

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            let fraction = Self.clampedFraction(fractionCompleted)
            VStack(spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }

                CoreCircularProgressRing(fraction: fraction)

                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(fraction, format: .percent))
        } else {
            VStack(spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: CoreControlMetrics.height(for: self.controlSize), height: CoreControlMetrics.height(for: self.controlSize))
                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    static func clampedFraction(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Ring

private struct CoreCircularProgressRing: View {
    let fraction: Double

    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let diameter = CoreControlMetrics.height(for: self.controlSize)
        let lineWidth = max(CoreBorderWidth.thick, diameter * Self.lineWidthRatio)
        ZStack {
            Circle()
                .stroke(Color.secondaryFill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: self.fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .frame(width: diameter, height: diameter)
    }

    private static let lineWidthRatio: CGFloat = 0.1
}

// MARK: - ProgressViewStyle extension

public extension ProgressViewStyle where Self == CoreCircularProgressViewStyle {
    /// OhMyDesign 的环形 `ProgressView` 外观。
    static var coreCircular: CoreCircularProgressViewStyle { CoreCircularProgressViewStyle() }
}

#Preview("CoreCircularProgressViewStyle — Light") {
    CoreCircularProgressViewStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreCircularProgressViewStyle — Dark") {
    CoreCircularProgressViewStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreCircularProgressViewStylePreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            HStack(spacing: CoreSpacing.xl) {
                ForEach([0.0, 0.25, 0.6, 1.0], id: \.self) { value in
                    ProgressView(value: value, label: { EmptyView() }, currentValueLabel: { Text(value, format: .percent) })
                        .progressViewStyle(.coreCircular)
                }
            }
            HStack(spacing: CoreSpacing.xl) {
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).controlSize(.small)
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).tint(.red)
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).controlSize(.large)
                ProgressView().progressViewStyle(.coreCircular)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
