import SwiftUI

// MARK: - FloatingGlassChrome

nonisolated struct FloatingGlassChrome: Equatable, Sendable {
    enum Border: Equatable, Sendable {
        case hairline
        case none
    }

    enum Backing: Equatable, Sendable {
        case translucent
        case opaque
    }

    let border: Border
    let backing: Backing
    let bleed: Edge.Set
    let overscan: Edge.Set

    init(border: Border, backing: Backing, bleed: Edge.Set, overscan: Edge.Set = []) {
        self.border = border
        self.backing = backing
        self.bleed = bleed
        self.overscan = overscan
    }

    static let floating = FloatingGlassChrome(border: .hairline, backing: .translucent, bleed: [])

    static let hud = FloatingGlassChrome(border: .hairline, backing: .opaque, bleed: [])

    static func edgeBanner(_ edge: VerticalEdge) -> FloatingGlassChrome {
        let anchored: Edge.Set = edge == .top ? .top : .bottom
        return FloatingGlassChrome(
            border: .none, backing: .translucent, bleed: anchored, overscan: anchored.union(.horizontal)
        )
    }

    @MainActor
    @ViewBuilder
    func backingView(in shape: some InsettableShape) -> some View {
        switch self.backing {
        case .translucent:
            shape
                .inset(by: CoreButtonMetrics.glassInset)
                .fill(.background.opacity(0.64))
        case .opaque:
            shape
                .inset(by: CoreButtonMetrics.glassInset)
                .fill(Color.surfaceRaised)
        }
    }
}

// MARK: - FloatingGlassModifier

public struct FloatingGlassModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isInteractive: Bool
    let chrome: FloatingGlassChrome

    public init(shape: S, isInteractive: Bool = false) {
        self.init(shape: shape, isInteractive: isInteractive, chrome: .floating)
    }

    init(shape: S, isInteractive: Bool, chrome: FloatingGlassChrome) {
        self.shape = shape
        self.isInteractive = isInteractive
        self.chrome = chrome
    }

    public func body(content: Content) -> some View {
        let glass = self.isInteractive ? Glass.regular.interactive() : Glass.regular

        content
            .background(
                self.chrome.backingView(in: self.shape)
                    .glassEffect(glass, in: self.shape)
                    .padding(self.chrome.overscan, -CoreSpacing.xs)
                    .ignoresSafeArea(edges: self.chrome.bleed)
            )
            .overlay {
                if self.chrome.border == .hairline {
                    self.shape.strokeBorder(
                        Color.borderSubtle,
                        lineWidth: CoreBorderWidth.hairline
                    )
                }
            }
    }
}

public extension View {
    func floatingGlass(
        in shape: some InsettableShape = Capsule(style: .continuous),
        isInteractive: Bool = false
    ) -> some View {
        self.modifier(FloatingGlassModifier(shape: shape, isInteractive: isInteractive))
    }
}

extension View {
    func floatingGlass(
        in shape: some InsettableShape,
        chrome: FloatingGlassChrome
    ) -> some View {
        self.modifier(FloatingGlassModifier(shape: shape, isInteractive: false, chrome: chrome))
    }
}

#Preview {
    VStack(spacing: CoreSpacing.xl) {
        Text("floatingGlass · Capsule (default)")
            .padding()
            .floatingGlass()

        Text("floatingGlass · RoundedRect (interactive)")
            .padding()
            .floatingGlass(in: CoreShape.rounded(CoreRadius.large), isInteractive: true)
    }
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
}
