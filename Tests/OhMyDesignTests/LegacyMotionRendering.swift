import SwiftUI
@testable import OhMyDesign

// MARK: - #407 之前的按压实现（原样拷贝，供逐像素对照）

struct LegacyButtonBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double?

    func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .fill(self.fill)
            )
            .overlay(
                self.shape
                    .strokeBorder(self.border, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .opacity(self.isPressed ? (self.pressedOpacity ?? 1) : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

struct LegacyTelegramGlassButtonModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let isPressed: Bool
    let border: Color?
    let pressFeedback: Bool

    func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background)
                    .glassEffect()
            )
            .overlay(
                self.shape.strokeBorder(
                    self.border ?? Color.white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.pressFeedback && self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(self.pressFeedback ? Animation.snappy(duration: 0.16) : nil, value: self.isPressed)
    }
}
