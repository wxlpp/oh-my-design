import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Toast level visuals")
@MainActor
struct ToastLevelVisualTests {
    @Test("neutral 图标色取 contentSecondary，不取资源色")
    func neutralIconColorUsesContentToken() {
        let color = ToastView.iconColor(for: .neutral)
        #expect(color == Color.contentSecondary)
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
