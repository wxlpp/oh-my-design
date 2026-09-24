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
    @Test("neutral 调色板取 content / status / border 语义 token，图标比正文更轻")
    func neutralPaletteUsesSemanticTokens() {
        let palette = bannerPalette(for: .neutral)
        #expect(palette.icon == Color.contentSecondary)
        #expect(palette.foreground == Color.contentPrimary)
        #expect(palette.background == Color.statusNeutralSubtle)
        #expect(palette.border == Color.borderDefault)
    }

    @MainActor
    @Test("statusNeutralSubtle 桥接 systemGray5，明暗两档都完全不透明")
    func statusNeutralSubtleIsOpaqueSystemGray() {
        #expect(Color.statusNeutralSubtle == Color.systemGray5)
        #expect(assetName(of: Color.statusNeutralSubtle) == nil)
        for scheme in [ColorScheme.light, .dark] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            #expect(Color.statusNeutralSubtle.resolve(in: env).opacity == 1, "\(scheme)")
        }
    }

    #if os(iOS)
    @MainActor
    @Test("iOS 上 systemGray5 与 UIColor.systemGray5 同值")
    func systemGray5MatchesUIKit() {
        for scheme in [ColorScheme.light, .dark] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            #expect(Color.systemGray5.resolve(in: env) == Color(uiColor: .systemGray5).resolve(in: env), "\(scheme)")
        }
    }
    #endif

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

    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func alpha(_ x: Int, _ y: Int) -> UInt8 {
            self.bytes[(y * self.width + x) * 4 + 3]
        }

        func bytes(where include: (Int, Int) -> Bool) -> [UInt8] {
            var out: [UInt8] = []
            for y in 0..<self.height {
                for x in 0..<self.width where include(x, y) {
                    let offset = (y * self.width + x) * 4
                    out.append(contentsOf: self.bytes[offset..<offset + 4])
                }
            }
            return out
        }
    }

    private func bitmap(_ view: some View) throws -> Bitmap {
        let image = try self.render(view)
        return Bitmap(width: image.width, height: image.height, bytes: self.pixels(of: image))
    }

    private struct CornerGeometry {
        let frame: CGRect
        let extent: Int
        let path: Path

        init(frame: CGRect) {
            self.frame = frame
            let path = CoreShape.rounded(CoreRadius.medium).path(in: frame)
            self.path = path
            let epsilon = 0.001
            var extent = 0
            while extent < Int(frame.width) / 2 {
                let x = frame.minX + CGFloat(extent)
                let row = [CGPoint(x: x + epsilon, y: frame.minY + epsilon), CGPoint(x: x + 1 - epsilon, y: frame.minY + epsilon)]
                if row.allSatisfy({ path.contains($0) }) { break }
                extent += 1
            }
            self.extent = extent
        }

        func inCornerSquare(_ x: Int, _ y: Int) -> Bool {
            let minX = Int(self.frame.minX)
            let minY = Int(self.frame.minY)
            let maxX = Int(self.frame.maxX)
            let maxY = Int(self.frame.maxY)
            guard x >= minX, x < maxX, y >= minY, y < maxY else { return false }
            return (x < minX + self.extent || x >= maxX - self.extent) && (y < minY + self.extent || y >= maxY - self.extent)
        }

        func isClearOfShape(_ x: Int, _ y: Int) -> Bool {
            let steps = 6
            for i in 0...steps {
                for j in 0...steps {
                    let point = CGPoint(
                        x: CGFloat(x) - Self.antialiasReach + (1 + 2 * Self.antialiasReach) * CGFloat(i) / CGFloat(steps),
                        y: CGFloat(y) - Self.antialiasReach + (1 + 2 * Self.antialiasReach) * CGFloat(j) / CGFloat(steps)
                    )
                    if self.path.contains(point) { return false }
                }
            }
            return true
        }

        static let antialiasReach: CGFloat = 1
    }

    private static func opaqueBounds(of bitmap: Bitmap) -> CGRect {
        var minX = bitmap.width, minY = bitmap.height, maxX = -1, maxY = -1
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where bitmap.alpha(x, y) != 0 {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        return maxX < 0 ? .zero : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func legacy(_ level: StatusLevel, _ body: String, bordered: Bool, corners: LegacyBannerCorners, contentHidden: Bool = false) -> some View {
        LegacyBanner(level: level, bordered: bordered, corners: corners, contentHidden: contentHidden) { Text(body) }
    }

    private func current(_ level: StatusLevel, _ body: String, bordered: Bool) -> AnyView {
        bordered
            ? AnyView(Banner(level: level) { Text(body) }.bannerStyle(BorderedBannerStyle()))
            : AnyView(Banner(level: level) { Text(body) })
    }

    private func expectOnlyCornersChanged(level: StatusLevel, body: String, bordered: Bool) throws {
        for scheme in [ColorScheme.light, .dark] {
            let label = "\(level) \(scheme) bordered=\(bordered) body=\(body.prefix(12))"
            _ = try self.bitmap(self.host(self.current(level, body, bordered: bordered)).environment(\.colorScheme, scheme))
            let now = try self.bitmap(self.host(self.current(level, body, bordered: bordered)).environment(\.colorScheme, scheme))
            let square = try self.bitmap(self.host(self.legacy(level, body, bordered: bordered, corners: .square)).environment(\.colorScheme, scheme))
            let rounded = try self.bitmap(self.host(self.legacy(level, body, bordered: bordered, corners: .rounded)).environment(\.colorScheme, scheme))
            let backgroundOnly = try self.bitmap(
                self.host(self.legacy(level, body, bordered: bordered, corners: .square, contentHidden: true)).environment(\.colorScheme, scheme)
            )
            let sizes = [square, rounded, backgroundOnly].map { [$0.width, $0.height] }
            #expect(sizes.allSatisfy { $0 == [now.width, now.height] }, "\(label)：尺寸与旧实现不同")
            guard sizes.allSatisfy({ $0 == [now.width, now.height] }) else { continue }

            expectBitmapsEquivalent(now.bytes, rounded.bytes, maxChannelDelta: 1, "\(label)：与加同样圆角的旧实现整帧不同")

            let geometry = CornerGeometry(frame: Self.opaqueBounds(of: backgroundOnly))
            #expect(geometry.extent > 0 && CGFloat(geometry.extent) < geometry.frame.height / 2, "\(label)：圆角延伸 \(geometry.extent)px 不合理")
            let outsideCorners = { (x: Int, y: Int) in !geometry.inCornerSquare(x, y) }
            let inCorners = { (x: Int, y: Int) in geometry.inCornerSquare(x, y) }
            let cutAway = { (x: Int, y: Int) in geometry.inCornerSquare(x, y) && geometry.isClearOfShape(x, y) }
            expectBitmapsEquivalent(now.bytes(where: outsideCorners), square.bytes(where: outsideCorners), maxChannelDelta: 1, "\(label)：四角以外与直角旧实现不同")
            expectBitmapsDiffer(now.bytes(where: inCorners), square.bytes(where: inCorners), "\(label)：四角与直角旧实现相同，圆角没生效")
            let cutAwayPixels = now.bytes(where: cutAway)
            #expect(!cutAwayPixels.isEmpty, "\(label)：没有落在形状外的角像素")
            #expect(cutAwayPixels.allSatisfy { $0 == 0 }, "\(label)：形状外的角区有像素")
            expectBitmapsEquivalent(square.bytes(where: cutAway), backgroundOnly.bytes(where: cutAway), maxChannelDelta: 1, "\(label)：内容伸进了被圆角切掉的区域")
        }
    }

    @Test("只有正文的 Banner 与本 Issue 前的实现（d8915ba^ 原样拷贝）渲染尺寸一致（短 / 多行正文，两条腿都跑）")
    func bodyOnlyBannerMatchesLegacySize() throws {
        for level in Self.levels {
            for body in Self.bodies {
                for bordered in [false, true] {
                    let now = self.bannerSize(self.current(level, body, bordered: bordered))
                    let old = self.bannerSize(self.legacy(level, body, bordered: bordered, corners: .square))
                    #expect(now != .zero, "尺寸探针未回调")
                    #expect(now == old, "\(level) bordered=\(bordered) body=\(body.prefix(12))：\(now) ≠ \(old)")
                }
            }
        }
    }

    @Test("只有正文的 neutral Banner 与旧实现相比只有四角变圆（neutral 只用系统色，两条腿都跑）")
    func bodyOnlyNeutralBannerOnlyCornersChanged() throws {
        for body in Self.bodies {
            for bordered in [false, true] {
                try self.expectOnlyCornersChanged(level: .neutral, body: body, bordered: bordered)
            }
        }
    }

    @Test(
        "只有正文的 Banner 五档与旧实现相比只有四角变圆（light / dark × 短 / 多行 × 描边有无）",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：bundle 里没有 Assets.car（SwiftPM native 腿），info / success / warning / danger 的底色与前景取自 \
            asset catalog，在这条腿上解析为全透明。本条在 iOS Simulator 腿上跑；native 腿由尺寸判据与 neutral 像素判据兜。
            """
        )
    )
    func bodyOnlyBannerOnlyCornersChanged() throws {
        for level in Self.levels {
            for body in Self.bodies {
                for bordered in [false, true] {
                    try self.expectOnlyCornersChanged(level: level, body: body, bordered: bordered)
                }
            }
        }
    }

    @Test("neutral 底色不透明：叠在不同底色上，四角以外逐像素一致（两条腿都跑）")
    func neutralBannerIgnoresBackdrop() throws {
        for scheme in [ColorScheme.light, .dark] {
            for bordered in [false, true] {
                let banner = self.current(.neutral, Self.bodies[1], bordered: bordered)
                let onLight = try self.bitmap(self.host(banner).background(Color(white: 0.95)).environment(\.colorScheme, scheme))
                let onDark = try self.bitmap(self.host(banner).background(Color(white: 0.1)).environment(\.colorScheme, scheme))
                #expect(onLight.width == onDark.width && onLight.height == onDark.height)
                let bare = try self.bitmap(self.host(banner).environment(\.colorScheme, scheme))
                let geometry = CornerGeometry(frame: Self.opaqueBounds(of: bare))
                #expect(geometry.frame.width > 0)
                let outsideCorners = { (x: Int, y: Int) in geometry.frame.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) && !geometry.inCornerSquare(x, y) }
                expectBitmapsEquivalent(
                    onLight.bytes(where: outsideCorners), onDark.bytes(where: outsideCorners),
                    maxChannelDelta: 1,
                    "\(scheme) bordered=\(bordered)：neutral 底色随背后底色变化"
                )
            }
        }
    }

    private final class RegionProbe {
        var rects: [BannerRegion: CGRect] = [:]
        var size: CGSize = .zero

        func record(_ rects: [BannerRegion: CGRect], size: CGSize) {
            self.rects = rects
            self.size = size
        }
    }

    private func probed(_ banner: some View, _ probe: RegionProbe) -> some View {
        banner.overlayPreferenceValue(BannerRegionAnchorsKey.self) { anchors in
            GeometryReader { proxy in
                let _ = probe.record(anchors.mapValues { proxy[$0] }, size: proxy.size)
                Color.clear
            }
        }
    }

    private func extendedBanner(titled: Bool, bordered: Bool) -> AnyView {
        let message: LocalizedStringKey = "Restart the app to finish installing version 2.4."
        let actions = {
            Group {
                Button("Restart now") {}
                Button("Later") {}
            }
        }
        let banner = titled
            ? Banner(level: .neutral, title: "Update available", message: message, actions: actions, onDismiss: {})
            : Banner(level: .neutral, message: message, actions: actions, onDismiss: {})
        return bordered ? AnyView(banner.bannerStyle(BorderedBannerStyle())) : AnyView(banner)
    }

    private func expectExtendedContentInsideShape(_ size: DynamicTypeSize) throws {
        for scheme in [ColorScheme.light, .dark] {
            for bordered in [false, true] {
                for titled in [true, false] {
                    let label = "\(size) \(scheme) bordered=\(bordered) titled=\(titled)"
                    let probe = RegionProbe()
                    let margin: CGFloat = 40
                    let view = self.probed(self.extendedBanner(titled: titled, bordered: bordered), probe)
                        .frame(width: 320)
                        .padding(margin)
                        .dynamicTypeSize(size)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try #require(renderer.cgImage, "ImageRenderer 未产出位图")
                    let bitmap = Bitmap(width: image.width, height: image.height, bytes: self.pixels(of: image))

                    let expected: Set<BannerRegion> = titled ? [.icon, .title, .body, .actions, .dismiss] : [.icon, .body, .actions, .dismiss]
                    #expect(Set(probe.rects.keys) == expected, "\(label)：内容区探针 \(probe.rects.keys)")
                    let shape = CornerGeometry(frame: CGRect(origin: .zero, size: probe.size))
                    for (region, rect) in probe.rects {
                        let inset = rect.insetBy(dx: 0.01, dy: 0.01)
                        let corners = [inset.origin, CGPoint(x: inset.maxX, y: inset.minY), CGPoint(x: inset.minX, y: inset.maxY), CGPoint(x: inset.maxX, y: inset.maxY)]
                        #expect(!rect.isEmpty, "\(label)：\(region) 探针为空")
                        #expect(corners.allSatisfy { shape.path.contains($0) }, "\(label)：\(region) \(rect) 伸出圆角形状 \(probe.size)")
                    }

                    let placed = CornerGeometry(frame: CGRect(x: margin, y: margin, width: probe.size.width, height: probe.size.height))
                    let reach = placed.frame.insetBy(dx: -CornerGeometry.antialiasReach, dy: -CornerGeometry.antialiasReach)
                    var clear = 0
                    var painted: [String] = []
                    for y in 0..<bitmap.height {
                        for x in 0..<bitmap.width {
                            let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                            let isClear = !reach.intersects(pixel) || (placed.inCornerSquare(x, y) && placed.isClearOfShape(x, y))
                            guard isClear else { continue }
                            clear += 1
                            if bitmap.alpha(x, y) != 0 { painted.append("(\(x), \(y))") }
                        }
                    }
                    #expect(clear > 0, "\(label)：没有落在形状外的像素")
                    #expect(painted.isEmpty, "\(label)：圆角形状外有 \(painted.count)/\(clear) 个像素被画到，如 \(painted.prefix(4))")
                }
            }
        }
    }

    private static let overflowSide: CGFloat = 12

    private static func isOverflowRed(_ bitmap: Bitmap, _ x: Int, _ y: Int) -> Bool {
        let offset = (y * bitmap.width + x) * 4
        return Array(bitmap.bytes[offset..<offset + 4]) == [255, 0, 0, 255]
    }

    private func overflowMarker(offset: CGSize) -> some View {
        Color(red: 1, green: 0, blue: 0)
            .frame(width: Self.overflowSide, height: Self.overflowSide)
            .offset(offset)
    }

    private func expectOverflowDrawn(label: String, build: (CGSize) -> AnyView, region: BannerRegion, corner: (CGSize) -> CGPoint) throws {
        let margin: CGFloat = 40
        let probe = RegionProbe()
        _ = ImageRenderer(content: self.probed(build(.zero), probe).frame(width: 320, alignment: .leading)).cgImage
        let anchor = try #require(probe.rects[region], "\(label)：\(region) 探针未回调")
        let target = corner(probe.size)
        let half = Self.overflowSide / 2
        let offset = CGSize(width: target.x - half - anchor.minX, height: target.y - half - anchor.minY)

        let renderer = ImageRenderer(content: build(offset).frame(width: 320, alignment: .leading).padding(margin))
        renderer.scale = 1
        let image = try #require(renderer.cgImage, "ImageRenderer 未产出位图")
        let bitmap = Bitmap(width: image.width, height: image.height, bytes: self.pixels(of: image))
        let side = Int(Self.overflowSide)
        let originX = Int(margin + target.x - half)
        let originY = Int(margin + target.y - half)
        var red = 0
        for y in originY..<(originY + side) {
            for x in originX..<(originX + side) where Self.isOverflowRed(bitmap, x, y) {
                red += 1
            }
        }
        let shape = CornerGeometry(frame: CGRect(x: margin, y: margin, width: probe.size.width, height: probe.size.height))
        let outside = (originY..<(originY + side)).flatMap { y in (originX..<(originX + side)).map { (x: $0, y: y) } }
            .filter { shape.isClearOfShape($0.x, $0.y) }.count
        #expect(outside > 0, "\(label)：溢出块没有越过圆角")
        #expect(red == side * side, "\(label)：越过圆角的溢出块只画出 \(red)/\(side * side) 像素（其中 \(outside) 个在形状外）——容器在裁切内容")
    }

    @Test("内容越过圆角时照常画出：容器不裁切（只有正文 / 带动作两种分支，两条腿都跑）")
    func overflowingContentIsNotClipped() throws {
        for bordered in [false, true] {
            try self.expectOverflowDrawn(
                label: "body-only bordered=\(bordered)",
                build: { offset in
                    let banner = Banner(level: .neutral) {
                        Text(verbatim: "Saved").overlay(alignment: .topLeading) { self.overflowMarker(offset: offset) }
                    }
                    return bordered ? AnyView(banner.bannerStyle(BorderedBannerStyle())) : AnyView(banner)
                },
                region: .body,
                corner: { _ in .zero }
            )
            try self.expectOverflowDrawn(
                label: "extended bordered=\(bordered)",
                build: { offset in
                    let banner = Banner(level: .neutral, title: "Update available", message: "Restart to finish installing.") {
                        self.overflowMarker(offset: offset)
                    } onDismiss: {}
                    return bordered ? AnyView(banner.bannerStyle(BorderedBannerStyle())) : AnyView(banner)
                },
                region: .actions,
                corner: { size in CGPoint(x: 0, y: size.height) }
            )
        }
    }

    @Test("带标题 / 双动作 / 关闭钮的 Banner：内容全部落在圆角形状内（常规字号，两条腿都跑）")
    func extendedBannerContentStaysInsideShape() throws {
        try self.expectExtendedContentInsideShape(.large)
    }


    #if os(iOS)
    @Test("AX5 下带标题 / 双动作 / 关闭钮的 Banner：内容全部落在圆角形状内")
    func extendedBannerContentStaysInsideShapeAtAX5() throws {
        try self.expectExtendedContentInsideShape(.accessibility5)
    }

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

private enum LegacyBannerCorners {
    case square
    case rounded
}

/// 只有正文形态的旧 `Banner` 布局（直角原样拷贝，另可选同样的圆角）。取色走**当前**的 `bannerPalette`，
/// 所以「只有四角不同」是在 neutral 底色改为 `statusNeutralSubtle` 之后量的；底色变更另由 neutral 调色板判据覆盖。
private struct LegacyBanner<Label: View>: View {
    let level: StatusLevel
    let bordered: Bool
    let corners: LegacyBannerCorners
    let contentHidden: Bool
    let label: Label

    init(level: StatusLevel, bordered: Bool, corners: LegacyBannerCorners, contentHidden: Bool, @ViewBuilder label: () -> Label) {
        self.level = level
        self.bordered = bordered
        self.corners = corners
        self.contentHidden = contentHidden
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
        .opacity(self.contentHidden ? 0 : 1)
        .accessibilityElement(children: .combine)
        .coreFont(.callout)
        .foregroundStyle(palette.foreground)
        .padding(CoreSpacing.md)
        .background {
            switch self.corners {
            case .square:
                if self.bordered {
                    Rectangle().fill(palette.background).bordered(style: palette.border)
                } else {
                    Rectangle().fill(palette.background)
                }
            case .rounded:
                let shape = CoreShape.rounded(CoreRadius.medium)
                if self.bordered {
                    shape.fill(palette.background).bordered(style: palette.border, shape: shape)
                } else {
                    shape.fill(palette.background)
                }
            }
        }
    }
}
