import SwiftUI
@testable import OhMyDesign

// MARK: - 改动前实现的原样拷贝（Issue #399 像素对照基线）

struct LegacyFloatingGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let isInteractive: Bool

    init(shape: S, isInteractive: Bool = false) {
        self.shape = shape
        self.isInteractive = isInteractive
    }

    func body(content: Content) -> some View {
        let glass = self.isInteractive ? Glass.regular.interactive() : Glass.regular

        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background.opacity(0.64))
                    .glassEffect(glass, in: self.shape)
            )
            .overlay(
                self.shape.strokeBorder(
                    Color.borderSubtle,
                    lineWidth: CoreBorderWidth.hairline
                )
            )
    }
}

extension View {
    func legacyFloatingGlass(
        in shape: some InsettableShape = Capsule(style: .continuous),
        isInteractive: Bool = false
    ) -> some View {
        self.modifier(LegacyFloatingGlassModifier(shape: shape, isInteractive: isInteractive))
    }
}

struct LegacyToastContainerDecoration: ViewModifier {
    let presentation: ToastPresentation
    let isSingleRow: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch self.presentation {
        case .floatingCapsule:
            if self.isSingleRow {
                content.legacyFloatingGlass(in: Capsule(style: .continuous), isInteractive: false)
            } else {
                content.legacyFloatingGlass(
                    in: RoundedRectangle(cornerRadius: CoreRadius.xLarge, style: .continuous),
                    isInteractive: false
                )
            }
        case .fullWidthBanner:
            content.legacyFloatingGlass(in: Rectangle(), isInteractive: false)
        case .centeredHUD:
            content.legacyFloatingGlass(
                in: RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous),
                isInteractive: false
            )
        }
    }
}

struct LegacyToastView: View {
    let item: ToastItem
    let edge: VerticalEdge
    let presentation: ToastPresentation
    let isDismissing: Bool
    let onDismiss: () -> Void
    var onAction: () -> Void = {}
    var onPause: (ToastPauseReason, Bool) -> Void = { _, _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var dragOffset: CGFloat = .zero
    @GestureState private var isPressing = false
    @GestureState private var isDragging = false

    var body: some View {
        self.content
            .padding(CoreSpacing.md)
            .modifier(LegacyToastContainerDecoration(presentation: self.presentation, isSingleRow: self.isSingleRow))
            .offset(y: self.verticalOffset)
            .scaleEffect(self.presentation == .centeredHUD && self.isDismissing ? 0.92 : 1)
            .opacity(self.isDismissing ? 0 : 1)
            .contentShape(Rectangle())
            .onTapGesture { self.onDismiss() }
            .simultaneousGesture(self.interactionGesture)
            .onChange(of: self.isPressing) { _, pressing in
                self.onPause(.press, pressing)
            }
            .onChange(of: self.isDragging) { _, dragging in
                self.onPause(.drag, dragging)
                if !dragging { self.dragOffset = .zero }
            }
            .allowsHitTesting(!self.isDismissing)
    }

    private var isAccessibilityLayout: Bool {
        self.dynamicTypeSize.isAccessibilitySize
    }

    private var isSingleRow: Bool {
        self.item.description == nil && !self.isAccessibilityLayout
    }

    @ViewBuilder
    private var content: some View {
        if let action = self.item.action {
            let layout = self.isAccessibilityLayout
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: CoreSpacing.sm))
                : AnyLayout(HStackLayout(spacing: CoreSpacing.sm))
            layout {
                self.message
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(Text("Tap to dismiss", bundle: .module))
                    .accessibilityAction { self.onDismiss() }
                self.actionButton(action)
            }
            .accessibilityElement(children: .contain)
        } else {
            self.message
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("Tap to dismiss", bundle: .module))
        }
    }

    private var message: some View {
        HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.sm) {
            self.icon
                .foregroundStyle(self.iconColor)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(self.item.title)
                    .coreFont(.callout)
                    .fontWeight(self.item.description == nil ? .regular : .semibold)
                    .foregroundStyle(Color.contentPrimary)
                    .lineLimit(Self.lineLimits(for: self.dynamicTypeSize).title)
                    .fixedSize(horizontal: false, vertical: self.isAccessibilityLayout)
                if let description = self.item.description {
                    Text(description)
                        .coreFont(.footnote)
                        .foregroundStyle(Color.contentSecondary)
                        .lineLimit(Self.lineLimits(for: self.dynamicTypeSize).description)
                        .fixedSize(horizontal: false, vertical: self.isAccessibilityLayout)
                }
            }
            .multilineTextAlignment(.leading)
            if self.presentation != .centeredHUD {
                Spacer(minLength: CoreSpacing.none)
            }
        }
    }

    private func actionButton(_ action: ToastAction) -> some View {
        Button {
            self.onAction()
        } label: {
            Text(action.label)
                .fontWeight(.semibold)
                .lineLimit(self.isAccessibilityLayout ? nil : 1)
                .fixedSize(horizontal: !self.isAccessibilityLayout, vertical: true)
        }
        .buttonStyle(ToastActionButtonStyle())
        .controlSize(.small)
        .padding(-ToastActionButtonStyle.hitOutset)
        .layoutPriority(1)
    }

    static func lineLimits(for size: DynamicTypeSize) -> (title: Int?, description: Int?) {
        size.isAccessibilitySize ? (nil, nil) : (1, 2)
    }

    private var verticalOffset: CGFloat {
        if self.presentation == .centeredHUD {
            return .zero
        }
        return self.isDismissing ? self.dismissOffset : self.dragOffset
    }

    // MARK: visuals

    private var icon: Image {
        Self.icon(for: self.item.level)
    }

    private var iconColor: Color {
        Self.iconColor(for: self.item.level)
    }

    static func icon(for level: StatusLevel) -> Image {
        switch level {
        case .info: Image(systemName: "info.circle")
        case .success: Image(systemName: "checkmark.circle")
        case .warning: Image(systemName: "exclamationmark.triangle")
        case .danger: Image(systemName: "exclamationmark.octagon")
        case .neutral: Image(systemName: "bell")
        }
    }

    static func iconColor(for level: StatusLevel) -> Color {
        switch level {
        case .info: .statusAccentForeground
        case .success: .statusSuccessForeground
        case .warning: .statusAttentionForeground
        case .danger: .statusDangerForeground
        case .neutral: .contentSecondary
        }
    }

    // MARK: gestures

    private var interactionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$isPressing) { _, pressing, _ in
                pressing = true
            }
            .updating(self.$isDragging) { value, dragging, _ in
                if abs(value.translation.height) > 0 || abs(value.translation.width) > 0 {
                    dragging = true
                }
            }
            .onChanged { value in
                guard self.presentation != .centeredHUD else { return }
                let dy = value.translation.height
                self.dragOffset = self.allowsDrag(dy) ? dy : dy * ToastDefaults.reverseDragDamping
            }
            .onEnded { value in
                guard self.presentation != .centeredHUD else { return }
                let dy = value.translation.height
                let pastThreshold = abs(dy) >= ToastDefaults.swipeDismissThreshold
                if pastThreshold, self.allowsDrag(dy) {
                    self.onDismiss()
                }
                self.dragOffset = .zero
            }
    }

    private func allowsDrag(_ dy: CGFloat) -> Bool {
        switch self.edge {
        case .top: dy <= 0
        case .bottom: dy >= 0
        }
    }

    private var dismissOffset: CGFloat {
        switch self.edge {
        case .top: -ToastDefaults.dismissSlideDistance
        case .bottom: ToastDefaults.dismissSlideDistance
        }
    }
}

extension SurfaceKind {
    var legacyBorder: Color {
        switch self {
        case .canvas: .clear
        case .content: .borderMuted
        case .control: .borderSubtle
        case .floating: .borderMuted
        case .grouped: .clear
        case .canvasSubtle: .borderMuted
        case .panel: .borderDefault
        case .sidebar: .clear
        case .card: .borderMuted
        }
    }
}

struct LegacySurfaceModifier: ViewModifier {
    let kind: SurfaceKind
    @Environment(\.surfaceLevel) private var parentLevel

    func body(content: Content) -> some View {
        let shape = CoreShape.rounded(self.kind.cornerRadius)
        let level = self.kind.level(inheriting: self.parentLevel)
        return content
            .environment(\.surfaceLevel, level)
            .background(shape.fill(self.kind.background(at: level)))
            .overlay(shape.strokeBorder(self.kind.legacyBorder, lineWidth: CoreBorderWidth.thin))
            .clipShape(shape)
    }
}
