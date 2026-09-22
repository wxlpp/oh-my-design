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
    @Test("neutral 调色板取 content / fill / border 语义 token，图标比正文更轻")
    func neutralPaletteUsesSemanticTokens() {
        let palette = bannerPalette(for: .neutral)
        #expect(palette.icon == Color.contentSecondary)
        #expect(palette.foreground == Color.contentPrimary)
        #expect(palette.background == Color.tertiaryFill)
        #expect(palette.border == Color.borderDefault)
    }

    @MainActor
    @Test("neutral 调色板不取资源色，明暗两档都解析为可见色")
    func neutralPaletteIsNotCatalogColor() {
        let palette = bannerPalette(for: .neutral)
        for color in [palette.icon, palette.foreground, palette.background, palette.border] {
            #expect(assetName(of: color) == nil)
            for scheme in [ColorScheme.light, .dark] {
                var env = EnvironmentValues()
                env.colorScheme = scheme
                #expect(color.resolve(in: env).opacity > 0)
            }
        }
    }

    @MainActor
    @Test("非 neutral 档图标色与正文色同源")
    func statusLevelsShareIconAndForeground() {
        for level in [StatusLevel.info, .success, .warning, .danger] {
            let palette = bannerPalette(for: level)
            #expect(palette.icon == palette.foreground)
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

// MARK: - title / actions / dismiss

@Suite("Banner 标题 / 动作 / 关闭")
@MainActor
struct BannerSlotTests {
    @Test("便利 init 填满 title / actions / dismiss，label 仍是正文槽")
    func convenienceInitFillsAllSlots() {
        let banner = Banner(level: .warning, title: "Storage almost full", message: "Free up space to keep syncing.") {
            Button("Manage") {}
        } onDismiss: {}
        #expect(type(of: banner) == Banner<Text>.self)
        #expect(banner.configuration.title != nil)
        #expect(banner.configuration.actions != nil)
        #expect(banner.configuration.dismiss != nil)
        #expect(banner.configuration.level == .warning)
    }

    @Test("省略 actions / onDismiss / title 时对应字段为 nil")
    func omittedSlotsAreNil() {
        let banner = Banner(level: .info, message: "Sync paused.")
        #expect(banner.configuration.title == nil)
        #expect(banner.configuration.actions == nil)
        #expect(banner.configuration.dismiss == nil)
    }

    @Test("既有 init(level:label:) 不带任何新槽")
    func labelInitLeavesNewSlotsEmpty() {
        let banner = Banner(level: .success) { Text("Saved") }
        #expect(banner.configuration.title == nil)
        #expect(banner.configuration.actions == nil)
        #expect(banner.configuration.dismiss == nil)
    }

    @Test("dismiss 只转调调用方回调，Banner 不持有状态")
    func dismissOnlyForwardsCallback() {
        final class Counter { var value = 0 }
        let counter = Counter()
        let banner = Banner(level: .danger, message: "Upload failed.", onDismiss: { counter.value += 1 })
        banner.configuration.dismiss?()
        banner.configuration.dismiss?()
        #expect(counter.value == 2)
        #expect(banner.configuration.dismiss != nil)
    }

    @Test("自定义 BannerStyle 收到新字段")
    func customStyleReceivesNewFields() {
        final class Probe { var configurations: [BannerStyleConfiguration] = [] }
        struct RecordingStyle: BannerStyle {
            let probe: Probe
            func makeBody(configuration: Configuration) -> some View {
                self.probe.configurations.append(configuration)
                return configuration.label
            }
        }
        let probe = Probe()
        let view = Banner(level: .neutral, title: "Title", message: "Body") {
            Button("Undo") {}
        } onDismiss: {}
        .bannerStyle(RecordingStyle(probe: probe))
        _ = ImageRenderer(content: view.frame(width: 320)).cgImage
        let received = probe.configurations.last
        #expect(received != nil)
        #expect(received?.title != nil)
        #expect(received?.actions != nil)
        #expect(received?.dismiss != nil)
    }

    @Test("图标无障碍标签覆盖五档，键已注册")
    func iconAccessibilityKeysResolve() {
        for level in [StatusLevel.info, .success, .warning, .danger, .neutral] {
            let key = bannerIconAccessibilityKey(for: level)
            let resolved = Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved != "__MISSING__", "键 \(key) 未注册")
        }
        let dismiss = Bundle.module.localizedString(forKey: "Dismiss", value: "__MISSING__", table: nil)
        #expect(dismiss != "__MISSING__")
    }

    #if os(iOS)
    private func renderedSize<V: View>(_ view: V) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage?.size ?? .zero
    }

    @Test("关闭钮命中框 ≥ 44pt")
    func dismissButtonMeetsMinimumTouchTarget() {
        let size = self.renderedSize(BannerDismissButton(color: .contentSecondary, action: {}))
        #expect(size.width >= 44)
        #expect(size.height >= 44)
    }

    @Test("关闭钮不撑高单行 banner")
    func dismissButtonDoesNotGrowBanner() {
        let plain = self.renderedSize(Banner(level: .info, message: "Sync paused.").frame(width: 320))
        let dismissible = self.renderedSize(Banner(level: .info, message: "Sync paused.", onDismiss: {}).frame(width: 320))
        #expect(dismissible.height <= plain.height + 1, "带关闭钮 \(dismissible.height) vs 不带 \(plain.height)")
    }

    @Test("AX5 下动作行改竖排、不溢出宽度")
    func actionsWrapAtAccessibilitySizes() {
        func banner() -> some View {
            Banner(level: .info, title: "Update available", message: "Restart to finish installing.") {
                Button("Restart now") {}
                Button("Later") {}
            }
            .frame(width: 320)
        }
        let regular = self.renderedSize(banner().dynamicTypeSize(.large))
        let huge = self.renderedSize(banner().dynamicTypeSize(.accessibility5))
        #expect(huge.width == 320)
        #expect(huge.height > regular.height)
    }
    #endif
}
