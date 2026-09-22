import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Toast level visuals")
@MainActor
struct ToastLevelVisualTests {
    @Test("neutral 前景取 contentPrimary，不取资源色")
    func neutralForegroundUsesContentToken() {
        let color = ToastView.foregroundColor(for: .neutral)
        #expect(color == Color.contentPrimary)
        #expect(assetName(of: color) == nil)
        for scheme in [ColorScheme.light, .dark] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            #expect(color.resolve(in: env).opacity > 0)
        }
    }

    @Test("neutral 图标与其余四档互异")
    func neutralIconDiffersFromOtherLevels() {
        for level in [StatusLevel.info, .success, .warning, .danger] {
            #expect(ToastView.icon(for: .neutral) != ToastView.icon(for: level))
        }
    }
}
