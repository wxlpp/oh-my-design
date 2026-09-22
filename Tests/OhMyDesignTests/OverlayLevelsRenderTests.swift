import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import OhMyDesign

// MARK: - 渲染辅助

// 新旧实现是两棵视图树：进程内首次渲染时圆角描边 / 字形的抗锯齿边会差 1 个 LSB（实测 36–81 字节），
// 所以「外观不变」一律走有界的 `expectBitmapsEquivalent(maxChannelDelta: 1)`；描边或底色真变了时偏差远大于 1。

@MainActor
enum OverlayRender {
    struct Frame {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func cropped(inset: Int) -> [UInt8]? {
            guard self.width > 2 * inset, self.height > 2 * inset else { return nil }
            var out: [UInt8] = []
            for y in inset..<(self.height - inset) {
                let start = (y * self.width + inset) * 4
                out.append(contentsOf: self.bytes[start..<(start + (self.width - 2 * inset) * 4)])
            }
            return out
        }

        func rgba(x: Int, y: Int) -> [UInt8]? {
            guard x >= 0, y >= 0, x < self.width, y < self.height else { return nil }
            let i = (y * self.width + x) * 4
            return Array(self.bytes[i..<(i + 4)])
        }
    }

    static func frame(
        _ view: some View,
        scheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .large,
        scale: CGFloat = 2
    ) -> Frame? {
        let renderer = ImageRenderer(
            content: view
                .environment(\.colorScheme, scheme)
                .dynamicTypeSize(dynamicTypeSize)
        )
        renderer.scale = scale
        #if canImport(UIKit)
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        guard let cg = renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        #endif
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Frame(width: w, height: h, bytes: buf)
    }
}

// MARK: - FR-B1 / FR-B2：Toast

@Suite("Issue #399：Toast danger 图标与 AX 字号布局")
@MainActor
struct ToastOverlayLevelsTests {
    private static let screenWidth: CGFloat = 402

    private static let items: [ToastItem] = [
        ToastItem(title: "Saved", level: .info),
        ToastItem(title: "Conversation archived", description: "It moves back to the inbox if you undo.", level: .neutral,
                  action: ToastAction("Undo") {}),
    ]

    @Test("danger 图标是 exclamationmark.circle（与 Banner 的 circle 族成组）")
    func dangerIconIsCircle() {
        #expect(ToastView.icon(for: .danger) == Image(systemName: "exclamationmark.circle"))
        #expect(ToastView.icon(for: .danger) != Image(systemName: "exclamationmark.octagon"))
    }

    private func newToast(_ item: ToastItem, _ presentation: ToastPresentation) -> some View {
        ToastView(item: item, edge: .top, presentation: presentation, isDismissing: false, onDismiss: {})
            .padding(.horizontal, CoreSpacing.lg)
            .frame(width: Self.screenWidth)
            .background(Color.surfaceCanvas)
    }

    private func legacyToast(_ item: ToastItem, _ presentation: ToastPresentation) -> some View {
        LegacyToastView(item: item, edge: .top, presentation: presentation, isDismissing: false, onDismiss: {})
            .padding(.horizontal, CoreSpacing.lg)
            .frame(width: Self.screenWidth)
            .background(Color.surfaceCanvas)
    }

    @Test(
        "常规字号下胶囊形态与改动前逐像素相同（danger 以外四档）",
        arguments: [DynamicTypeSize.large, .xxxLarge]
    )
    func capsuleRegularSizesMatchLegacy(size: DynamicTypeSize) {
        for scheme in [ColorScheme.light, .dark] {
            for template in Self.items {
                for level in [StatusLevel.info, .success, .warning, .neutral] {
                    let item = ToastItem(
                        id: template.id, title: template.title, description: template.description,
                        level: level, action: template.action
                    )
                    let now = OverlayRender.frame(self.newToast(item, .floatingCapsule), scheme: scheme, dynamicTypeSize: size)
                    let before = OverlayRender.frame(self.legacyToast(item, .floatingCapsule), scheme: scheme, dynamicTypeSize: size)
                    expectBitmapsEquivalent(now?.bytes, before?.bytes, maxChannelDelta: 1,
                                            "\(scheme) \(size) \(level) \(item.title)：常规字号胶囊外观变了")
                }
            }
        }
    }

    #if os(iOS)
    private final class LayoutBox {
        var layouts: [Text.LayoutKey.AnchoredLayout] = []
    }

    private func widestLine(_ view: some View, size: DynamicTypeSize) -> CGFloat? {
        let box = LayoutBox()
        let probed = view.onPreferenceChange(Text.LayoutKey.self) { value in
            MainActor.assumeIsolated { box.layouts = value }
        }
        let host = UIHostingController(rootView: probed.dynamicTypeSize(size))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: Self.screenWidth, height: 1600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let widths = box.layouts.flatMap { anchored in anchored.layout.map { $0.typographicBounds.width } }
        return widths.max()
    }

    private func wordWidth(_ word: String, weight: Font.Weight, size: DynamicTypeSize) -> CGFloat? {
        self.widestLine(
            Text(word).coreFont(.callout).fontWeight(weight).fixedSize(),
            size: size
        )
    }

    @Test(
        "AX 字号下标题里最长的单词不被从中间折断（所在行宽 ≥ 单词固有宽）",
        arguments: [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5]
    )
    func accessibilityTitleKeepsWordsWhole(size: DynamicTypeSize) {
        let item = Self.items[1]
        guard let word = self.wordWidth("Conversation", weight: .semibold, size: size) else {
            Issue.record("量不到单词固有宽 —— 不得当作通过")
            return
        }
        for presentation in ToastPresentation.allCases {
            guard let widest = self.widestLine(self.newToast(item, presentation), size: size) else {
                Issue.record("\(presentation) @ \(size)：量不到文字行宽")
                continue
            }
            #expect(widest >= word - 0.5,
                    "\(presentation) @ \(size)：最宽的行 \(widest) < 单词固有宽 \(word) —— 单词被从中间折断")
        }
    }

    @Test("非退化前置：改动前的胶囊在 AX5 下确实把单词从中间折断")
    func legacyCapsuleBreaksWordAtAX5() {
        let item = Self.items[1]
        let word = self.wordWidth("Conversation", weight: .semibold, size: .accessibility5)
        let widest = self.widestLine(self.legacyToast(item, .floatingCapsule), size: .accessibility5)
        guard let word, let widest else {
            Issue.record("量测失效 —— 不得当作通过")
            return
        }
        #expect(widest < word - 0.5, "改动前最宽行 \(widest) 已 ≥ 单词宽 \(word) —— 本判据在 AX5 下分辨不出折断")
    }
    #endif
}

// MARK: - FR-B3：floatingGlass 三种外壳

@Suite("Issue #399：floatingGlass 的横幅 / HUD / 胶囊外壳")
@MainActor
struct FloatingGlassChromeTests {
    private static let canvas = Color(red: 0.2, green: 0.5, blue: 0.9)

    @Test("胶囊 / 圆角（公开入口与 .floating）与改动前逐像素相同")
    func floatingChromeMatchesLegacy() {
        for scheme in [ColorScheme.light, .dark] {
            let pairs: [(String, AnyView, AnyView)] = [
                ("capsule",
                 AnyView(Text("Hi").padding().floatingGlass()),
                 AnyView(Text("Hi").padding().legacyFloatingGlass())),
                ("rounded interactive",
                 AnyView(Text("Hi").padding().floatingGlass(in: CoreShape.rounded(CoreRadius.large), isInteractive: true)),
                 AnyView(Text("Hi").padding().legacyFloatingGlass(in: CoreShape.rounded(CoreRadius.large), isInteractive: true))),
                ("rounded chrome .floating",
                 AnyView(Text("Hi").padding().floatingGlass(in: RoundedRectangle(cornerRadius: CoreRadius.xLarge, style: .continuous), chrome: .floating)),
                 AnyView(Text("Hi").padding().legacyFloatingGlass(in: RoundedRectangle(cornerRadius: CoreRadius.xLarge, style: .continuous)))),
            ]
            for (name, now, before) in pairs {
                expectBitmapsEquivalent(
                    OverlayRender.frame(now.padding(8).background(Self.canvas), scheme: scheme)?.bytes,
                    OverlayRender.frame(before.padding(8).background(Self.canvas), scheme: scheme)?.bytes,
                    maxChannelDelta: 1,
                    "\(scheme) \(name)：胶囊 / 圆角外壳观感变了"
                )
            }
        }
    }

    @Test("横幅外壳不画 hairline：等于去掉描边的旧外壳，且与旧外壳不同")
    func bannerChromeDropsHairline() {
        for scheme in [ColorScheme.light, .dark] {
            let body = Color.clear.frame(width: 200, height: 60)
            let now = OverlayRender.frame(
                body.floatingGlass(in: Rectangle(), chrome: .edgeBanner(.top)).padding(8).background(Self.canvas),
                scheme: scheme
            )
            let unbordered = OverlayRender.frame(
                body.background(
                    Rectangle()
                        .inset(by: CoreButtonMetrics.glassInset)
                        .fill(.background.opacity(0.64))
                        .glassEffect(Glass.regular, in: Rectangle())
                ).padding(8).background(Self.canvas),
                scheme: scheme
            )
            let before = OverlayRender.frame(
                body.legacyFloatingGlass(in: Rectangle()).padding(8).background(Self.canvas),
                scheme: scheme
            )
            expectBitmapsEquivalent(now?.bytes, unbordered?.bytes, maxChannelDelta: 1, "\(scheme)：横幅外壳仍有描边或底色变了")
            expectBitmapsDiffer(now?.bytes, before?.bytes, "\(scheme)：横幅外壳与旧外壳相同 —— hairline 没去掉")
        }
    }

    @Test("横幅外壳只延伸进它贴的那条边的安全区；胶囊 / HUD 不延伸")
    func bleedFollowsAnchoredEdge() {
        #expect(FloatingGlassChrome.edgeBanner(.top).bleed == .top)
        #expect(FloatingGlassChrome.edgeBanner(.bottom).bleed == .bottom)
        #expect(FloatingGlassChrome.floating.bleed.isEmpty)
        #expect(FloatingGlassChrome.hud.bleed.isEmpty)
    }

    @Test("Toast 三形态各取各的外壳：胶囊 .floating、横幅 .edgeBanner(edge)、HUD .hud")
    func toastPicksChromePerPresentation() {
        for edge in [VerticalEdge.top, .bottom] {
            #expect(ToastContainerDecoration.chrome(for: .floatingCapsule, edge: edge) == .floating)
            #expect(ToastContainerDecoration.chrome(for: .fullWidthBanner, edge: edge) == .edgeBanner(edge))
            #expect(ToastContainerDecoration.chrome(for: .centeredHUD, edge: edge) == .hud)
        }
        #expect(FloatingGlassChrome.floating.border == .hairline)
        #expect(FloatingGlassChrome.edgeBanner(.top).border == .none)
        #expect(FloatingGlassChrome.hud.border == .hairline)
        #expect(FloatingGlassChrome.hud.backing == .opaque)
    }

    @Test(".floating 的底色层与改动前逐像素相同（经实色 backgroundStyle 显形）")
    func floatingBackingMatchesLegacy() {
        let probe = Color(red: 0, green: 0.6, blue: 0)
        for scheme in [ColorScheme.light, .dark] {
            let now = OverlayRender.frame(
                FloatingGlassChrome.floating.backingView(in: Capsule(style: .continuous))
                    .frame(width: 120, height: 44).backgroundStyle(probe),
                scheme: scheme
            )
            let before = OverlayRender.frame(
                Capsule(style: .continuous).inset(by: CoreButtonMetrics.glassInset).fill(.background.opacity(0.64))
                    .frame(width: 120, height: 44).backgroundStyle(probe),
                scheme: scheme
            )
            #expect(now?.rgba(x: 120, y: 44)?[3] ?? 0 > 0, "\(scheme)：底色层没画出来 —— 下面的相等是空比较")
            expectBitmapsEquivalent(now?.bytes, before?.bytes, maxChannelDelta: 1, "\(scheme)：.floating 底色层变了")
        }
    }

    private static let hudShape = RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)

    private var textUnderlay: some View {
        Text("Show again Show again")
            .font(.system(size: 40, weight: .heavy))
            .foregroundStyle(Color.contentPrimary)
            .lineLimit(2)
            .frame(width: 200, height: 80)
            .background(Color.surfaceCanvas)
    }

    private func interior(_ backing: some View, overText: Bool, scheme: ColorScheme) -> [UInt8]? {
        let view = ZStack {
            if overText {
                self.textUnderlay
            } else {
                Color.surfaceCanvas
            }
            backing
        }
        .frame(width: 200, height: 80)
        return OverlayRender.frame(view, scheme: scheme)?.cropped(inset: 2 * Int(CoreRadius.large))
    }

    @Test("HUD 外壳的底色层不透出底层文字：内部像素与底下有没有文字无关")
    func hudBackingHidesUnderlyingText() {
        for scheme in [ColorScheme.light, .dark] {
            let backing = FloatingGlassChrome.hud.backingView(in: Self.hudShape)
            expectBitmapsEqual(
                self.interior(backing, overText: true, scheme: scheme),
                self.interior(backing, overText: false, scheme: scheme),
                "\(scheme)：HUD 底色层透出了底层文字"
            )
        }
    }

    @Test("非退化前置：改动前的底色层（64% 背景色）确实透出底层文字")
    func legacyBackingShowsUnderlyingText() {
        for scheme in [ColorScheme.light, .dark] {
            let legacy = Self.hudShape.inset(by: CoreButtonMetrics.glassInset).fill(.background.opacity(0.64))
            expectBitmapsDiffer(
                self.interior(legacy, overText: true, scheme: scheme),
                self.interior(legacy, overText: false, scheme: scheme),
                "\(scheme)：旧底色层在本平台也不透字 —— 上一条判据分辨不出透字"
            )
        }
    }
}

// MARK: - FR-B4：elevated 层 content 描边

@Suite("Issue #399：只有 elevated 的 content 去掉描边")
@MainActor
struct SurfaceElevatedBorderRenderTests {
    private static let kinds: [SurfaceKind] = [
        .canvas, .content, .control, .floating, .grouped, .canvasSubtle, .panel, .sidebar, .card,
    ]

    private func tile(_ kind: SurfaceKind, legacy: Bool) -> some View {
        let body = Color.clear.frame(width: 60, height: 40)
        return Group {
            if legacy {
                body.modifier(LegacySurfaceModifier(kind: kind))
            } else {
                body.surface(kind)
            }
        }
    }

    private func nested(_ kind: SurfaceKind, legacy: Bool) -> some View {
        Group {
            if legacy {
                self.tile(kind, legacy: true).padding(12).modifier(LegacySurfaceModifier(kind: .content))
            } else {
                self.tile(kind, legacy: false).padding(12).surface(.content)
            }
        }
        .padding(8)
        .background(Color.surfaceCanvas)
    }

    @Test("base / raised 层：每个角色与改动前逐像素相同")
    func topLevelSurfacesMatchLegacy() {
        for scheme in [ColorScheme.light, .dark] {
            for kind in Self.kinds {
                expectBitmapsEquivalent(
                    OverlayRender.frame(self.tile(kind, legacy: false).padding(8).background(Color.surfaceCanvas), scheme: scheme)?.bytes,
                    OverlayRender.frame(self.tile(kind, legacy: true).padding(8).background(Color.surfaceCanvas), scheme: scheme)?.bytes,
                    maxChannelDelta: 1,
                    "\(scheme) \(kind)：顶层外观变了"
                )
            }
        }
    }

    @Test("嵌进 content：只有 content 变了，其余角色与改动前逐像素相同")
    func onlyElevatedContentChanges() {
        for scheme in [ColorScheme.light, .dark] {
            for kind in Self.kinds {
                let now = OverlayRender.frame(self.nested(kind, legacy: false), scheme: scheme)
                let before = OverlayRender.frame(self.nested(kind, legacy: true), scheme: scheme)
                if kind == .content {
                    expectBitmapsDiffer(now?.bytes, before?.bytes, "\(scheme)：elevated content 的描边没变")
                } else {
                    expectBitmapsEquivalent(now?.bytes, before?.bytes, maxChannelDelta: 1, "\(scheme) \(kind)：嵌套外观变了")
                }
            }
        }
    }

    @Test("elevated content 与 elevated grouped 逐像素相同（合流）")
    func elevatedContentMatchesGrouped() {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsEquivalent(
                OverlayRender.frame(self.nested(.content, legacy: false), scheme: scheme)?.bytes,
                OverlayRender.frame(self.nested(.grouped, legacy: false), scheme: scheme)?.bytes,
                maxChannelDelta: 1,
                "\(scheme)：elevated content 与 grouped 仍可区分"
            )
        }
    }
}
