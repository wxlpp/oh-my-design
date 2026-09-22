import SwiftUI

// MARK: - ToastItem

/// 单条 Toast 的数据载体。`ToastHost` 内部以 `[ToastItem]` 维护队列。
///
/// 类型为 `nonisolated` + `Sendable`：可在任意 actor 上构造，再回到主 actor 调用
/// `await MainActor.run { host.show(item) }` 展示。
public nonisolated struct ToastItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let level: StatusLevel
    public let duration: ToastDuration
    public let action: ToastAction?

    /// 创建一条 ToastItem。
    ///
    /// - Parameters:
    ///   - id: stable identity；缺省时由 `UUID()` 生成。
    ///   - title: 标题，单行显示。
    ///   - description: 可选说明，最多两行。
    ///   - level: 语义等级，决定 icon 与图标色，缺省 `.info`。
    ///   - duration: 显示时长，缺省 `ToastDefaults.duration`；计时从开始显示起算。
    ///   - action: 可选动作；点动作 = 执行后关闭。
    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        level: StatusLevel = .info,
        duration: ToastDuration = ToastDefaults.duration,
        action: ToastAction? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.level = level
        self.duration = duration
        self.action = action
    }
}

// MARK: - ToastAction

/// Toast 上的单个动作按钮。处理闭包在主 actor 上执行，执行后 toast 关闭。
public nonisolated struct ToastAction: Sendable {
    public let label: String
    private let handler: @MainActor @Sendable () -> Void

    /// 创建一个 Toast 动作。
    ///
    /// - Parameters:
    ///   - label: 按钮文案。
    ///   - action: 点按时在主 actor 上执行的处理闭包。
    public init(_ label: String, action: @escaping @MainActor @Sendable () -> Void) {
        self.label = label
        self.handler = action
    }

    /// 在主 actor 上执行动作（不关闭 toast；关闭由 `ToastHost` 负责）。
    @MainActor
    public func perform() {
        self.handler()
    }
}

// MARK: - ToastDuration

/// Toast 的显示时长。
public nonisolated enum ToastDuration: Sendable, Equatable {
    /// 显示指定秒数后自动关闭；非正值（含 NaN）按 `ToastDefaults` 的缺省时长处理，
    /// `.infinity` 等同 `.persistent`。
    case seconds(TimeInterval)
    /// 不自动关闭，直到被 `dismiss` / `dismissAll` / 点按关闭；关闭前阻塞其后的排队项。
    case persistent

    var resolvedSeconds: TimeInterval? {
        switch self {
        case .persistent:
            return nil
        case let .seconds(value):
            if value.isNaN || value <= 0 { return ToastDefaults.defaultSeconds }
            if value.isInfinite { return nil }
            return value
        }
    }
}

// MARK: - ToastPresentation

/// `Toast` 的**呈现形态**（公约 §2 形态 D2「配置枚举」，`wxlpp/oh-my-story#65`）。
public enum ToastPresentation: Sendable, Equatable, CaseIterable {
    /// 现状形态：`safeAreaInset` 贴边 + `Capsule` 几何 + 水平内边距，读起来像系统反馈。
    case floatingCapsule
    /// 全宽横幅条（Android Snackbar / in-app banner）：贴边、横跨屏幕宽度、非胶囊。
    case fullWidthBanner
    /// 居中 HUD（经典 UIKit toast/HUD）：浮于屏幕中央而非贴边，宽度收缩为内容宽。
    /// ⚠️ 本形态下 `edge` 不生效。
    case centeredHUD
}

// MARK: - ToastDefaults

/// Toast 行为的默认值常量集合。集中此处避免 magic numbers 散落。
public nonisolated enum ToastDefaults {
    /// `ToastItem.init` / `ToastHost.show(_:description:level:duration:)` 的缺省时长：3 秒，
    /// 贴合 Apple HIG / Material Design 对短提示的常见取值。
    public static let duration: ToastDuration = .seconds(ToastDefaults.defaultSeconds)

    static let defaultSeconds: TimeInterval = 3

    static let dismissAnimationDuration: TimeInterval = 0.25

    static let swipeDismissThreshold: CGFloat = CoreSpacing.xxl

    static let reverseDragDamping: CGFloat = 0.5

    static let dismissSlideDistance: CGFloat = 60
}

// MARK: - ToastPauseReason

enum ToastPauseReason: Hashable {
    case press
    case drag
}

// MARK: - ToastHost

/// Scene 级的浮层 toast 队列与调度器，外壳形状由 `ToastPresentation` 三选一。
///
/// 一次只显示 `queue.first`；按住或拖拽时暂停计时，松手按剩余时长恢复。
/// `.persistent` 的 toast 在被关闭前阻塞其后的排队项。
@MainActor
@Observable
public final class ToastHost {
    /// 当前队列；`queue.first` 是正在显示的那条，视图层只渲染它。
    public private(set) var queue: [ToastItem] = []

    /// 当前 toast 是否正处于 dismiss 动画中。`true` 时新 `show(...)` append 到队尾，
    /// 不打断当前正在退场的 toast；动画完成后取下一条。
    public private(set) var isDismissing: Bool = false

    private let clock: any ToastClock
    @ObservationIgnored private var displayTimer: (any ToastTimer)?
    @ObservationIgnored private var exitTimer: (any ToastTimer)?
    @ObservationIgnored private var remaining: TimeInterval?
    @ObservationIgnored private var displayStartedAt: TimeInterval = 0
    @ObservationIgnored private var pauseReasons: Set<ToastPauseReason> = []
    @ObservationIgnored private var generation: UInt64 = 0

    /// 创建一个新的 ToastHost。每个 scene 应持有独立实例；不要共享。
    public init() {
        self.clock = SystemToastClock()
    }

    init(clock: any ToastClock) {
        self.clock = clock
    }

    // MARK: Public API

    /// 入队一条 toast（便利重载），等同 `show(ToastItem(title:description:level:duration:))`。
    ///
    /// - Parameters:
    ///   - title: 标题，单行显示。
    ///   - description: 可选说明，最多两行。
    ///   - level: 语义等级，缺省 `.info`。
    ///   - duration: 显示时长，缺省 `ToastDefaults.duration`；计时从开始显示起算。
    public func show(
        _ title: String,
        description: String? = nil,
        level: StatusLevel = .info,
        duration: ToastDuration = ToastDefaults.duration
    ) {
        self.show(ToastItem(title: title, description: description, level: level, duration: duration))
    }

    /// 入队一条预构造的 ToastItem。
    public func show(_ item: ToastItem) {
        let wasIdle = self.queue.isEmpty && !self.isDismissing
        self.queue.append(item)
        if wasIdle {
            self.startDisplay(item)
        }
    }

    /// dismiss 指定 id 的 toast：正在显示的进入退场动画，排队中的直接移除。
    public func dismiss(_ id: ToastItem.ID) {
        guard let index = self.queue.firstIndex(where: { $0.id == id }) else { return }
        if index == 0 {
            self.beginDismissCurrent()
        } else {
            self.queue.remove(at: index)
        }
    }

    /// 清空当前与排队中的全部 toast，退场动画进行中调用同样生效；之后可立即 `show`。
    public func dismissAll() {
        self.displayTimer?.cancel()
        self.displayTimer = nil
        self.exitTimer?.cancel()
        self.exitTimer = nil
        self.remaining = nil
        self.pauseReasons = []
        self.queue.removeAll()
        self.isDismissing = false
    }

    // MARK: Interaction

    func performAction(of id: ToastItem.ID) {
        guard let current = self.queue.first, current.id == id, !self.isDismissing,
              let action = current.action else { return }
        let generation = self.generation
        action.perform()
        guard self.generation == generation, self.queue.first?.id == id else { return }
        self.dismiss(id)
    }

    func pause(_ reason: ToastPauseReason) {
        guard !self.queue.isEmpty, !self.isDismissing else { return }
        let wasRunning = self.pauseReasons.isEmpty
        self.pauseReasons.insert(reason)
        guard wasRunning, let timer = self.displayTimer, let remaining = self.remaining else { return }
        timer.cancel()
        self.displayTimer = nil
        self.remaining = max(0, remaining - (self.clock.now - self.displayStartedAt))
    }

    func resume(_ reason: ToastPauseReason) {
        guard self.pauseReasons.remove(reason) != nil, self.pauseReasons.isEmpty,
              !self.isDismissing, let current = self.queue.first,
              self.displayTimer == nil, let remaining = self.remaining else { return }
        self.armDisplayTimer(for: current.id, after: remaining)
    }

    var hasDisplayTimer: Bool { self.displayTimer != nil }

    var hasExitTimer: Bool { self.exitTimer != nil }

    // MARK: State machine

    private func startDisplay(_ item: ToastItem) {
        self.generation &+= 1
        self.displayTimer?.cancel()
        self.displayTimer = nil
        self.pauseReasons = []
        self.remaining = item.duration.resolvedSeconds
        if let seconds = self.remaining {
            self.armDisplayTimer(for: item.id, after: seconds)
        }
    }

    private func armDisplayTimer(for id: ToastItem.ID, after seconds: TimeInterval) {
        self.displayStartedAt = self.clock.now
        self.displayTimer = self.clock.schedule(after: seconds) { [weak self] in
            guard let self else { return }
            self.displayTimer = nil
            guard self.queue.first?.id == id, !self.isDismissing else { return }
            self.beginDismissCurrent()
        }
    }

    private func beginDismissCurrent() {
        guard let current = self.queue.first, !self.isDismissing else { return }
        self.displayTimer?.cancel()
        self.displayTimer = nil
        self.pauseReasons = []
        self.remaining = nil
        self.isDismissing = true
        self.exitTimer = self.clock.schedule(after: ToastDefaults.dismissAnimationDuration) { [weak self] in
            guard let self else { return }
            self.exitTimer = nil
            if self.queue.first?.id == current.id {
                self.queue.removeFirst()
            }
            self.isDismissing = false
            if let next = self.queue.first {
                self.startDisplay(next)
            }
        }
    }
}

// MARK: - EnvironmentValues

extension EnvironmentValues {
    /// 当前 scene 的 `ToastHost`；未挂 `.toastHost(edge:)` modifier 时为 `nil`。
    @Entry public var toastHost: ToastHost? = nil
}

// MARK: - View.toastHost

public extension View {
    /// 在当前 view 子树挂载一个 scene-scoped `ToastHost`，并在 `edge` 方向以
    /// `safeAreaInset` 渲染当前队列的首条 toast。
    ///
    /// - Parameters:
    ///   - edge: toast 显示位置，缺省 `.top`。
    ///     ⚠️ **`presentation` 为 `.centeredHUD` 时本参数不生效**（居中浮层无「贴哪边」
    ///     可言）。这是有意的静默，不加运行期断言——详见 `ToastPresentation`。
    ///   - presentation: 呈现形态，缺省 `.floatingCapsule`（现状形态）
    ///     ⇒ **现有调用方零影响**。
    /// - Returns: 已挂载 host 的视图。
    func toastHost(
        edge: VerticalEdge = .top,
        presentation: ToastPresentation = .floatingCapsule
    ) -> some View {
        self.modifier(ToastHostModifier(edge: edge, presentation: presentation))
    }
}

// MARK: - ToastHostModifier

struct ToastHostModifier: ViewModifier {
    @State private var host: ToastHost
    let edge: VerticalEdge
    let presentation: ToastPresentation

    init(host: ToastHost? = nil, edge: VerticalEdge, presentation: ToastPresentation) {
        self._host = State(initialValue: host ?? ToastHost())
        self.edge = edge
        self.presentation = presentation
    }

    func body(content: Content) -> some View {
        let base = content.environment(\.toastHost, self.host)
        if self.presentation == .centeredHUD {
            base.overlay(alignment: .center) {
                ToastOverlay(host: self.host, edge: self.edge, presentation: self.presentation)
            }
        } else {
            base.safeAreaInset(edge: self.edge, spacing: CoreSpacing.none) {
                ToastOverlay(host: self.host, edge: self.edge, presentation: self.presentation)
            }
        }
    }
}

// MARK: - ToastOverlay

struct ToastOverlay: View {
    @Bindable var host: ToastHost
    let edge: VerticalEdge
    let presentation: ToastPresentation

    var body: some View {
        Group {
            if let current = self.host.queue.first {
                ToastView(
                    item: current,
                    edge: self.edge,
                    presentation: self.presentation,
                    isDismissing: self.host.isDismissing,
                    onDismiss: { self.host.dismiss(current.id) },
                    onAction: { self.host.performAction(of: current.id) },
                    onPause: { reason, paused in
                        if paused {
                            self.host.pause(reason)
                        } else {
                            self.host.resume(reason)
                        }
                    }
                )
                .transition(self.transition)
                .id(current.id)
                .padding(.horizontal, self.horizontalPadding)
                .padding(self.edge == .top ? .top : .bottom, self.edgePadding)
                .frame(maxWidth: self.presentation == .centeredHUD ? nil : .infinity)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.queue.first?.id)
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.isDismissing)
    }

    private var horizontalPadding: CGFloat {
        self.presentation == .fullWidthBanner ? CoreSpacing.none : CoreSpacing.lg
    }

    private var edgePadding: CGFloat {
        self.presentation == .floatingCapsule ? CoreSpacing.lg : CoreSpacing.none
    }

    private var transition: AnyTransition {
        if self.presentation == .centeredHUD {
            return .scale(scale: 0.92).combined(with: .opacity)
        }
        let move: Edge = self.edge == .top ? .top : .bottom
        return .asymmetric(
            insertion: .move(edge: move).combined(with: .opacity),
            removal: .move(edge: move).combined(with: .opacity)
        )
    }
}

// MARK: - ToastView

enum ToastContainerShape: Equatable {
    case capsule
    case roundedXLarge
    case rectangle
    case roundedLarge
}

struct ToastContainerDecoration: ViewModifier {
    let presentation: ToastPresentation
    let edge: VerticalEdge
    let isSingleRow: Bool

    static func shape(for presentation: ToastPresentation, isSingleRow: Bool) -> ToastContainerShape {
        switch presentation {
        case .floatingCapsule: isSingleRow ? .capsule : .roundedXLarge
        case .fullWidthBanner: .rectangle
        case .centeredHUD: .roundedLarge
        }
    }

    static func chrome(for presentation: ToastPresentation, edge: VerticalEdge) -> FloatingGlassChrome {
        switch presentation {
        case .floatingCapsule: .floating
        case .fullWidthBanner: .edgeBanner(edge)
        case .centeredHUD: .hud
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let chrome = Self.chrome(for: self.presentation, edge: self.edge)
        switch Self.shape(for: self.presentation, isSingleRow: self.isSingleRow) {
        case .capsule:
            content.floatingGlass(in: Capsule(style: .continuous), chrome: chrome)
        case .roundedXLarge:
            content.floatingGlass(
                in: RoundedRectangle(cornerRadius: CoreRadius.xLarge, style: .continuous),
                chrome: chrome
            )
        case .rectangle:
            content.floatingGlass(in: Rectangle(), chrome: chrome)
        case .roundedLarge:
            content.floatingGlass(
                in: RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous),
                chrome: chrome
            )
        }
    }
}

struct ToastView: View {
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
            .modifier(ToastContainerDecoration(
                presentation: self.presentation, edge: self.edge, isSingleRow: self.isSingleRow
            ))
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

    @ViewBuilder
    private var message: some View {
        if self.isAccessibilityLayout {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                self.icon
                    .foregroundStyle(self.iconColor)
                    .dynamicTypeSize(...Self.accessibilityIconCap)
                    .accessibilityHidden(true)
                self.texts
            }
            .frame(maxWidth: self.presentation == .centeredHUD ? nil : .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: CoreSpacing.sm) {
                self.icon
                    .foregroundStyle(self.iconColor)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
                self.texts
                if self.presentation != .centeredHUD {
                    Spacer(minLength: CoreSpacing.none)
                }
            }
        }
    }

    static let accessibilityIconCap = DynamicTypeSize.accessibility1

    private var texts: some View {
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
        case .danger: Image(systemName: "exclamationmark.circle")
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

// MARK: - ToastActionButtonStyle

struct ToastActionButtonStyle: ButtonStyle {
    static let minimumHitSide: CGFloat = 44
    static let hitOutset = EdgeInsets(
        top: CoreSpacing.md, leading: CoreSpacing.md, bottom: CoreSpacing.md, trailing: CoreSpacing.md
    )

    @Environment(\.coreAccent) private var coreAccent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(ButtonRoleStyleRole.primary.resolvedColor(
                accent: self.coreAccent, isEnabled: self.isEnabled, isPressed: isPressed
            ))
            .buttonBackground(
                shape: Capsule(style: .continuous),
                fill: Color.surfaceInteractive,
                border: Color.borderSubtle,
                isPressed: isPressed
            )
            .opacity(isPressed ? 0.9 : 1)
            .padding(Self.hitOutset)
            .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Toast — Light") {
    ToastPreviewHarness()
        .preferredColorScheme(.light)
}

#Preview("Toast — Dark") {
    ToastPreviewHarness()
        .preferredColorScheme(.dark)
}

private struct ToastPreviewHarness: View {
    var body: some View {
        ToastDemoView()
            .toastHost(edge: .top)
    }
}

private struct ToastDemoView: View {
    @Environment(\.toastHost) private var toast

    private let levels: [(label: String, level: StatusLevel)] = [
        ("Info", .info),
        ("Success", .success),
        ("Warning", .warning),
        ("Danger", .danger),
        ("Neutral", .neutral),
    ]

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Tap a button to enqueue a toast.")
                .coreFont(.callout)
                .foregroundStyle(Color.contentMuted)
            ForEach(self.levels, id: \.label) { entry in
                Button(entry.label) {
                    self.toast?.show("\(entry.label): demo message", level: entry.level)
                }
            }
            Button("With description + action") {
                self.toast?.show(ToastItem(
                    title: "Message archived",
                    description: "It moves back to the inbox if you undo within a few seconds.",
                    level: .neutral,
                    action: ToastAction("Undo") {}
                ))
            }
            Button("Burst (queue all 4)") {
                for entry in self.levels {
                    self.toast?.show("\(entry.label) queued.", level: entry.level)
                }
            }
        }
        .padding(CoreSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
    }
}
