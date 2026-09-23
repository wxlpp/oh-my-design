import SwiftUI

// MARK: - 几何 / Geometry

nonisolated struct SlideToConfirmDragSample: Sendable, Hashable {
    let translation: CGFloat
    let predictedEndTranslation: CGFloat
}

nonisolated struct SlideToConfirmGeometry: Sendable, Hashable {
    let width: CGFloat
    let knob: CGFloat
    let spacing: CGFloat
    var layoutDirection: LayoutDirection = .leftToRight

    static func standard(width: CGFloat, controlSize: ControlSize, layoutDirection: LayoutDirection) -> Self {
        Self(
            width: width,
            knob: CoreControlMetrics.height(for: controlSize),
            spacing: CoreSpacing.xs,
            layoutDirection: layoutDirection
        )
    }

    // RTL 下 `.offset(x:)` 会被镜像，`DragGesture` 的位移与位置却按物理方向计 ⇒ 只换算手势这一侧。
    var directionSign: CGFloat { self.layoutDirection == .rightToLeft ? -1 : 1 }

    func sample(translation: CGFloat, predictedEndTranslation: CGFloat) -> SlideToConfirmDragSample {
        SlideToConfirmDragSample(
            translation: translation * self.directionSign,
            predictedEndTranslation: predictedEndTranslation * self.directionSign
        )
    }

    func logicalX(_ physicalX: CGFloat) -> CGFloat {
        self.layoutDirection == .rightToLeft ? self.width - physicalX : physicalX
    }

    // 指示器连同两侧间距都算命中区。
    func knobContains(logicalX x: CGFloat, atOffset offset: CGFloat) -> Bool {
        x >= offset && x <= offset + self.knob + 2 * self.spacing
    }

    var trackHeight: CGFloat { self.knob + 2 * self.spacing }

    var travel: CGFloat {
        guard self.width.isFinite else { return 0 }
        return max(0, self.width - self.knob - 2 * self.spacing)
    }

    func clampedOffset(forTranslation translation: CGFloat) -> CGFloat {
        guard !translation.isNaN else { return 0 }
        return min(max(translation, 0), self.travel)
    }

    // 不要加 predictedEndTranslation 速度补偿：高代价确认不该因甩得快而降低门槛。
    func confirms(_ sample: SlideToConfirmDragSample) -> Bool {
        self.travel > 0 && sample.translation >= self.travel
    }

    var idleKnobRegion: ClosedRange<CGFloat> { self.spacing...(self.spacing + self.knob) }

    var titleLeadingInset: CGFloat { self.knob + 2 * self.spacing }

    var titleTrailingInset: CGFloat { 2 * self.spacing }

    var titleRegion: ClosedRange<CGFloat> {
        self.titleLeadingInset...max(self.titleLeadingInset, self.width - self.titleTrailingInset)
    }

    func titleOpacity(forOffset offset: CGFloat) -> Double {
        guard self.travel > 0 else { return 1 }
        return Double(1 - self.clampedOffset(forTranslation: offset) / self.travel)
    }
}

// MARK: - 动效 / Motion

nonisolated enum SlideToConfirmMotion {
    static func returnDwell(for presentation: MotionPresentation) -> Duration {
        presentation == .animated ? .seconds(CoreMotionToken.reveal.duration) : .zero
    }
}

// MARK: - 外观 / Appearance

nonisolated enum SlideToConfirmAppearance {
    static let disabledOpacity: Double = 0.4

    // 指示器恒为浅色岛：accent 默认是墨色（深色外观下为白），白底上的箭头要在浅色外观下解析才看得见。
    static let knobScheme: ColorScheme = .light

    static let knobElevation: CoreElevation.Level = .medium

    static func opacity(isEnabled: Bool) -> Double {
        isEnabled ? 1 : Self.disabledOpacity
    }
}

// MARK: - 流光 / Shimmer

enum SlideToConfirmShimmer {
    static let period: TimeInterval = 2.4

    static let bandWidth: CGFloat = 0.6

    static func sweeps(
        presentation: MotionPresentation,
        isEnabled: Bool,
        phase: SlideToConfirmCore.Phase,
        isOnScreen: Bool
    ) -> Bool {
        presentation == .animated && isEnabled && phase == .idle && isOnScreen
    }

    static func progress(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period)
        return CGFloat((t < 0 ? t + Self.period : t) / Self.period)
    }

    static func bandCenter(progress: CGFloat, layoutDirection: LayoutDirection) -> CGFloat {
        let logical = -Self.bandWidth / 2 + (1 + Self.bandWidth) * progress
        return layoutDirection == .rightToLeft ? 1 - logical : logical
    }

    static func style(bandCenter center: CGFloat?) -> LinearGradient {
        guard let center else {
            return LinearGradient(colors: [Color.contentSecondary, Color.contentSecondary], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(
            stops: [
                .init(color: Color.contentSecondary, location: 0),
                .init(color: Color.contentPrimary, location: 0.5),
                .init(color: Color.contentSecondary, location: 1),
            ],
            startPoint: UnitPoint(x: center - Self.bandWidth / 2, y: 0.5),
            endPoint: UnitPoint(x: center + Self.bandWidth / 2, y: 0.5)
        )
    }
}

// MARK: - 触觉 / Sensory feedback

nonisolated enum SlideToConfirmFeedbackKind: Sendable, Hashable {
    case confirm
    case rebound

    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .confirm: .impact(weight: .heavy)
        case .rebound: .selection
        }
    }
}

nonisolated struct SlideToConfirmFeedbackEvent: Sendable, Hashable {
    let sequence: Int
    let kind: SlideToConfirmFeedbackKind
}

// MARK: - 执行门闩 / Execution gate

// 只认自己发出的运行号、不读阶段：阶段是显示用的，门闩关到这次运行的 action 返回且回位走完。
nonisolated struct SlideToConfirmGate: Sendable, Hashable {
    private var issued = 0
    private var running: Int?

    var isRunning: Bool { self.running != nil }

    mutating func admit() -> Int? {
        guard self.running == nil else { return nil }
        self.issued += 1
        self.running = self.issued
        return self.issued
    }

    func owns(_ run: Int) -> Bool { self.running == run }

    mutating func finish(_ run: Int) -> Bool {
        guard self.running == run else { return false }
        self.running = nil
        return true
    }
}

// MARK: - 状态机 / State machine

struct SlideToConfirmCore: Sendable, Hashable {
    enum Phase: Sendable, Hashable {
        case idle
        case executing
        case returning(StatefulButtonOutcome)
    }

    enum Release: Sendable, Hashable {
        case run(Int)
        case rebound
        case ignored
    }

    struct MotionKey: Sendable, Hashable {
        let phase: Phase
        let settles: Int
    }

    struct Announcement: Sendable, Hashable {
        enum Kind: Sendable, Hashable {
            case started
            case finished(StatefulButtonOutcome)
        }

        let sequence: Int
        let kind: Kind
    }

    // 会话在第一次拖动变化时裁决、整段不变：起点不在指示器上或门闩关着 ⇒ 只吸收、不位移、松手不触发。
    // `active` 在 `@GestureState` 复位（`interrupt`）时置假，但裁决留到 `release` 才消费——两者先后不定。
    struct DragSession: Sendable, Hashable {
        let live: Bool
        var active = true
    }

    private(set) var phase: Phase = .idle
    private(set) var feedback: SlideToConfirmFeedbackEvent?
    private(set) var announcement: Announcement?
    private(set) var session: DragSession?
    private var translation: CGFloat?
    private var settles = 0
    private var gate = SlideToConfirmGate()

    var acceptsInput: Bool { !self.gate.isRunning }

    var motionKey: MotionKey { MotionKey(phase: self.phase, settles: self.settles) }

    func knobOffset(in geometry: SlideToConfirmGeometry) -> CGFloat {
        switch self.phase {
        case .idle: geometry.clampedOffset(forTranslation: self.translation ?? 0)
        case .executing: geometry.travel
        case .returning: 0
        }
    }

    mutating func drag(_ translation: CGFloat, startX: CGFloat, geometry: SlideToConfirmGeometry) {
        if self.session?.active != true {
            let onKnob = geometry.knobContains(logicalX: startX, atOffset: self.knobOffset(in: geometry))
            self.session = DragSession(live: onKnob && self.acceptsInput)
        }
        guard self.session?.live == true, self.acceptsInput else { return }
        self.translation = translation
    }

    mutating func release(_ sample: SlideToConfirmDragSample, geometry: SlideToConfirmGeometry) -> Release {
        let live = self.session?.live == true
        self.session = nil
        self.translation = nil
        guard live, self.acceptsInput else { return .ignored }
        if geometry.confirms(sample), let run = self.gate.admit() {
            self.phase = .executing
            self.announce(.started)
            self.emit(.confirm)
            return .run(run)
        }
        self.settles += 1
        if geometry.clampedOffset(forTranslation: sample.translation) > 0 { self.emit(.rebound) }
        return .rebound
    }

    mutating func interrupt() {
        self.session?.active = false
        guard self.translation != nil else { return }
        self.translation = nil
        self.settles += 1
    }

    mutating func activate() -> Int? {
        guard let run = self.gate.admit() else { return nil }
        if let session = self.session { self.session = DragSession(live: false, active: session.active) }
        self.translation = nil
        self.phase = .executing
        self.announce(.started)
        return run
    }

    mutating func settle(_ run: Int, outcome: StatefulButtonOutcome) {
        guard self.gate.owns(run) else { return }
        self.phase = .returning(outcome)
        self.announce(.finished(outcome))
    }

    mutating func finish(_ run: Int) {
        guard self.gate.finish(run) else { return }
        self.phase = .idle
    }

    private mutating func announce(_ kind: Announcement.Kind) {
        self.announcement = Announcement(sequence: (self.announcement?.sequence ?? 0) + 1, kind: kind)
    }

    private mutating func emit(_ kind: SlideToConfirmFeedbackKind) {
        self.feedback = SlideToConfirmFeedbackEvent(sequence: (self.feedback?.sequence ?? 0) + 1, kind: kind)
    }
}

extension SlideToConfirmCore.Phase {
    var accessibilityValueText: Text? {
        self == .executing ? Text("Loading", bundle: .module) : nil
    }
}

extension SlideToConfirmCore.Announcement.Kind {
    func text(locale: Locale) -> String? {
        switch self {
        case .started: String(localized: "Loading", bundle: .module, locale: locale)
        case .finished(.succeeded): String(localized: "Success", bundle: .module, locale: locale)
        case .finished(.failed): String(localized: "Failed", bundle: .module, locale: locale)
        case .finished(.cancelled): nil
        }
    }
}

// MARK: - 编排 / Orchestration

@MainActor
@Observable
final class SlideToConfirmRunner {
    private(set) var core = SlideToConfirmCore()
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void

    init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    func dragChanged(_ translation: CGFloat, startX: CGFloat, geometry: SlideToConfirmGeometry) {
        self.core.drag(translation, startX: startX, geometry: geometry)
    }

    @discardableResult
    func release(
        _ sample: SlideToConfirmDragSample,
        geometry: SlideToConfirmGeometry,
        presentation: MotionPresentation,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) -> Bool {
        guard case .run(let run) = self.core.release(sample, geometry: geometry) else { return false }
        self.start(run: run, presentation: presentation, action: action)
        return true
    }

    func interrupt() {
        self.core.interrupt()
    }

    @discardableResult
    func activate(
        presentation: MotionPresentation,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) -> Bool {
        guard let run = self.core.activate() else { return false }
        self.start(run: run, presentation: presentation, action: action)
        return true
    }

    func disappear() {
        self.task?.cancel()
        self.core.interrupt()
    }

    private func start(
        run: Int,
        presentation: MotionPresentation,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.task = Task { @MainActor in
            let outcome = await StatefulButtonOutcome.resolve(action)
            self.core.settle(run, outcome: outcome)
            let dwell = SlideToConfirmMotion.returnDwell(for: presentation)
            if dwell > .zero, !Task.isCancelled {
                try? await self.sleep(dwell)
            }
            self.core.finish(run)
        }
    }
}

// MARK: - SlideToConfirm

/// 滑到底才触发的高代价动作确认 / Slide-to-confirm for costly actions.
///
/// 按住指示器拖到轨道尽头松手才执行 `action`：阈值是纯距离，**不**因甩得快而放宽。
/// 执行期间指示器停在尽头、内部换成进度指示；`action` 返回（含抛错、取消）后指示器回到起点。
/// 从确认到回位走完之间，手势与无障碍激活都被忽略——一次滑动只对应一次执行；
/// 这期间开始的拖动整段作废，回位走完后才松手也不会触发。
/// 从右到左的布局下轨道镜像：指示器从右端出发、向左滑到尽头。
///
/// 视图离屏（例如导航返回）会取消 `action` 所在的任务；不可中断的工作请在 `action` 内另起非结构化 `Task`。
///
/// 对辅助技术整体暴露为一个普通按钮：激活即执行同一个 `action`，执行中为禁用并带「Loading」状态。
/// 箭头与执行中的进度取 `View.coreAccent(_:on:)` 的强调色；尺寸读 `controlSize`。
public struct SlideToConfirm<Label: View>: View {
    @State private var runner: SlideToConfirmRunner
    @State private var width: CGFloat = 0
    @State private var titleOnScreen = true
    @GestureState private var dragging = false

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.coreAccent) private var resolvedAccent
    @Environment(\.scenePhase) private var systemScenePhase
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.slideToConfirmAnnouncementPoster) private var poster

    private let action: @MainActor @Sendable () async throws -> Void
    private let label: Label

    private var reduceMotion: Bool { self.motionPresentation != .animated }

    /// 以自定义 label 创建。
    ///
    /// - Parameters:
    ///   - action: 高代价动作；抛错或被取消后同样回位。
    ///   - label: 轨道上的提示文案，同时是无障碍按钮的名称。
    public init(
        action: @escaping @MainActor @Sendable () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.init(runner: SlideToConfirmRunner(), action: action, label: label)
    }

    init(
        runner: SlideToConfirmRunner,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self._runner = State(initialValue: runner)
        self.action = action
        self.label = label()
    }

    public var body: some View {
        let core = self.runner.core
        let geometry = SlideToConfirmGeometry.standard(
            width: self.width,
            controlSize: self.controlSize,
            layoutDirection: self.layoutDirection
        )
        let offset = core.knobOffset(in: geometry)
        let energy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let sweeps = SlideToConfirmShimmer.sweeps(
            presentation: energy.presentation(reduceMotion: self.reduceMotion),
            isEnabled: self.isEnabled,
            phase: core.phase,
            isOnScreen: self.titleOnScreen
        )
        return ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.secondaryFill)
                .glassEffect(.regular, in: Capsule(style: .continuous))
            self.title(geometry: geometry, sweeps: sweeps, energy: energy.policy)
                .opacity(geometry.titleOpacity(forOffset: offset))
            self.knob(geometry: geometry, executing: core.phase == .executing)
                .padding(geometry.spacing)
                .offset(x: offset)
        }
        .frame(height: geometry.trackHeight)
        .opacity(SlideToConfirmAppearance.opacity(isEnabled: self.isEnabled))
        .contentShape(Capsule(style: .continuous))
        // 挂在整条轨道上：起点不在指示器上的横滑也被吸收，不漏给系统返回手势。
        // 执行 / 回位期间不停用，正确性由 core 的会话裁决与门闩保证。
        .gesture(
            DragGesture()
                .updating(self.$dragging) { _, state, _ in state = true }
                .onChanged { value in
                    self.runner.dragChanged(
                        value.translation.width * geometry.directionSign,
                        startX: geometry.logicalX(value.startLocation.x),
                        geometry: geometry
                    )
                }
                .onEnded { value in
                    self.runner.release(
                        geometry.sample(
                            translation: value.translation.width,
                            predictedEndTranslation: value.predictedEndTranslation.width
                        ),
                        geometry: geometry,
                        presentation: self.motionPresentation,
                        action: self.action
                    )
                },
            isEnabled: self.isEnabled
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { self.width = $0 }
        .animation(CoreMotionToken.reveal.transformAnimation(for: self.motionPresentation), value: core.motionKey)
        .sensoryFeedback(trigger: core.feedback) { _, event in event?.kind.sensoryFeedback }
        .onChange(of: self.dragging) { _, active in
            if !active { self.runner.interrupt() }
        }
        .onChange(of: core.announcement) { _, next in
            guard let text = next?.kind.text(locale: self.locale) else { return }
            self.poster.post(text)
        }
        .onDisappear {
            self.runner.disappear()
        }
        .accessibilityRepresentation {
            Button {
                self.runner.activate(presentation: self.motionPresentation, action: self.action)
            } label: {
                self.label
            }
            .accessibilityHint(Text("Double-tap to confirm", bundle: .module))
            .disabled(!core.acceptsInput)
            .accessibilityValue(core.phase.accessibilityValueText ?? Text(verbatim: ""))
        }
    }

    private func title(geometry: SlideToConfirmGeometry, sweeps: Bool, energy: RenderPolicy) -> some View {
        ZStack {
            if sweeps {
                TimelineView(.animation(minimumInterval: energy.minimumInterval)) { context in
                    self.titleText(bandCenter: SlideToConfirmShimmer.bandCenter(
                        progress: SlideToConfirmShimmer.progress(at: context.date),
                        layoutDirection: self.layoutDirection
                    ))
                }
            } else {
                self.titleText(bandCenter: nil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, geometry.titleLeadingInset)
        .padding(.trailing, geometry.titleTrailingInset)
        .onAppear { self.titleOnScreen = true }
        .onDisappear { self.titleOnScreen = false }
        .onScrollVisibilityChange { self.titleOnScreen = $0 }
    }

    private func titleText(bandCenter: CGFloat?) -> some View {
        self.label
            .coreFont(CoreControlMetrics.fontToken(for: self.controlSize))
            .foregroundStyle(SlideToConfirmShimmer.style(bandCenter: bandCenter))
            .lineLimit(1)
    }

    private func knob(geometry: SlideToConfirmGeometry, executing: Bool) -> some View {
        Circle()
            .fill(Color.surfaceRaised)
            .frame(width: geometry.knob, height: geometry.knob)
            .coreShadow(SlideToConfirmAppearance.knobElevation)
            .overlay {
                ZStack {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: CoreControlMetrics.iconSize(for: self.controlSize), weight: .semibold))
                        .opacity(executing ? 0 : 1)
                    if executing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(self.resolvedAccent)
                            .transition(.opacity)
                    }
                }
                .foregroundStyle(self.resolvedAccent)
                .animation(CoreMotionToken.press.animation(for: self.motionPresentation), value: executing)
            }
            .environment(\.colorScheme, SlideToConfirmAppearance.knobScheme)
    }
}

// MARK: - 无障碍 / Accessibility

extension EnvironmentValues {
    @Entry var slideToConfirmAnnouncementPoster: FieldAnnouncementPoster = .system
}

// MARK: - Text label convenience

public extension SlideToConfirm where Label == Text {
    /// 以 `LocalizedStringKey` 文案创建。
    ///
    /// - Parameters:
    ///   - titleKey: 轨道上的提示文案，同时是无障碍按钮的名称。
    ///   - action: 高代价动作；抛错或被取消后同样回位。
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.init(action: action) { Text(titleKey) }
    }
}

// MARK: - Previews (development only — snapshot 脚本会删除 OhMyDesign_*.png)

#Preview("SlideToConfirm") {
    struct Harness: View {
        @State private var confirmed = 0

        var body: some View {
            VStack(spacing: 16) {
                SlideToConfirm("Slide to delete account") {
                    try await Task.sleep(for: .milliseconds(1200))
                    self.confirmed += 1
                }
                SlideToConfirm("Slide to pay") {
                    try await Task.sleep(for: .milliseconds(800))
                }
                .controlSize(.large)
                .coreAccent(.blue)
                SlideToConfirm("Disabled") { }
                    .disabled(true)
                Text(verbatim: "Confirmed \(self.confirmed)")
                    .font(.caption)
            }
            .padding()
        }
    }
    return Harness()
}
