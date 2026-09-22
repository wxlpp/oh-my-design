import SwiftUI

// MARK: - CoreMotionToken

/// 语义化动效 token：核心库所有过渡动画的唯一来源，按「这次变化是什么」而不是按曲线参数命名。
///
/// 取值以 SwiftUI 的 `.snappy` / `.smooth` 族为基础（无过冲，贴合墨色 accent 的安静观感），
/// 有意不提供 `.bouncy` 档。Reduce Motion 经 `animation(for:)` 与
/// `EnvironmentValues.coreMotionPresentation` 纳入：框架**不会**替调用方降级位移 / 缩放 / 旋转，
/// 这些变换本身须由调用点按 `coreMotionPresentation` 去掉。
public nonisolated enum CoreMotionToken: Sendable, CaseIterable {
    /// 直接操作的即时反馈：按压缩放 / 变暗、按钮内 label 与进度的切换。0.16 s snappy。
    case press
    /// 选中态切换：分段控件滑块、下划线标签（含把选中项滚到中间）、勾选 / 单选。0.22 s snappy。
    case selection
    /// 出现 / 消失 / 展开：Toast 进出、表单消息、折叠组、加载遮罩。0.25 s smooth。
    case reveal
    /// 页级位移：走马灯翻页。0.35 s smooth；Reduce Motion 下直接到位。
    case scroll

    /// 该档的时长（秒）。与动画节奏耦合的计时（例如退场后再移除）应取这里，而不是另写字面量。
    public var duration: TimeInterval {
        switch self {
        case .press: 0.16
        case .selection: 0.22
        case .reveal: 0.25
        case .scroll: 0.35
        }
    }

    /// 完整动效下的曲线。
    public var animation: Animation {
        switch self {
        case .press, .selection: .snappy(duration: self.duration)
        case .reveal, .scroll: .smooth(duration: self.duration)
        }
    }

    /// 按呈现裁决取曲线。
    ///
    /// - Parameter presentation: 通常取自 `EnvironmentValues.coreMotionPresentation`。
    /// - Returns: `.animated` ⇒ `animation`；`.resting` ⇒ 同时长 `easeInOut`（只用于淡变），
    ///   `scroll` 则为 `nil`（位移不补间，直接到位）；`.hidden` ⇒ `nil`。
    public func animation(for presentation: MotionPresentation) -> Animation? {
        switch presentation {
        case .animated: self.animation
        case .resting: self == .scroll ? nil : .easeInOut(duration: self.duration)
        case .hidden: nil
        }
    }
}

// MARK: - Reduce Motion 入口 / Reduce Motion entry

private nonisolated struct CoreMotionPresentationOverrideKey: EnvironmentKey {
    static let defaultValue: MotionPresentation? = nil
}

public extension EnvironmentValues {
    /// **可注入**的一次性动效呈现裁决。`nil`（默认）⇒ 跟随系统「减弱动态效果」。
    ///
    /// 供预览与测试固定一种呈现；产品代码通常不写它。
    nonisolated var coreMotionPresentationOverride: MotionPresentation? {
        get { self[CoreMotionPresentationOverrideKey.self] }
        set { self[CoreMotionPresentationOverrideKey.self] = newValue }
    }

    /// 一次性过渡动效的呈现裁决：有注入值取注入值；否则 Reduce Motion 开启 ⇒ `.resting`，关闭 ⇒ `.animated`。
    ///
    /// 只看 Reduce Motion，不看能耗——能耗闸只管常驻渲染层（`EnergyState`）。
    nonisolated var coreMotionPresentation: MotionPresentation {
        self.coreMotionPresentationOverride ?? (self.accessibilityReduceMotion ? .resting : .animated)
    }
}

public extension View {
    /// 环境感知的 `animation(_:value:)`：按 `coreMotionPresentation` 取 `motion` 的曲线。
    ///
    /// - Parameters:
    ///   - motion: 动效档位。
    ///   - value: 触发动画的值。
    /// - Returns: 施加了对应曲线的视图。
    func coreAnimation(_ motion: CoreMotionToken, value: some Equatable) -> some View {
        self.modifier(CoreAnimationModifier(motion: motion, value: value))
    }
}

private struct CoreAnimationModifier<Value: Equatable>: ViewModifier {
    let motion: CoreMotionToken
    let value: Value

    @Environment(\.coreMotionPresentation) private var presentation

    func body(content: Content) -> some View {
        content.animation(self.motion.animation(for: self.presentation), value: self.value)
    }
}

// MARK: - 滑动指示器 / Sliding indicators

extension MotionPresentation {
    nonisolated func slidingIndicatorID(_ base: String, slot: AnyHashable) -> AnyHashable {
        self == .animated ? AnyHashable(base) : AnyHashable([AnyHashable(base), slot])
    }
}

extension CoreMotionToken {
    nonisolated func transformAnimation(for presentation: MotionPresentation) -> Animation? {
        presentation == .animated ? self.animation : nil
    }
}

// MARK: - 集合项的增删转场 / Collection item insertion & removal

// 降级量是 `scale(for:phase:)`，不是 `properties`：后者是 static、承载不了逐实例的呈现裁决，
// 而 #407 实测框架并**不**按 `hasMotion` 把转场换成 `.opacity`。
struct CollectionItemTransition: Transition {
    nonisolated static let properties = TransitionProperties(hasMotion: true)

    nonisolated static let enteringScale: CGFloat = 0.86

    let presentation: MotionPresentation

    nonisolated static func scale(for presentation: MotionPresentation, phase: TransitionPhase) -> CGFloat {
        guard presentation == .animated, !phase.isIdentity else { return 1 }
        return Self.enteringScale
    }

    nonisolated static func opacity(for phase: TransitionPhase) -> Double {
        phase.isIdentity ? 1 : 0
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(Self.scale(for: self.presentation, phase: phase))
            .opacity(Self.opacity(for: phase))
    }
}

extension MotionPresentation {
    nonisolated var collectionItemTransition: CollectionItemTransition {
        CollectionItemTransition(presentation: self)
    }
}

// MARK: - 符号 / 数字的内容过渡 / Symbol & numeric content transitions

extension MotionPresentation {
    nonisolated var symbolReplacement: ContentTransition {
        self == .animated ? ContentTransition.symbolEffect(.replace) : ContentTransition.identity
    }

    nonisolated func numericRoll(to value: Int) -> ContentTransition {
        self == .animated ? ContentTransition.numericText(value: Double(value)) : ContentTransition.identity
    }
}
