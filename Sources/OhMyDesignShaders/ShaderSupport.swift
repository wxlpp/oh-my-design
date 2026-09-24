//
//  ShaderSupport.swift
//  OhMyDesignShaders
//
//  程序化背景的公共骨架 / Shared scaffolding for procedural backgrounds.
//

import OhMyDesign
import SwiftUI
import Synchronization

// MARK: - ShaderMotion

/// 运动速度档位。**所有**动画 shader 共用这一个枚举。
///
/// ⚠️ 不暴露"时间缩放系数"这类裸数值——本仓的调参惯例是语义档位单一来源
/// （对照 `ButtonRoleStyleRole`：role 调色板的唯一来源，新增 role 扩枚举而不是各自定义）。
public nonisolated enum ShaderMotion: Sendable, CaseIterable {
    case still, calm, regular, lively

    /// 展开成时间缩放。⚠️ 展开在 Swift 侧，公开面只有档位。
    var speed: Double {
        switch self {
        case .still: 0
        case .calm: 0.12
        case .regular: 0.28
        case .lively: 0.55
        }
    }
}

// MARK: - ProceduralBackground

/// 程序化背景的公共骨架：时间原点、能耗闸（NFR-7）、Reduce Motion 冻结、装饰层 a11y。
///
/// ⚠️ **每个背景都必须经由本类型构建，不要各自搭 `TimelineView`**——它封装了一个
/// 只有在真渲染时才会暴露的坑，见 `origin` 的注释。
///
/// ⚠️ **能耗闸的 `.hidden`（后台 / inactive）在这里是「暂停并保留最后一帧」，不是整层不建**
/// ——有意偏离 `RenderPolicy.drawsAnything` 的通用约定与 Effects 的 `AnimatedMeshGradient`
/// （`.hidden` ⇒ `EmptyView()`），也不套用 `OrbitingLogos` 那条「`.hidden` 摘掉装饰层与调度器」
/// 的收窄裁决（`docs/components/orbiting-logos.md`）：环是内容旁的装饰，摘掉后内容仍完整；
/// 全幅背景**就是**可见表面，而 `.inactive` 时画面仍然可见（macOS 上别的 App 在前台时窗口完全可见，
/// iOS 上控制中心 / App 切换器），整层摘掉会把宿主底色闪出来。另外 `EmptyView` 会销毁子树、
/// 重置 `origin`，回前台从 `t = 0` 重放，又是一次可见的闪回。暂停的 `TimelineView` 不再产生帧，
/// 满足「停摆」的能耗目的；回前台时 `origin` 顺延暂停时长，画面接着最后一帧走。
struct ProceduralBackground: View {

    /// 底色。shader 未生效时的降级形态（首帧、或用原生 `swift build` 构建时）。
    ///
    /// ⚠️ 这**不是**在掩盖失败：`OhMyDesignShaders.assertShaderLibraryLoadable`
    /// 会在测试里判红，这里只是让降级形态不难看。
    let base: Color

    let motion: ShaderMotion

    /// 由各 shader 提供：`(布局尺寸, 归一化时间) -> Shader`。
    ///
    /// ⚠️ **必须是 `@Sendable` 而非 `@MainActor`**（#261 终审 I-1）：`visualEffect` 的
    /// 闭包本身是 `@Sendable`（nonisolated），从里面调 `@MainActor` 闭包会报
    /// `main actor-isolated ... can not be referenced from a Sendable closure`。
    /// ⇒ 调用方须在 `body`（MainActor 上下文）里把要捕获的东西**先取成值**，
    /// 再让这个闭包只做纯计算。
    let makeShader: @Sendable (CGSize, Float) -> Shader

    init(
        base: Color,
        motion: ShaderMotion,
        originOverride: Date? = nil,
        makeShader: @escaping @Sendable (CGSize, Float) -> Shader
    ) {
        self.base = base
        self.motion = motion
        self.originOverride = originOverride
        self.makeShader = makeShader
    }

    /// 动画时间的原点。
    ///
    /// ⚠️ **必须以视图出现的时刻为原点，不能直接用 `timeIntervalSinceReferenceDate`**：
    /// 后者当前约 **8.1 亿**，乘上速度后进 `Float` 是 ~2.3e8，而 `Float` 在该量级上的
    /// 精度约 **16 个单位** —— shader 里 `sin(p.x + t)` 的空间项（通常 0…20）会被
    /// 舍入**整个吃掉**，每个像素算出同一个值。
    ///
    /// **表现是「画面纯色 / 完全不动」，而编译、metallib 加载、参数签名全部正常**
    /// —— 一个只在真渲染时才暴露的失败面（`Plasma` 落地时实测踩到）。
    @State private var origin = Date()

    /// ⚠️ **仅供测试注入**：把时间原点推到过去，等价于"已经播放了 N 秒"。
    /// 没有它就无法断言「shader 真的吃了 `time`」——渲染证明只比较单帧时，
    /// 一个完全忽略 `time` 的 shader 照样通过（#261 终审 I-3）。
    var originOverride: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var systemScenePhase
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride

    @State private var pausedAt: Date?

    var body: some View {
        let energy = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let presentation = energy.presentation(reduceMotion: self.reduceMotion)
        let schedule = Self.schedule(presentation: presentation, policy: energy.policy, motion: self.motion)

        TimelineView(.animation(minimumInterval: schedule.minimumInterval, paused: schedule.paused)) { timeline in
            let t = self.elapsed(at: self.pausedAt ?? timeline.date)

            self.base
                .visualEffect { content, proxy in
                    ShaderRenderProbe.recordDrawnFrame()
                    return content.colorEffect(self.makeShader(proxy.size, t))
                }
        }
        .onChange(of: presentation) { old, new in
            let now = Date()
            if new == .hidden {
                self.pausedAt = now
            } else if old == .hidden, let pausedAt = self.pausedAt {
                self.origin = Self.resumedOrigin(origin: self.origin, pausedAt: pausedAt, resumedAt: now)
                self.pausedAt = nil
            }
        }
        // FR-13：纯装饰层。承载状态语义的效果由调用方提供 a11y 通告。
        .accessibilityHidden(true)
    }

    struct Schedule: Equatable {
        let paused: Bool
        let minimumInterval: Double?
    }

    static func schedule(presentation: MotionPresentation, policy: RenderPolicy, motion: ShaderMotion) -> Schedule {
        switch presentation {
        case .animated: Schedule(paused: motion == .still, minimumInterval: policy.minimumInterval)
        case .resting, .hidden: Schedule(paused: true, minimumInterval: nil)
        }
    }

    static func resumedOrigin(origin: Date, pausedAt: Date, resumedAt: Date) -> Date {
        origin.addingTimeInterval(max(0, resumedAt.timeIntervalSince(pausedAt)))
    }

    /// Reduce Motion 下**冻结在某一帧**（保留视觉、去掉运动，FR-12），
    /// 而不是停止渲染或换成静态图。
    /// ⚠️ **判定抽成 `static` 纯函数是为了可测**（终审 I-5）：初版整段是 private 方法，
    /// 而 `reduceMotion` 是 `@Environment` —— 脱离视图层级根本注入不了，于是
    /// 「Reduce Motion 下冻结」这条 FR-12 承诺**零覆盖**。
    /// 纯函数把环境读取与判定分开：读取仍在 View 里，判定任何平台都能断言。
    static func elapsed(
        at date: Date, origin: Date, motion: ShaderMotion, reduceMotion: Bool
    ) -> Float {
        guard !reduceMotion, motion != .still else { return 0 }
        return Float(date.timeIntervalSince(origin) * motion.speed)
    }

    func elapsed(at date: Date) -> Float {
        Self.elapsed(
            at: date,
            origin: self.originOverride ?? self.origin,
            motion: self.motion,
            reduceMotion: self.reduceMotion
        )
    }
}

// MARK: - ShaderRamp

/// 由单一 `tint` 推导出的三档调色斜坡。
///
/// 手法与 `InteractionColors` 的 `accentHover` / `accentPressed` 一致
/// （`Color.mix(with:by:)` 对基色本身调制），而不是各取一个固定色阶。
///
/// ⚠️ **`.metal` 侧一律零硬编码色**（FR-8）：三档全部由此推导后经 `.color(...)` 传入。
struct ShaderRamp {
    let low: Color
    let mid: Color
    let high: Color

    /// - Parameter contrast: Reduce Transparency 开启时收窄斜坡——三档相互靠拢，
    ///   让背景读起来更接近一块实色（FR-12）。
    init(tint: Color, reduceTransparency: Bool) {
        let spread = reduceTransparency ? 0.12 : 0.34
        self.low = tint.mix(with: .surfaceCanvas, by: 0.5 + spread)
        self.mid = tint
        self.high = tint.mix(with: .contentPrimary, by: spread)
    }
}

// MARK: - 渲染存活读数（基准专用观测点）

/// `ProceduralBackground` **真的提交了 shader** 的帧数。
@_spi(OhMyDesignBenchmark)
public nonisolated enum ShaderRenderProbe {
    private static let counter = Atomic<Int>(0)

    /// 至今提交过 shader 的帧数。基准取**窗口前后的差值**。
    public static var drawnFrames: Int { Self.counter.load(ordering: .relaxed) }

    static func recordDrawnFrame() {
        Self.counter.wrappingAdd(1, ordering: .relaxed)
    }
}
