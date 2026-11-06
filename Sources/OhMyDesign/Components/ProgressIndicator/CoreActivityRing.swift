import SwiftUI

// MARK: - CoreActivityRing

struct CoreActivityRing<Style: ShapeStyle>: View {
    let style: Style

    @Environment(\.controlSize) private var controlSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.coreMotionPresentation) private var motionPresentation
    @State private var isVisible = false

    private var reduceMotion: Bool { self.motionPresentation != .animated }

    var body: some View {
        let energy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.scenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let presentation = energy.presentation(reduceMotion: self.reduceMotion)
        let animates = self.isVisible && self.motionPresentation == .animated
            && ActivityRingMetrics.animates(presentation: presentation, phase: energy.scenePhase)
        let diameter = ActivityRingMetrics.diameter(for: self.controlSize)
        Group {
            if animates {
                TimelineView(.animation(minimumInterval: energy.policy.minimumInterval)) { context in
                    self.ring(angle: ActivityRingMetrics.angle(at: context.date.timeIntervalSinceReferenceDate))
                }
            } else {
                self.ring(angle: .zero)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { self.isVisible = true }
        .onDisappear { self.isVisible = false }
    }

    private func ring(angle: Angle) -> some View {
        let diameter = ActivityRingMetrics.diameter(for: self.controlSize)
        let lineWidth = diameter < 20 ? 1.5 : 1.75
        return ZStack {
            Circle().stroke(self.style.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.74)
                .stroke(self.style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .mask {
                    AngularGradient(
                        colors: [Color.maskOpaque.opacity(0.4), Color.maskOpaque],
                        center: .center, startAngle: .zero, endAngle: .degrees(270)
                    )
                }
                .rotationEffect(angle)
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - ActivityRingMetrics

nonisolated enum ActivityRingMetrics {
    static func diameter(for size: ControlSize) -> CGFloat {
        switch size {
        case .mini: 14
        case .small: 16
        case .regular: 20
        case .large, .extraLarge: 28
        @unknown default: 20
        }
    }

    static func angle(at time: TimeInterval) -> Angle {
        .degrees(time.truncatingRemainder(dividingBy: 0.95) / 0.95 * 360)
    }

    static func animates(presentation: MotionPresentation, phase: ScenePhase) -> Bool {
        presentation == .animated && phase == .active
    }
}
