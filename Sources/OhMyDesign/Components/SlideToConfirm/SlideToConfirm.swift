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

    static func standard(width: CGFloat, controlSize: ControlSize) -> Self {
        Self(width: width, knob: CoreControlMetrics.height(for: controlSize), spacing: CoreSpacing.xs)
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

    private(set) var phase: Phase = .idle
    private(set) var feedback: SlideToConfirmFeedbackEvent?
    private(set) var announcement: Announcement?
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

    mutating func drag(_ translation: CGFloat) {
        guard self.acceptsInput else { return }
        self.translation = translation
    }

    mutating func release(_ sample: SlideToConfirmDragSample, geometry: SlideToConfirmGeometry) -> Release {
        self.translation = nil
        guard self.acceptsInput else { return .ignored }
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
        guard self.translation != nil else { return }
        self.translation = nil
        self.settles += 1
    }

    mutating func activate() -> Int? {
        guard let run = self.gate.admit() else { return nil }
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

    func dragChanged(_ translation: CGFloat) {
        self.core.drag(translation)
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
/// 从确认到回位走完之间，手势与无障碍激活都被忽略——一次滑动只对应一次执行。
///
/// 对辅助技术整体暴露为一个普通按钮：激活即执行同一个 `action`，执行中为禁用并带「Loading」状态。
/// 强调色读 `View.coreAccent(_:on:)`；尺寸读 `controlSize`。
public struct SlideToConfirm<Label: View>: View {
    @State private var runner: SlideToConfirmRunner
    @State private var width: CGFloat = 0
    @GestureState private var dragging = false

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.coreAccent) private var resolvedAccent
    @Environment(\.coreAccentOn) private var resolvedOn
    @Environment(\.self) private var environment
    @Environment(\.locale) private var locale
    @Environment(\.slideToConfirmAnnouncementPoster) private var poster

    private let action: @MainActor @Sendable () async throws -> Void
    private let label: Label

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
        let geometry = SlideToConfirmGeometry.standard(width: self.width, controlSize: self.controlSize)
        let offset = core.knobOffset(in: geometry)
        return ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.secondaryFill)
            self.label
                .coreFont(CoreControlMetrics.fontToken(for: self.controlSize))
                .foregroundStyle(self.isEnabled ? Color.contentSecondary : Color.contentDisabled)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.leading, geometry.knob + 2 * geometry.spacing)
                .padding(.trailing, 2 * geometry.spacing)
                .opacity(geometry.titleOpacity(forOffset: offset))
            self.knob(geometry: geometry, executing: core.phase == .executing)
                .padding(geometry.spacing)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .updating(self.$dragging) { _, state, _ in state = true }
                        .onChanged { value in self.runner.dragChanged(value.translation.width) }
                        .onEnded { value in
                            self.runner.release(
                                SlideToConfirmDragSample(
                                    translation: value.translation.width,
                                    predictedEndTranslation: value.predictedEndTranslation.width
                                ),
                                geometry: geometry,
                                presentation: self.motionPresentation,
                                action: self.action
                            )
                        },
                    isEnabled: core.acceptsInput && self.isEnabled
                )
        }
        .frame(height: geometry.trackHeight)
        .environment(\.layoutDirection, .leftToRight)
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
            .disabled(!core.acceptsInput)
            .accessibilityValue(core.phase.accessibilityValueText ?? Text(verbatim: ""))
        }
    }

    private func knob(geometry: SlideToConfirmGeometry, executing: Bool) -> some View {
        let fill = self.isEnabled ? self.resolvedAccent : Color.accentDisabled(from: self.resolvedAccent)
        let foreground = self.resolvedOn ?? Color.onAccent(for: self.resolvedAccent, in: self.environment)
        return Circle()
            .fill(fill)
            .frame(width: geometry.knob, height: geometry.knob)
            .overlay {
                ZStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: CoreControlMetrics.iconSize(for: self.controlSize), weight: .semibold))
                        .opacity(executing ? 0 : 1)
                    if executing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(foreground)
                            .transition(.opacity)
                    }
                }
                .foregroundStyle(foreground)
                .animation(CoreMotionToken.press.animation(for: self.motionPresentation), value: executing)
            }
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
