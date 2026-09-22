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
        let pressed = PressFeedback.card(isPressed: true, isEnabled: true, reduceMotion: false)
        #expect(pressed.scale == CoreButtonMetrics.pressedScale)
        #expect(pressed.opacity == 1)
        #expect(pressed.fill == nil)

        let idle = PressFeedback.card(isPressed: false, isEnabled: true, reduceMotion: false)
        #expect(idle == PressFeedback.idle)
    }

    @Test("卡片：reduce motion 下只变暗不缩放")
    func cardFeedbackReduceMotion() {
        let pressed = PressFeedback.card(isPressed: true, isEnabled: true, reduceMotion: true)
        #expect(pressed.scale == 1)
        #expect(pressed.opacity < 1)

        let idle = PressFeedback.card(isPressed: false, isEnabled: true, reduceMotion: true)
        #expect(idle == PressFeedback.idle)
    }

    @Test("禁用：两者都不给按压反馈，并整体变淡")
    func disabledFeedback() {
        let row = PressFeedback.row(isPressed: true, isEnabled: false)
        let card = PressFeedback.card(isPressed: true, isEnabled: false, reduceMotion: false)
        let cardReduced = PressFeedback.card(isPressed: true, isEnabled: false, reduceMotion: true)
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
}
