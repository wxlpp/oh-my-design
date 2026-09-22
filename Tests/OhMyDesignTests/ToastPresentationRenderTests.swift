import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import OhMyDesign

@MainActor
struct ToastPresentationRenderTests {
    private static let containerWidth: CGFloat = 320

    // MARK: harness

    private func cgImage(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.cgImage
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        return renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }

    private func pixels(_ view: some View) -> Data? {
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Data(buf)
    }

    private func overlayInk(
        _ presentation: ToastPresentation,
        edge: VerticalEdge = .top,
        containerWidth: CGFloat? = nil,
        message: String = "Hi"
    ) -> Int? {
        let host = ToastHost()
        host.show(message, level: .info)
        let view = ToastOverlay(host: host, edge: edge, presentation: presentation)
            .frame(width: containerWidth ?? Self.containerWidth)
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, maxX = -1
        for y in 0..<h {
            for x in 0..<w where buf[(y * w + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        return maxX >= minX ? maxX - minX + 1 : nil
    }

    private func overlayInkMinX(_ presentation: ToastPresentation) -> Int? {
        let host = ToastHost()
        host.show("Hi", level: .neutral)
        guard let bytes = self.pixels(
            ToastOverlay(host: host, edge: .top, presentation: presentation).frame(width: Self.containerWidth)
        ) else { return nil }
        let w = Int(Self.containerWidth), h = bytes.count / (w * 4)
        var minX = w
        for y in 0..<h {
            for x in 0..<minX where bytes[(y * w + x) * 4 + 3] > 0 {
                minX = x
                break
            }
        }
        return minX < w ? minX : nil
    }

    private func rowInk(_ presentation: ToastPresentation, atFraction f: Double) -> Int? {
        let host = ToastHost()
        host.show("Hi", level: .info)
        let view = ToastOverlay(host: host, edge: .top, presentation: presentation)
            .frame(width: Self.containerWidth)
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var inkRows: [Int] = []
        for y in 0..<h where (0..<w).contains(where: { buf[(y * w + $0) * 4 + 3] > 0 }) {
            inkRows.append(y)
        }
        guard let first = inkRows.first, let last = inkRows.last, last > first else { return nil }
        let y = first + Int(Double(last - first) * f)
        var minX = w, maxX = -1
        for x in 0..<w where buf[(y * w + x) * 4 + 3] > 0 {
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
        return maxX >= minX ? maxX - minX + 1 : nil
    }

    private func overlayPixels(_ presentation: ToastPresentation, edge: VerticalEdge) -> Data? {
        let host = ToastHost()
        host.show("Hi", level: .info)
        return self.pixels(
            ToastOverlay(host: host, edge: edge, presentation: presentation)
                .frame(width: Self.containerWidth)
        )
    }

    private func mountedSize(_ presentation: ToastPresentation, edge: VerticalEdge = .top, empty: Bool = false) -> CGSize? {
        let host = ToastHost()
        if !empty { host.show("Hi", level: .info) }
        let view = Color.blue.frame(width: Self.containerWidth, height: 120)
            .modifier(ToastHostModifier(host: host, edge: edge, presentation: presentation))
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size
        #else
        return renderer.nsImage?.size
        #endif
    }

    // MARK: A9 —— 注入缝真的接上了（其余挂载层级断言的前置）

    @Test("A9 承重：注入的 host 真的驱动了产线挂载路径")
    func injectedHostDrivesProductionMount() {
        let empty = self.mountedSize(.floatingCapsule, empty: true)
        let filled = self.mountedSize(.floatingCapsule)
        #expect(empty != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        #expect(filled != nil, "渲染失败")
        #expect((filled?.height ?? 0) > (empty?.height ?? 0),
                "注入的 host 没驱动渲染：空 \(empty?.height ?? -1) / 有 toast \(filled?.height ?? -1)")
    }

    // MARK: A6 —— .centeredHUD 不走 safeAreaInset

    @Test("A6 承重：.centeredHUD 不因挂载增高，另两个形态会")
    func centeredHUDDoesNotInsetContainer() {
        let baseline = self.mountedSize(.centeredHUD, empty: true)
        let hud = self.mountedSize(.centeredHUD)
        let capsule = self.mountedSize(.floatingCapsule)
        let banner = self.mountedSize(.fullWidthBanner)
        for (name, size) in [("hud", hud), ("capsule", capsule), ("banner", banner), ("baseline", baseline)] {
            #expect(size != nil, "\(name) 渲染失败 —— 不得当作通过")
        }
        #expect(hud?.height == baseline?.height,
                ".centeredHUD 仍在撑高容器（说明还走着 safeAreaInset）：\(hud?.height ?? -1) vs 基线 \(baseline?.height ?? -1)")
        #expect((capsule?.height ?? 0) > (baseline?.height ?? 0), "capsule 没撑高容器 —— 挂载路径可能已坏")
        #expect((banner?.height ?? 0) > (baseline?.height ?? 0), "banner 没撑高容器 —— 挂载路径可能已坏")
    }

    // MARK: A5 —— banner 与 capsule 渲染不同

    @Test("A5 承重：fullWidthBanner 与 floatingCapsule 渲染不同")
    func bannerDiffersFromCapsule() {
        let capsule = self.overlayPixels(.floatingCapsule, edge: .top)
        let banner = self.overlayPixels(.fullWidthBanner, edge: .top)
        #expect(capsule != nil, "渲染失败 —— 不得当作通过")
        #expect(banner != nil, "渲染失败")
        expectBitmapsDiffer(capsule, banner, "banner 与 capsule 位图相同 —— 形态分支没生效")
    }

    @Test("A5b 承重：容器形状真的不同（banner 是矩形，capsule 有圆角）")
    func containerShapeDiffers() {
        let capsuleTop = self.rowInk(.floatingCapsule, atFraction: 0.06)
        let capsuleMid = self.rowInk(.floatingCapsule, atFraction: 0.5)
        for (name, v) in [("capsuleTop", capsuleTop), ("capsuleMid", capsuleMid)] {
            #expect(v != nil, "\(name) 量测失败 —— 不得当作通过")
        }
        #expect((capsuleTop ?? 0) < (capsuleMid ?? 0),
                "capsule 顶行 \(capsuleTop ?? -1) 未窄于中行 \(capsuleMid ?? -1) —— 圆角没了")
        // banner 外壳无 hairline，玻璃与 `.background` 底色 `ImageRenderer` 都不画 ⇒ 位图里没有轮廓可量，改核形状选择。
        for isSingleRow in [true, false] {
            #expect(ToastContainerDecoration.shape(for: .fullWidthBanner, isSingleRow: isSingleRow) == .rectangle)
            #expect(ToastContainerDecoration.shape(for: .floatingCapsule, isSingleRow: isSingleRow) != .rectangle)
            #expect(ToastContainerDecoration.shape(for: .centeredHUD, isSingleRow: isSingleRow) != .rectangle)
        }
    }

    // MARK: A10 / A10b —— edge 在 .centeredHUD 下真的无效

    @Test("A10 承重：.centeredHUD 下 edge 不影响渲染（逐字节相等）")
    func edgeHasNoEffectUnderCenteredHUD() {
        let top = self.overlayPixels(.centeredHUD, edge: .top)
        let bottom = self.overlayPixels(.centeredHUD, edge: .bottom)
        #expect(top != nil, "渲染失败 —— 不得当作通过（否则本条会因两张空图而恒真）")
        // ⚠️ 相等断言走容差入口（#317）：toast 文案字形 AA 边在本平台无逐字节确定性。
        expectBitmapsEquivalent(top, bottom, maxChannelDelta: 1,
                ".centeredHUD 下 edge 仍在影响渲染 —— 「edge 静默无效」的定案在像素层面为假")
    }

    @Test("A10b 承重：A10 的非退化前置 —— 换 edge 在本平台确实能产生位图差异")
    func edgeDoesAffectCapsule() {
        let top = self.overlayPixels(.floatingCapsule, edge: .top)
        let bottom = self.overlayPixels(.floatingCapsule, edge: .bottom)
        #expect(top != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(top, bottom,
                ".floatingCapsule 下换 edge 位图相同 —— 说明 edge 根本没进渲染，A10 的相等就没有意义了")
    }

    // MARK: A11 —— 「占多宽」这个差异真的存在

    @Test("A11 承重：三形态的实际占宽符合各自定义")
    func inkWidthsMatchPresentation() {
        let capsule = self.overlayInk(.floatingCapsule)
        let banner = self.overlayInk(.fullWidthBanner)
        let hud = self.overlayInk(.centeredHUD)
        for (name, ink) in [("capsule", capsule), ("banner", banner), ("hud", hud)] {
            #expect(ink != nil, "\(name) ink 量测失败 —— 不得当作通过")
            #expect((ink ?? 0) > 0, "\(name) ink 为 0 —— 渲染为空图，下面的比较会假通过")
        }
        // banner 外壳在位图里不可见（见 A5b），改量内容的左缘：banner 不留外侧水平边距，只剩内容内边距。
        let bannerMinX = self.overlayInkMinX(.fullWidthBanner)
        let capsuleMinX = self.overlayInkMinX(.floatingCapsule)
        #expect((Int(CoreSpacing.md)...Int(CoreSpacing.md) + 2).contains(bannerMinX ?? -1),
                "banner 内容左缘 \(bannerMinX ?? -1) 不在内容内边距 \(Int(CoreSpacing.md)) 处 —— banner 没贴容器边")
        #expect(abs((capsuleMinX ?? -99) - Int(CoreSpacing.lg)) <= 1,
                "capsule 左缘 \(capsuleMinX ?? -1) 不在外侧边距 \(Int(CoreSpacing.lg)) 处 —— 上一条的对照失效")
        #expect((hud ?? Int.max) < (capsule ?? 0),
                "hud 未比 capsule 窄：hud \(hud ?? -1) / capsule \(capsule ?? -1)")
    }

    @Test("A11b 承重：.centeredHUD 真的 content-hugging（ink 不随容器宽变化）")
    func centeredHUDHugsContent() {
        let hud320 = self.overlayInk(.centeredHUD, containerWidth: 320)
        let hud500 = self.overlayInk(.centeredHUD, containerWidth: 500)
        let capsule320 = self.overlayInk(.floatingCapsule, containerWidth: 320)
        let capsule500 = self.overlayInk(.floatingCapsule, containerWidth: 500)
        for (name, v) in [("hud320", hud320), ("hud500", hud500),
                          ("capsule320", capsule320), ("capsule500", capsule500)] {
            #expect(v != nil, "\(name) 量测失败 —— 不得当作通过")
            #expect((v ?? 0) > 0, "\(name) 为 0 —— 空图，下面的比较会假通过")
        }
        #expect(hud320 == hud500,
                ".centeredHUD 的 ink 随容器宽变了（\(hud320 ?? -1) → \(hud500 ?? -1)）—— 它在撑满，不是 content-hugging")

        let shortInk = self.overlayInk(.centeredHUD, message: "Hi")
        let longInk = self.overlayInk(.centeredHUD, message: "A considerably longer toast message")
        #expect(shortInk != nil && longInk != nil, "量测失败 —— 不得当作通过")
        #expect((longInk ?? 0) > (shortInk ?? 0),
                ".centeredHUD 的 ink 不随内容长度变（短 \(shortInk ?? -1) / 长 \(longInk ?? -1)）—— 它被钉成了固定宽度，不是 content-hugging")
        #expect((longInk ?? Int.max) <= Int(Self.containerWidth),
                ".centeredHUD 的长文本 ink \(longInk ?? -1) 超出容器宽 \(Int(Self.containerWidth)) —— hugging 不该突破容器")

        #expect((capsule320 ?? 0) < (capsule500 ?? 0),
                "capsule 的 ink 没随容器宽变 —— 换容器宽这个操作没生效，上一条的相等就没有意义了")
    }

    // MARK: A7 —— 遍历 allCases

    @Test("A7 兜底：全部形态都能渲染出非空内容")
    func allPresentationsRender() {
        for presentation in ToastPresentation.allCases {
            let ink = self.overlayInk(presentation)
            #expect(ink != nil, "\(presentation) 渲染失败")
            #expect((ink ?? 0) > 0, "\(presentation) 渲染为空图")
        }
    }
    // MARK: action label is never truncated

    private static let probeRed = Color(red: 1, green: 0, blue: 0)

    private func redInk(_ view: some View, dynamicTypeSize: DynamicTypeSize) -> (width: Int, pixels: Int)? {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(dynamicTypeSize))
        renderer.scale = 1
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
        var minX = w, maxX = -1, count = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                if buf[i + 3] > 128, buf[i] > 180, buf[i + 1] < 90, buf[i + 2] < 90 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    count += 1
                }
            }
        }
        return maxX >= minX ? (maxX - minX + 1, count) : nil
    }

    private func standaloneActionInk(
        _ label: String,
        dynamicTypeSize: DynamicTypeSize,
        backdrop: Color = .clear
    ) -> (width: Int, pixels: Int)? {
        self.redInk(
            Button {} label: { Text(label).fontWeight(.semibold) }
                .buttonStyle(.light(role: .primary))
                .controlSize(.small)
                .fixedSize()
                .coreAccent(Self.probeRed)
                .padding(CoreSpacing.lg)
                .background(backdrop),
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private func toastActionInk(
        _ presentation: ToastPresentation,
        label: String,
        dynamicTypeSize: DynamicTypeSize
    ) -> (width: Int, pixels: Int)? {
        let host = ToastHost()
        host.show(ToastItem(
            title: "A long toast title that will not fit on a single line here",
            description: "Supporting description text that wraps across two lines at most.",
            level: .neutral,
            action: ToastAction(label) {}
        ))
        return self.redInk(
            ToastOverlay(host: host, edge: .top, presentation: presentation)
                .frame(width: Self.containerWidth)
                .coreAccent(Self.probeRed),
            dynamicTypeSize: dynamicTypeSize
        )
    }

    @Test(
        "动作按钮在三种形态、常规与 AX5 字号下都不被截断（AX5 允许折行）",
        arguments: [DynamicTypeSize.large, .accessibility5]
    )
    func actionLabelIsNotTruncated(dynamicTypeSize: DynamicTypeSize) {
        let label = "Undo archive"
        let bare = self.standaloneActionInk(label, dynamicTypeSize: dynamicTypeSize)
        let onRaised = self.standaloneActionInk(label, dynamicTypeSize: dynamicTypeSize, backdrop: .surfaceRaised)
        guard let bare, let onRaised, bare.pixels > 0, onRaised.pixels > 0 else {
            Issue.record("参照按钮没画出探针色 —— 量测失效，不得当作通过")
            return
        }
        for presentation in ToastPresentation.allCases {
            guard let ink = self.toastActionInk(presentation, label: label, dynamicTypeSize: dynamicTypeSize) else {
                Issue.record("\(presentation) @ \(dynamicTypeSize)：toast 里找不到动作文字")
                continue
            }
            // HUD 外壳底色不透明；`ImageRenderer` 画不画玻璃里的底色随运行环境而变，字形抗锯齿边的墨量随之两取一。
            let reference = presentation == .centeredHUD && abs(ink.pixels - onRaised.pixels) < abs(ink.pixels - bare.pixels)
                ? onRaised : bare
            let ratio = Double(ink.pixels) / Double(reference.pixels)
            #expect(abs(ratio - 1) <= 0.05,
                    "\(presentation) @ \(dynamicTypeSize)：动作文字墨量 \(ink.pixels) / 完整 \(reference.pixels) —— 字形缺失，被截断")
            if !dynamicTypeSize.isAccessibilitySize {
                #expect(abs(ink.width - reference.width) <= 1,
                        "\(presentation) @ \(dynamicTypeSize)：动作文字宽 \(ink.width) ≠ 完整宽 \(reference.width) —— 常规字号下动作应单行完整显示")
            }
        }
    }

    @Test("截断判据的非退化前置：被挤压的动作文字确实量得出更窄")
    func truncationProbeDetectsSqueeze() {
        let full = self.standaloneActionInk("Undo everything", dynamicTypeSize: .large)
        let squeezed = self.redInk(
            Button {} label: { Text("Undo everything").lineLimit(1) }
                .buttonStyle(.light(role: .primary))
                .controlSize(.small)
                .frame(width: 60)
                .coreAccent(Self.probeRed)
                .padding(CoreSpacing.lg),
            dynamicTypeSize: .large
        )
        guard let full, let squeezed else {
            Issue.record("量测失效")
            return
        }
        #expect(Double(squeezed.pixels) < Double(full.pixels) * 0.95,
                "挤压后墨量 \(squeezed.pixels) 未明显少于完整墨量 \(full.pixels) —— 墨量判据分辨不出截断")
    }
    // MARK: action hit area

    private func renderedSize(_ view: some View, dynamicTypeSize: DynamicTypeSize = .large) -> CGSize? {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(dynamicTypeSize))
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size
        #else
        return renderer.nsImage?.size
        #endif
    }

    @Test("动作按钮命中区 ≥ 44×44，且不改变按钮在布局中的占位", arguments: ["Undo", "OK"])
    func actionHitAreaIsAtLeast44WithoutGrowingLayout(label: String) {
        let hit = self.renderedSize(
            Button {} label: { Text(label).fontWeight(.semibold) }
                .buttonStyle(ToastActionButtonStyle())
                .controlSize(.small)
        )
        let footprint = self.renderedSize(
            Button {} label: { Text(label).fontWeight(.semibold) }
                .buttonStyle(ToastActionButtonStyle())
                .controlSize(.small)
                .padding(-ToastActionButtonStyle.hitOutset)
        )
        let light = self.renderedSize(
            Button {} label: { Text(label).fontWeight(.semibold) }
                .buttonStyle(.light(role: .primary))
                .controlSize(.small)
        )
        guard let hit, let footprint, let light else {
            Issue.record("渲染失败 —— 不得当作通过")
            return
        }
        #expect(hit.width >= ToastActionButtonStyle.minimumHitSide && hit.height >= ToastActionButtonStyle.minimumHitSide,
                "命中区 \(hit) 小于 44×44")
        #expect(footprint == light, "布局占位 \(footprint) ≠ 紧凑外观 \(light) —— 命中区扩展撑大了 toast")
    }

    // MARK: accessibility-size line limits

    @Test("行数：常规字号标题 1 行、说明 2 行；AX1+ 均不限")
    func lineLimitsFollowDynamicType() {
        #expect(ToastView.lineLimits(for: .large) == (1, 2))
        #expect(ToastView.lineLimits(for: .xxxLarge) == (1, 2))
        #expect(ToastView.lineLimits(for: .accessibility1) == (nil, nil))
        #expect(ToastView.lineLimits(for: .accessibility5) == (nil, nil))
    }

    private func toastHeight(description: String, dynamicTypeSize: DynamicTypeSize) -> CGFloat? {
        let host = ToastHost()
        host.show(ToastItem(title: "Archived", description: description, level: .neutral))
        return self.renderedSize(
            ToastOverlay(host: host, edge: .top, presentation: .floatingCapsule)
                .frame(width: Self.containerWidth),
            dynamicTypeSize: dynamicTypeSize
        )?.height
    }

    @Test("说明在常规字号封顶 2 行，在 AX1+ 随内容增高")
    func descriptionGrowsOnlyAtAccessibilitySizes() {
        let short = String(repeating: "A longer description that keeps going. ", count: 3)
        let long = String(repeating: "A much longer description that keeps going. ", count: 6)
        let regularShort = self.toastHeight(description: short, dynamicTypeSize: .large)
        let regularLong = self.toastHeight(description: long, dynamicTypeSize: .large)
        let axShort = self.toastHeight(description: short, dynamicTypeSize: .accessibility1)
        let axLong = self.toastHeight(description: long, dynamicTypeSize: .accessibility1)
        guard let regularShort, let regularLong, let axShort, let axLong else {
            Issue.record("渲染失败 —— 不得当作通过")
            return
        }
        #expect(regularLong == regularShort, "常规字号下两段都超过 2 行，应同样封顶：短 \(regularShort) / 长 \(regularLong)")
        #expect(axLong > axShort, "AX1 下说明应完整显示：短 \(axShort) / 长 \(axLong)")
    }
}
