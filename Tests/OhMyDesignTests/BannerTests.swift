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

    // MARK: - 动作行排布

    private final class FrameProbe {
        var frames: [String: CGRect] = [:]
        var container: CGSize = .zero
    }

    private func measureActions(_ size: DynamicTypeSize) -> FrameProbe {
        let probe = FrameProbe()
        let view = Banner(level: .info, title: "Update available", message: "Restart to finish installing.") {
            Button("Restart now") {}
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("banner")) } action: { probe.frames["restart"] = $0 }
            Button("Later") {}
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("banner")) } action: { probe.frames["later"] = $0 }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { probe.container = $0 }
        .coordinateSpace(.named("banner"))
        .frame(width: 320)
        .dynamicTypeSize(size)
        _ = ImageRenderer(content: view).cgImage
        return probe
    }

    private func expectWithinContainer(_ probe: FrameProbe, _ label: String) {
        let bounds = CGRect(origin: .zero, size: probe.container)
        for (name, frame) in probe.frames {
            #expect(bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame), "\(label) \(name) \(frame) 越出容器 \(bounds)")
        }
    }

    @Test("常规字号下动作横排，且都在容器内")
    func actionsAreHorizontalAtRegularSize() throws {
        let probe = self.measureActions(.large)
        let restart = try #require(probe.frames["restart"])
        let later = try #require(probe.frames["later"])
        #expect(abs(restart.minY - later.minY) < 0.5, "横排时两按钮应同一行：\(restart) / \(later)")
        #expect(later.minX >= restart.maxX)
        self.expectWithinContainer(probe, "large")
    }

    // MARK: - 旧调用点布局不变

    private func render(_ view: some View) throws -> CGImage {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        return try #require(renderer.cgImage, "ImageRenderer 未产出位图")
    }

    private func pixels(of image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    private static let bodies = [
        "Saved",
        "This version of the document is going to expire after 4 days. Download a copy before then to keep your comments.",
    ]

    private static let levels: [StatusLevel] = [.info, .success, .warning, .danger, .neutral]

    private func host(_ view: some View) -> some View {
        view.frame(width: 300)
    }

    private func bannerSize(_ banner: some View) -> CGSize {
        let probe = FrameProbe()
        let view = self.host(banner.onGeometryChange(for: CGSize.self) { $0.size } action: { probe.container = $0 })
        _ = ImageRenderer(content: view.dynamicTypeSize(.large)).cgImage
        return probe.container
    }

    private func expectPixelIdentical(level: StatusLevel, body: String, bordered: Bool) throws {
        for scheme in [ColorScheme.light, .dark] {
            let current: AnyView = bordered
                ? AnyView(Banner(level: level) { Text(body) }.bannerStyle(BorderedBannerStyle()))
                : AnyView(Banner(level: level) { Text(body) })
            let now = try self.render(self.host(current).environment(\.colorScheme, scheme))
            let old = try self.render(self.host(LegacyBanner(level: level, bordered: bordered) { Text(body) }).environment(\.colorScheme, scheme))
            #expect(now.width == old.width && now.height == old.height, "\(level) \(scheme) bordered=\(bordered)：尺寸与旧实现不同")
            guard now.width == old.width, now.height == old.height else { continue }
            expectBitmapsEqual(self.pixels(of: now), self.pixels(of: old), "\(level) \(scheme) bordered=\(bordered)：像素与旧实现不同")
        }
    }

    @Test("只有正文的 Banner 与本 Issue 前的实现（d8915ba^ 原样拷贝）渲染尺寸一致（短 / 多行正文，两条腿都跑）")
    func bodyOnlyBannerMatchesLegacySize() throws {
        for level in Self.levels {
            for body in Self.bodies {
                for bordered in [false, true] {
                    let current: AnyView = bordered
                        ? AnyView(Banner(level: level) { Text(body) }.bannerStyle(BorderedBannerStyle()))
                        : AnyView(Banner(level: level) { Text(body) })
                    let now = self.bannerSize(current)
                    let old = self.bannerSize(LegacyBanner(level: level, bordered: bordered) { Text(body) })
                    #expect(now != .zero, "尺寸探针未回调")
                    #expect(now == old, "\(level) bordered=\(bordered) body=\(body.prefix(12))：\(now) ≠ \(old)")
                }
            }
        }
    }

    @Test("只有正文的 neutral Banner 与旧实现逐像素一致（neutral 只用系统色，两条腿都跑）")
    func bodyOnlyNeutralBannerMatchesLegacyPixels() throws {
        for body in Self.bodies {
            for bordered in [false, true] {
                try self.expectPixelIdentical(level: .neutral, body: body, bordered: bordered)
            }
        }
    }

    @Test(
        "只有正文的 Banner 五档与旧实现逐像素一致（light / dark × 短 / 多行 × 描边有无）",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：bundle 里没有 Assets.car（SwiftPM native 腿），info / success / warning / danger 的底色与前景取自 \
            asset catalog，在这条腿上解析为全透明。本条在 iOS Simulator 腿上跑；native 腿由尺寸判据与 neutral 像素判据兜。
            """
        )
    )
    func bodyOnlyBannerMatchesLegacyPixels() throws {
        for level in Self.levels {
            for body in Self.bodies {
                for bordered in [false, true] {
                    try self.expectPixelIdentical(level: level, body: body, bordered: bordered)
                }
            }
        }
    }

    #if os(iOS)
    @Test("AX5 下动作改竖排（上下排列、左缘对齐），且都在容器内")
    func actionsStackVerticallyAtAccessibilitySizes() throws {
        let probe = self.measureActions(.accessibility5)
        let restart = try #require(probe.frames["restart"])
        let later = try #require(probe.frames["later"])
        #expect(later.minY >= restart.maxY, "AX5 下 Later 应在 Restart now 下方：\(restart) / \(later)")
        #expect(abs(restart.minX - later.minX) < 0.5, "竖排时左缘应对齐：\(restart) / \(later)")
        #expect(probe.container.width == 320)
        self.expectWithinContainer(probe, "AX5")
    }

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

    #endif
}

// MARK: - LegacyBanner

private struct LegacyBanner<Label: View>: View {
    let level: StatusLevel
    let bordered: Bool
    let label: Label

    init(level: StatusLevel, bordered: Bool, @ViewBuilder label: () -> Label) {
        self.level = level
        self.bordered = bordered
        self.label = label()
    }

    var body: some View {
        let palette = bannerPalette(for: self.level)
        HStack(spacing: CoreSpacing.sm) {
            bannerIcon(for: self.level)
                .foregroundStyle(palette.icon)
                .accessibilityHidden(true)
            self.label
        }
        .accessibilityElement(children: .combine)
        .coreFont(.callout)
        .foregroundStyle(palette.foreground)
        .padding(CoreSpacing.md)
        .background {
            if self.bordered {
                Rectangle().fill(palette.background).bordered(style: palette.border)
            } else {
                Rectangle().fill(palette.background)
            }
        }
    }
}
