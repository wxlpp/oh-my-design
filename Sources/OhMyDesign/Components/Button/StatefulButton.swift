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
    // 三个非静息态的符号必须互异：相同就无法在渲染上分辨，`StatefulButtonTests` 按这条钉死。
    nonisolated var symbolName: String? {
        switch self {
        case .idle: nil
        case .loading: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
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
}

// MARK: - 执行门闩 / Execution gate

// 门闩只认自己发出的运行号，**不读任何视觉态**——视觉态在托管模式下由调用方写，
// 拿它当门闩时调用方把态改回 `.idle` 就能重入。
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
        guard self.running == run else { return false }
        self.running = nil
        return true
    }

    func ownsDisplay(_ run: Int) -> Bool { self.displaying == run }

    mutating func invalidate() {
        self.issued += 1
        self.displaying = self.issued
        self.running = nil
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
        guard self.gate.finish(run) else { return false }
        if host == nil { self.managed = state }
        return true
    }

    mutating func reset(_ run: Int, host: StatefulButtonState?) -> Bool {
        guard self.gate.ownsDisplay(run) else { return false }
        if host == nil { self.managed = .idle }
        return true
    }

    mutating func invalidate() { self.gate.invalidate() }
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
/// action 不加隐式超时（那是调用方的事）；需要超时请在 action 内用
/// `withTaskGroup` / `Task.sleep` 自行竞速后抛错，失败态会随之出现。
/// 需要拿到 `Error` 本身（记日志 / 弹 toast）时在 action 内 `catch` 后处理并 `rethrow`。
///
/// 与 `AsyncButton` 的分工：只需要「正在跑」的系统 spinner、不需要成功 / 失败视觉回执时用
/// `AsyncButton`；需要四态回执、无障碍播报与外部托管态时用本组件。
public struct StatefulButton<Label: View>: View {
    @State private var core = StatefulButtonCore()
    @State private var task: Task<Void, Never>?

    @Environment(\.coreMotionPresentation) private var motionPresentation
    @Environment(\.controlSize) private var controlSize

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
        let state = self.core.display(host: self.hostState)
        let slot = CoreControlMetrics.iconSize(for: self.controlSize)
        return Button {
            self.handleTap()
        } label: {
            HStack(spacing: CoreSpacing.xs) {
                if let symbol = state.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: slot))
                        .frame(width: slot, height: slot)
                        .contentTransition(self.motionPresentation.symbolReplacement)
                        .accessibilityHidden(true)
                }
                self.label
            }
        }
        .animation(CoreMotionToken.press.transformAnimation(for: self.motionPresentation), value: state)
        .modifier(StatefulButtonAccessibility(state: state))
        .onDisappear {
            self.task?.cancel()
            self.core.invalidate()
        }
    }

    private func handleTap() {
        guard case .run(let run) = self.core.tap(host: self.hostState) else { return }
        self.task?.cancel()
        self.task = Task { @MainActor in
            await self.perform(run: run)
        }
    }

    @MainActor
    private func perform(run: Int) async {
        let outcome = await StatefulButtonOutcome.resolve(self.action)
        guard self.core.settle(run, to: outcome.state, host: self.hostState) else { return }
        guard self.hostState == nil, let dwell = self.dwell(for: outcome) else { return }
        try? await Task.sleep(for: dwell)
        guard !Task.isCancelled else { return }
        _ = self.core.reset(run, host: self.hostState)
    }

    private func dwell(for outcome: StatefulButtonOutcome) -> Duration? {
        switch outcome {
        case .succeeded: self.successDwell
        case .failed: self.failureDwell
        case .cancelled: nil
        }
    }
}

// MARK: - 无障碍 / Accessibility

private struct StatefulButtonAccessibility: ViewModifier {
    let state: StatefulButtonState

    func body(content: Content) -> some View {
        if let value = self.state.accessibilityValueText {
            content.accessibilityValue(value)
        } else {
            content
        }
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
                    try await Task.sleep(for: .milliseconds(900))
                    self.state = .success
                    try await Task.sleep(for: .seconds(1))
                    self.state = .idle
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
