import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("Banner")
struct BannerTests {
    @MainActor
    @Test("banner constructs with info level")
    func bannerConstructsWithInfoLevel() {
        let banner = Banner(level: .info) {
            Text("New version available")
        }
        #expect(type(of: banner) == Banner<Text>.self)
    }

    @MainActor
    @Test("banner constructs with danger level")
    func bannerConstructsWithDangerLevel() {
        let banner = Banner(level: .danger) {
            Text("Build failed")
        }
        #expect(type(of: banner) == Banner<Text>.self)
    }

    // MARK: - neutral

    @MainActor
    @Test("neutral 调色板取 content / fill / border 语义 token")
    func neutralPaletteUsesSemanticTokens() {
        let palette = bannerPalette(for: .neutral)
        #expect(palette.foreground == Color.contentPrimary)
        #expect(palette.background == Color.secondaryFill)
        #expect(palette.border == Color.borderDefault)
    }

    @MainActor
    @Test("neutral 调色板不取资源色，明暗两档都解析为可见色")
    func neutralPaletteIsNotCatalogColor() {
        let palette = bannerPalette(for: .neutral)
        for color in [palette.foreground, palette.background, palette.border] {
            #expect(assetName(of: color) == nil)
            for scheme in [ColorScheme.light, .dark] {
                var env = EnvironmentValues()
                env.colorScheme = scheme
                #expect(color.resolve(in: env).opacity > 0)
            }
        }
    }

    @MainActor
    @Test("neutral 图标与其余四档互异")
    func neutralIconDiffersFromOtherLevels() {
        for level in [StatusLevel.info, .success, .warning, .danger] {
            #expect(bannerIcon(for: .neutral) != bannerIcon(for: level))
        }
    }
}
