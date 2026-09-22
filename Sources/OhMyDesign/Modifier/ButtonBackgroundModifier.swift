import SwiftUI

// MARK: - ButtonBackgroundModifier

private struct ButtonBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double?

    @Environment(\.coreMotionPresentation) private var motionPresentation

    func body(content: Content) -> some View {
        let feedback = PressFeedback.chrome(
            isPressed: self.isPressed,
            pressedOpacity: self.pressedOpacity,
            presentation: self.motionPresentation
        )
        content
            .background(
                self.shape
                    .fill(self.fill)
            )
            .overlay(
                self.shape
                    .strokeBorder(self.border, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(feedback.scale)
            .opacity(feedback.opacity)
            .animation(CoreMotionToken.press.animation(for: self.motionPresentation), value: self.isPressed)
    }
}

// MARK: - View extension

extension View {
    func buttonBackground(
        shape: some InsettableShape,
        fill: Color,
        border: Color,
        isPressed: Bool,
        pressedOpacity: Double? = nil
    ) -> some View {
        self.modifier(ButtonBackgroundModifier(
            shape: shape,
            fill: fill,
            border: border,
            isPressed: isPressed,
            pressedOpacity: pressedOpacity
        ))
    }
}
