import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("细弧 loading")
@MainActor
struct ActivityRingTests {
    @Test("尺寸为布局提供稳定占位")
    func sizes() {
        #expect(ActivityRingMetrics.diameter(for: .mini) == 14)
        #expect(ActivityRingMetrics.diameter(for: .small) == 16)
        #expect(ActivityRingMetrics.diameter(for: .regular) == 20)
        #expect(ActivityRingMetrics.diameter(for: .large) == 28)
    }

    @Test("0.95秒一圈，匀速，跨周期连续")
    func phase() {
        #expect(abs(ActivityRingMetrics.angle(at: 0.475).degrees - 180) < 0.001)
        #expect(abs(ActivityRingMetrics.angle(at: 0.95).degrees) < 0.001)
        #expect(abs(ActivityRingMetrics.angle(at: 1.1875).degrees - 90) < 0.001)
    }

    @Test("静止、隐藏与非活跃不驱动动画")
    func motionGate() {
        for phase in [ScenePhase.inactive, .background] {
            #expect(!ActivityRingMetrics.animates(presentation: .animated, phase: phase))
        }
        #expect(!ActivityRingMetrics.animates(presentation: .resting, phase: .active))
        #expect(!ActivityRingMetrics.animates(presentation: .hidden, phase: .active))
        #expect(ActivityRingMetrics.animates(presentation: .animated, phase: .active))
    }
}
