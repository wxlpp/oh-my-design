import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - `.pressableRow` / `.pressableCard`（Issue #381 / FR-11）

@MainActor
private func renderedImage(_ content: some View) -> CGImage? {
    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    return renderer.cgImage
}

@MainActor
private func rgba(_ content: some View) -> [UInt8]? {
    guard let cgImage = renderedImage(content) else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

private func differingPixelFraction(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var differing = 0
    for index in stride(from: 0, to: a.count, by: 4)
    where a[index] != b[index] || a[index + 1] != b[index + 1] || a[index + 2] != b[index + 2] || a[index + 3] != b[index + 3] {
        differing += 1
    }
    return Double(differing) / Double(a.count / 4)
}

private struct AlphaStats {
    let covered: Int
    let meanAlpha: Double
}

private func alphaStats(_ pixels: [UInt8]) -> AlphaStats {
    var covered = 0
    var total = 0.0
    for index in stride(from: 3, to: pixels.count, by: 4) where pixels[index] > 0 {
        covered += 1
        total += Double(pixels[index])
    }
    return AlphaStats(covered: covered, meanAlpha: covered > 0 ? total / Double(covered) : 0)
}

@MainActor
private func tintedPixelCount(_ content: some View) -> Int? {
    guard let cgImage = renderedImage(content.background(Color.white)) else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0] < 255 }.count
}

@Suite("Pressable ButtonStyle")
@MainActor
struct PressableButtonStyleTests {
    @Test("静态入口产出对应样式")
    func staticMembers() {
        let row: PressableRowButtonStyle = .pressableRow
        let card: PressableCardButtonStyle = .pressableCard
        _ = (row, card)
    }

    // MARK: - 反馈真值表

    @Test("行：按下且可用时铺 pressedBackground，其余不铺")
    func rowFeedback() {
        #expect(PressFeedback.row(isPressed: true, isEnabled: true).fill == Color.pressedBackground)
        #expect(PressFeedback.row(isPressed: false, isEnabled: true).fill == nil)
        #expect(PressFeedback.row(isPressed: true, isEnabled: false).fill == nil)
        #expect(PressFeedback.row(isPressed: true, isEnabled: true).scale == 1, "行不缩放")
    }

    @Test("卡片：按下按 pressedScale 缩放，不变暗")
    func cardFeedbackScales() {
        let pressed = PressFeedback.card(isPressed: true, isEnabled: true, presentation: .animated)
        #expect(pressed.scale == CoreButtonMetrics.pressedScale)
        #expect(pressed.opacity == 1)
        #expect(pressed.fill == nil)

        let idle = PressFeedback.card(isPressed: false, isEnabled: true, presentation: .animated)
        #expect(idle == PressFeedback.idle)
    }

    @Test("卡片：reduce motion 下只变暗不缩放")
    func cardFeedbackReduceMotion() {
        let pressed = PressFeedback.card(isPressed: true, isEnabled: true, presentation: .resting)
        #expect(pressed.scale == 1)
        #expect(pressed.opacity < 1)

        let idle = PressFeedback.card(isPressed: false, isEnabled: true, presentation: .resting)
        #expect(idle == PressFeedback.idle)
    }

    @Test("禁用：两者都不给按压反馈，并整体变淡")
    func disabledFeedback() {
        let row = PressFeedback.row(isPressed: true, isEnabled: false)
        let card = PressFeedback.card(isPressed: true, isEnabled: false, presentation: .animated)
        let cardReduced = PressFeedback.card(isPressed: true, isEnabled: false, presentation: .resting)
        for feedback in [row, card, cardReduced] {
            #expect(feedback.fill == nil)
            #expect(feedback.scale == 1)
            #expect(feedback.opacity == PressFeedback.disabledOpacity)
        }
        #expect(PressFeedback.disabledOpacity < 1)
    }

    // MARK: - 渲染：只装饰、不改布局

    @Test("行样式不改变 label 的尺寸（按下与未按下）")
    func rowKeepsLabelSize() throws {
        let label = Text("Wi-Fi").padding(CoreSpacing.md)
        let bare = try #require(renderedImage(label))
        for isPressed in [false, true] {
            let styled = try #require(renderedImage(PressableRowBody(label: label, isPressed: isPressed)))
            #expect(styled.width == bare.width && styled.height == bare.height,
                    "isPressed=\(isPressed)：\(styled.width)x\(styled.height) vs 原 label \(bare.width)x\(bare.height)")
        }
    }

    @Test("卡片样式不改变 label 的尺寸（按下与未按下）")
    func cardKeepsLabelSize() throws {
        let label = Text("Card").padding(CoreSpacing.lg)
        let bare = try #require(renderedImage(label))
        for isPressed in [false, true] {
            let styled = try #require(renderedImage(PressableCardBody(label: label, isPressed: isPressed)))
            #expect(styled.width == bare.width && styled.height == bare.height,
                    "isPressed=\(isPressed)：\(styled.width)x\(styled.height) vs 原 label \(bare.width)x\(bare.height)")
        }
    }

    @Test("行样式按下时真的画出底色，禁用时不画")
    func rowRendersPressedFill() throws {
        let label = Color.clear.frame(width: 40, height: 20)
        let idle = try #require(tintedPixelCount(PressableRowBody(label: label, isPressed: false)))
        let pressed = try #require(tintedPixelCount(PressableRowBody(label: label, isPressed: true)))
        let disabled = try #require(tintedPixelCount(
            PressableRowBody(label: label, isPressed: true).environment(\.isEnabled, false)
        ))
        #expect(idle == 0)
        #expect(pressed == 40 * 20, "按下应铺满整行，实测 \(pressed) 个被着色像素")
        #expect(disabled == 0)
    }

    // MARK: - 渲染：真实行组件

    private func wifiListRow() -> some View {
        ListRow {
            Image(systemName: "wifi")
        } label: {
            Text("Wi-Fi")
        } trailing: {
            Text("On")
        }
        .frame(width: 240)
    }

    private func wifiSettingsRow() -> some View {
        SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
            Text("HomeNetwork")
        }
        .frame(width: 240)
        .background(Color.surfaceRaised)
    }

    private func assertRowHighlight(_ label: some View, name: String) throws {
        let idle = try #require(rgba(PressableRowBody(label: label, isPressed: false).environment(\.colorScheme, .light)))
        let pressed = try #require(rgba(PressableRowBody(label: label, isPressed: true).environment(\.colorScheme, .light)))
        let fraction = differingPixelFraction(idle, pressed)
        #expect(fraction > 0.9, "\(name)：按下态应覆盖整行（含自带背景），实测只有 \(fraction) 的像素变化")

        let disabledIdle = try #require(rgba(
            PressableRowBody(label: label, isPressed: false).environment(\.colorScheme, .light).environment(\.isEnabled, false)
        ))
        let disabledPressed = try #require(rgba(
            PressableRowBody(label: label, isPressed: true).environment(\.colorScheme, .light).environment(\.isEnabled, false)
        ))
        expectBitmapsEqual(disabledIdle, disabledPressed, "\(name)：禁用时按下不应有任何变化")
        expectBitmapsDiffer(idle, disabledIdle, "\(name)：禁用态应整体变淡")
    }

    @Test("行样式：自带背景的 ListRow 按下时高亮可见，禁用时无变化")
    func rowHighlightOverListRow() throws {
        try self.assertRowHighlight(self.wifiListRow(), name: "ListRow")
    }

    @Test("行样式：分组背景上的 SettingsRow 按下时高亮可见，禁用时无变化")
    func rowHighlightOverSettingsRow() throws {
        try self.assertRowHighlight(self.wifiSettingsRow(), name: "SettingsRow")
    }

    // MARK: - 渲染：卡片真实效果

    private func cardHost(_ content: some View) -> some View {
        content.frame(width: 60, height: 60)
    }

    private var cardLabel: some View { Color.black.frame(width: 40, height: 40) }

    @Test("卡片按下：label 真的被缩小")
    func cardPressedRendersScaled() throws {
        let idle = alphaStats(try #require(rgba(self.cardHost(PressableCardBody(label: self.cardLabel, isPressed: false)))))
        let pressed = alphaStats(try #require(rgba(self.cardHost(PressableCardBody(label: self.cardLabel, isPressed: true)))))
        #expect(idle.covered == 1600, "未按下应覆盖 40×40，实测 \(idle.covered)")
        #expect(pressed.covered < 1500, "按下应按 0.94 缩小（约 1414 像素），实测 \(pressed.covered)")
    }

    @Test("卡片按下 + 减弱动态效果：不缩放，只变暗")
    func cardPressedReduceMotionRendersDimmed() throws {
        let pressed = alphaStats(try #require(rgba(self.cardHost(PressableCardBody(label: self.cardLabel, isPressed: true).environment(\.coreMotionPresentationOverride, .resting)))))
        #expect(pressed.covered == 1600, "减弱动态效果下不应缩放，实测覆盖 \(pressed.covered)")
        #expect(abs(pressed.meanAlpha - 255 * PressFeedback.reducedMotionPressedOpacity) < 3, "应按 0.7 变暗，实测平均 α=\(pressed.meanAlpha)")
    }

    @Test("卡片禁用：按下也不缩放，整体变淡")
    func cardDisabledRendersFaded() throws {
        let body = PressableCardBody(label: self.cardLabel, isPressed: true)
            .environment(\.isEnabled, false)
        let stats = alphaStats(try #require(rgba(self.cardHost(body))))
        #expect(stats.covered == 1600, "禁用时不应缩放，实测覆盖 \(stats.covered)")
        #expect(abs(stats.meanAlpha - 255 * PressFeedback.disabledOpacity) < 3, "禁用应为 0.4 透明度，实测平均 α=\(stats.meanAlpha)")
    }

    @Test("真实 Button + .pressableCard 走到卡片 body（禁用态与 body 直出逐像素一致）")
    func realButtonReachesCardBody() throws {
        let button = Button {} label: { self.cardLabel }
            .buttonStyle(.pressableCard)
            .environment(\.isEnabled, false)
        let direct = PressableCardBody(label: self.cardLabel, isPressed: false)
            .environment(\.isEnabled, false)
        let buttonPixels = try #require(rgba(self.cardHost(button)))
        let directPixels = try #require(rgba(self.cardHost(direct)))
        expectBitmapsEqual(buttonPixels, directPixels, "Button 渲染应与 PressableCardBody 一致")
        let stats = alphaStats(buttonPixels)
        #expect(abs(stats.meanAlpha - 255 * PressFeedback.disabledOpacity) < 3, "Button 禁用态应带 0.4 透明度，实测 α=\(stats.meanAlpha)")
    }
}
