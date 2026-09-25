import SwiftUI

// MARK: - StatefulButtonState

/// 四态动作按钮的视觉态 / The four visual states of a stateful action button.
///
/// 四态是**一个枚举**而不是四个 Bool：任意两态互斥，Bool 组合能表达出 `loading && success`
/// 这类无意义状态。
public nonisolated enum StatefulButtonState: Sendable, Hashable, CaseIterable {
    /// 静息：只画 label，无配件符号。
    case idle
    /// 正在执行调用方的 action。
    case loading
    /// action 正常返回。
    case success
    /// action 抛出了非取消错误。
    case failure
}

public extension StatefulButtonState {
    /// `success` / `failure` 停留时长的默认值（2 s，取自参考实现 `stateful-button` 的 `delay: 2`）。
    nonisolated static let defaultDwell: Duration = .seconds(2)
}

extension StatefulButtonState {
    nonisolated var symbolName: String? {
        switch self {
        case .idle: nil
        case .loading: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        }
    }

    nonisolated var isResult: Bool {
        self == .success || self == .failure
    }

    var badgeColor: Color {
        self == .failure ? Color.danger : Color.success
    }

    var sensoryFeedback: SensoryFeedback? {
        switch self {
        case .success: .success
        case .failure: .error
        case .idle, .loading: nil
        }
    }

    @MainActor
    var accessibilityValueText: Text? {
        switch self {
        case .idle: nil
        case .loading: Text("Loading", bundle: .module)
        case .success: Text("Success", bundle: .module)
        case .failure: Text("Failed", bundle: .module)
        }
    }

    func announcement(locale: Locale) -> String? {
        switch self {
        case .idle: nil
        case .loading: String(localized: "Loading", bundle: .module, locale: locale)
        case .success: String(localized: "Success", bundle: .module, locale: locale)
        case .failure: String(localized: "Failed", bundle: .module, locale: locale)
        }
    }
}

// MARK: - 执行门闩 / Execution gate

// 门闩只认自己发出的运行号，**不读任何视觉态**——视觉态在托管模式下由调用方写，
// 拿它当门闩时调用方把态改回 `.idle` 就能重入。
// `running` 只由该次运行自己的 `finish` 清：离屏作废只收回显示权，不开闸——
// 不响应取消的 action 在离屏后仍在跑，此时开闸会让回屏后的点击并发重入。
struct StatefulButtonGate: Sendable, Hashable {
    private var issued = 0
    private var running: Int?
    private var displaying = 0

    var isRunning: Bool { self.running != nil }

    mutating func admit() -> Int? {
        guard self.running == nil else { return nil }
        self.issued += 1
        self.running = self.issued
        self.displaying = self.issued
        return self.issued
    }

    mutating func finish(_ run: Int) -> Bool {
        if self.running == run { self.running = nil }
        return self.ownsDisplay(run)
    }

    func ownsDisplay(_ run: Int) -> Bool { self.displaying == run }

    mutating func invalidate() {
        self.issued += 1
        self.displaying = self.issued
    }
}

// MARK: - 执行结果 / Outcome

enum StatefulButtonOutcome: Sendable, Hashable, CaseIterable {
    case succeeded
    case failed
    case cancelled

    var state: StatefulButtonState {
        switch self {
        case .succeeded: .success
        case .failed: .failure
        case .cancelled: .idle
        }
    }

    @MainActor
    static func resolve(_ action: @MainActor @Sendable () async throws -> Void) async -> Self {
        do {
            try await action()
            return .succeeded
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed
        }
    }
}

// MARK: - 状态机 / State machine

// `host != nil` ⇒ 托管模式：调用方是视觉态的**唯一写入方**，本类型只读它。
// `host == nil` ⇒ 自管模式：本类型是唯一写入方。两种模式共用同一个 `gate`。
struct StatefulButtonCore: Sendable, Hashable {
    enum Tap: Sendable, Hashable {
        case run(Int)
        case ignored
    }

    private var gate = StatefulButtonGate()
    private var managed: StatefulButtonState = .idle

    var isRunning: Bool { self.gate.isRunning }

    func display(host: StatefulButtonState?) -> StatefulButtonState {
        host ?? self.managed
    }

    // `host` 只决定「谁写视觉态」，**不参与准入判定**——准入只看 `gate`。
    mutating func tap(host: StatefulButtonState?) -> Tap {
        guard let run = self.gate.admit() else { return .ignored }
        if host == nil { self.managed = .loading }
        return .run(run)
    }

    mutating func settle(_ run: Int, to state: StatefulButtonState, host: StatefulButtonState?) -> Bool {
        let owned = self.gate.finish(run)
        if host == nil { self.managed = owned ? state : .idle }
        return owned
    }

    mutating func reset(_ run: Int, host: StatefulButtonState?) -> Bool {
        guard self.gate.ownsDisplay(run) else { return false }
        if host == nil { self.managed = .idle }
        return true
    }

    mutating func invalidate(host: StatefulButtonState?) {
        self.gate.invalidate()
        if host == nil { self.managed = self.gate.isRunning ? .loading : .idle }
    }
}

// MARK: - 编排 / Orchestration

// 点击 → 准入 → 跑 action → 落定 → 停留 → 复位，以及离屏取消 + 作废；视图只做接线。
// `sleep` 可注入，好让停留复位在测试里不靠挂钟。
@MainActor
@Observable
final class StatefulButtonRunner {
    private(set) var core = StatefulButtonCore()
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void

    init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    @discardableResult
    func tap(
        host: StatefulButtonState?,
        successDwell: Duration,
        failureDwell: Duration,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) -> Bool {
        guard case .run(let run) = self.core.tap(host: host) else { return false }
        self.task?.cancel()
        self.task = Task { @MainActor in
            await self.perform(
                run: run, host: host, successDwell: successDwell, failureDwell: failureDwell, action: action
            )
        }
        return true
    }

    func disappear(host: StatefulButtonState?) {
        self.task?.cancel()
        self.core.invalidate(host: host)
    }

    private func perform(
        run: Int,
        host: StatefulButtonState?,
        successDwell: Duration,
        failureDwell: Duration,
        action: @MainActor @Sendable () async throws -> Void
    ) async {
        let outcome = await StatefulButtonOutcome.resolve(action)
        guard self.core.settle(run, to: outcome.state, host: host) else { return }
        let dwell: Duration? = switch outcome {
        case .succeeded: successDwell
        case .failed: failureDwell
        case .cancelled: nil
        }
        guard host == nil, let dwell else { return }
        try? await self.sleep(dwell)
        guard !Task.isCancelled else { return }
        _ = self.core.reset(run, host: host)
    }
}

// MARK: - StatefulButton

/// 带 idle / loading / success / failure 四态视觉回执的动作按钮。
///
/// 两种模式，由是否传 `state` 决定：
///
/// - **自管**（不传 `state`）：组件是视觉态的唯一写入方。点击 → `loading` → action 返回 →
///   `success` / `failure` → 停留 `successDwell` / `failureDwell` → 回 `idle`。
/// - **托管**（传 `state`）：**调用方**是视觉态的唯一写入方，组件从不写它，也不做停留复位；
///   组件仍持有防重入门闩与 `Task`。
///
/// 两种模式下防重入门闩都**不看视觉态**：托管模式的调用方在 action 执行期间把 `state` 改回
/// `.idle`，再次点击仍不会重入。
///
/// action 不加隐式超时（那是调用方的事）；需要超时请在 action 内竞速后抛错，失败态会随之出现。
/// 用 `withThrowingTaskGroup` 竞速时，被竞速的操作**必须协作式响应取消**：task group
/// 要等所有子任务结束才返回，不响应取消的操作会让超时抛错迟迟不到、按钮一直停在 `loading`。
/// 需要拿到 `Error` 本身（记日志 / 弹 toast）时在 action 内 `catch` 后处理并 `rethrow`。
///
/// 与 `AsyncButton` 的分工：只需要「正在跑」的系统 spinner、不需要成功 / 失败视觉回执时用
/// `AsyncButton`；需要四态回执、无障碍播报与外部托管态时用本组件。
public struct StatefulButton<Label: View>: View {
    @State private var runner = StatefulButtonRunner()
    @State private var failureShakes = 0
    @State private var lastResult: StatefulButtonState = .success

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize
    @Environment(\.statefulButtonAnnouncementPoster) private var poster
    @Environment(\.locale) private var locale

    private let hostState: StatefulButtonState?
    private let successDwell: Duration
    private let failureDwell: Duration
    private let action: @MainActor @Sendable () async throws -> Void
    private let label: Label

    /// 自管模式 / Self-managed。
    ///
    /// - Parameters:
    ///   - successDwell: `success` 停留时长，之后自动回 `idle`。
    ///   - failureDwell: `failure` 停留时长，之后自动回 `idle`。
    ///   - action: 业务动作；抛出非 `CancellationError` 的错误 ⇒ `failure`。
    ///   - label: 按钮内容。
    public init(
        successDwell: Duration = StatefulButtonState.defaultDwell,
        failureDwell: Duration = StatefulButtonState.defaultDwell,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.hostState = nil
        self.successDwell = successDwell
        self.failureDwell = failureDwell
        self.action = action
        self.label = label()
    }

    /// 托管模式 / Host-managed：视觉态由调用方持有并写入。
    ///
    /// - Parameters:
    ///   - state: 当前视觉态；组件只读，不写。
    ///   - action: 业务动作；状态推进由调用方在 action 内完成。
    ///   - label: 按钮内容。
    public init(
        state: StatefulButtonState,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.hostState = state
        self.successDwell = .zero
        self.failureDwell = .zero
        self.action = action
        self.label = label()
    }

    public var body: some View {
        let state = self.runner.core.display(host: self.hostState)
        let slot = CoreControlMetrics.iconSize(for: self.controlSize)
        return Button {
            self.runner.tap(
                host: self.hostState,
                successDwell: self.successDwell,
                failureDwell: self.failureDwell,
                action: self.action
            )
        } label: {
            HStack(spacing: CoreSpacing.xs) {
                if state != .idle {
                    let result = state.isResult ? state : self.lastResult
                    ZStack {
                        StatefulButtonSpinner(isSpinning: self.spins(state), lineWidth: slot * 0.14)
                            .opacity(self.spins(state) ? 1 : 0)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: slot))
                            .opacity(state == .loading && !self.spins(state) ? 1 : 0)
                        Image(systemName: result.symbolName ?? "")
                            .font(.system(size: slot))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, result.badgeColor)
                            .opacity(state.isResult ? 1 : 0)
                            .scaleEffect(state.isResult ? 1 : StatefulButtonMetrics.hiddenSymbolScale)
                    }
                    .frame(width: slot, height: slot)
                    .accessibilityHidden(true)
                }
                self.label
            }
        }
        .animation(CoreMotionToken.press.transformAnimation(for: self.motionPresentation), value: state)
        .modifier(StatefulButtonShake(trigger: self.failureShakes))
        .sensoryFeedback(trigger: state) { _, next in next.sensoryFeedback }
        .modifier(StatefulButtonAccessibility(state: state))
        .onChange(of: state) { _, next in
            if next.isResult {
                self.lastResult = next
            }
            if next == .failure, self.motionPresentation == .animated {
                self.failureShakes += 1
            }
            guard let text = next.announcement(locale: self.locale) else { return }
            self.poster.post(text)
        }
        .onDisappear {
            self.runner.disappear(host: self.hostState)
        }
    }
}

nonisolated enum StatefulButtonMetrics {
    static let shakeOffsets: [CGFloat] = [-6, 6, -4, 4, 0]
    static let shakeStep: TimeInterval = CoreMotionToken.reveal.duration / Double(shakeOffsets.count)
    static let hiddenSymbolScale: CGFloat = 0.4
}

extension StatefulButton {
    func spins(_ state: StatefulButtonState) -> Bool {
        state == .loading && self.motionPresentation == .animated
    }
}

// MARK: - Failure shake

struct StatefulButtonShake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: self.trigger) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            KeyframeTrack {
                for dx in StatefulButtonMetrics.shakeOffsets {
                    CubicKeyframe(dx, duration: StatefulButtonMetrics.shakeStep)
                }
            }
        }
    }
}

// MARK: - Spinner

struct StatefulButtonSpinner: View {
    let isSpinning: Bool
    let lineWidth: CGFloat

    static let period: TimeInterval = 0.8

    static func angle(at date: Date) -> Angle {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
        return .degrees(phase * 360)
    }

    var body: some View {
        TimelineView(.animation(paused: !self.isSpinning)) { context in
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(.primary, style: StrokeStyle(lineWidth: self.lineWidth, lineCap: .round))
                .padding(self.lineWidth / 2)
                .rotationEffect(Self.angle(at: context.date))
        }
    }
}

// MARK: - 无障碍 / Accessibility

extension EnvironmentValues {
    @Entry var statefulButtonAnnouncementPoster: FieldAnnouncementPoster = .system
}

// 恒挂同一个 modifier、idle 给空值：写成 `if let … else content` 会产生 `_ConditionalContent`，
// idle ↔ 非 idle 时整棵 Button 子树换身份被重建，挂在里面的宽度动画就不补间了。
private struct StatefulButtonAccessibility: ViewModifier {
    let state: StatefulButtonState

    func body(content: Content) -> some View {
        content.accessibilityValue(self.state.accessibilityValueText ?? Text(verbatim: ""))
    }
}

// MARK: - Text label conveniences

public extension StatefulButton where Label == Text {
    /// 自管模式 + `LocalizedStringKey` 文案。
    ///
    /// - Parameters:
    ///   - titleKey: 按钮文案。
    ///   - successDwell: `success` 停留时长。
    ///   - failureDwell: `failure` 停留时长。
    ///   - action: 业务动作。
    init(
        _ titleKey: LocalizedStringKey,
        successDwell: Duration = StatefulButtonState.defaultDwell,
        failureDwell: Duration = StatefulButtonState.defaultDwell,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.init(
            successDwell: successDwell,
            failureDwell: failureDwell,
            action: action
        ) { Text(titleKey) }
    }

    /// 托管模式 + `LocalizedStringKey` 文案。
    ///
    /// - Parameters:
    ///   - titleKey: 按钮文案。
    ///   - state: 当前视觉态；组件只读，不写。
    ///   - action: 业务动作。
    init(
        _ titleKey: LocalizedStringKey,
        state: StatefulButtonState,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.init(state: state, action: action) { Text(titleKey) }
    }
}

// MARK: - Previews (development only — snapshot 脚本会删除 OhMyDesign_*.png)

#Preview("StatefulButton — 自管四态") {
    VStack(spacing: 16) {
        StatefulButton("Send message") {
            try await Task.sleep(for: .milliseconds(1200))
        }
        .buttonStyle(.solid())

        StatefulButton("Always fails") {
            try await Task.sleep(for: .milliseconds(800))
            struct DemoError: LocalizedError {
                var errorDescription: String? { "Demo failure" }
            }
            throw DemoError()
        }
        .buttonStyle(.light())

        StatefulButton("Short dwell", successDwell: .milliseconds(400)) {
            try await Task.sleep(for: .milliseconds(600))
        }
        .buttonStyle(.borderless())
    }
    .padding()
}

#Preview("StatefulButton — 托管态（调用方写）") {
    struct Harness: View {
        @State private var state: StatefulButtonState = .idle

        var body: some View {
            VStack(spacing: 16) {
                StatefulButton("Upload", state: self.state) {
                    self.state = .loading
                    do {
                        try await Task.sleep(for: .milliseconds(900))
                        self.state = .success
                        try await Task.sleep(for: .seconds(1))
                        self.state = .idle
                    } catch {
                        self.state = .idle
                        throw error
                    }
                }
                .buttonStyle(.solid())

                Picker("State", selection: self.$state) {
                    Text(verbatim: "idle").tag(StatefulButtonState.idle)
                    Text(verbatim: "loading").tag(StatefulButtonState.loading)
                    Text(verbatim: "success").tag(StatefulButtonState.success)
                    Text(verbatim: "failure").tag(StatefulButtonState.failure)
                }
                .pickerStyle(.segmented)
            }
            .padding()
        }
    }
    return Harness()
}

#Preview("StatefulButton — 四态静息对照") {
    VStack(spacing: 16) {
        ForEach(StatefulButtonState.allCases, id: \.self) { state in
            StatefulButton("Submit", state: state) { }
                .buttonStyle(.solid())
        }
    }
    .padding()
}
