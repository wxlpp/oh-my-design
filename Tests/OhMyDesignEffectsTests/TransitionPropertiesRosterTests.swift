import OhMyDesignEffects
import SwiftUI
import Testing

// MARK: - 全仓 Transition 的 `hasMotion` 花名册 / The repo-wide `hasMotion` roster（Issue #292）

@Suite("Transition 的 hasMotion 花名册（#292）")
struct TransitionPropertiesRoster {
    private struct DefaultPropertiesProbe: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View { content }
    }

    @Test("全仓 12 条 Transition 都据实声明 hasMotion（8 真 / 4 假，逐条）")
    func everyTransitionDeclaresItsMotionHonestly() {
        #expect(TransitionProperties(hasMotion: false).hasMotion == false,
                "`hasMotion` 恒为 true —— 下面 4 条 `== false` 不作数")
        #expect(TransitionProperties(hasMotion: true).hasMotion == true,
                "`hasMotion` 恒为 false —— 下面 8 条 `== true` 不作数")
        #expect(Self.DefaultPropertiesProbe.properties.hasMotion, """
        `Transition.properties` 的协议默认值不再是 `hasMotion == true`
        —— 下面「显式声明 vs 继承默认值」的区分要重新核对。
        """)

        // MARK: 有真实几何运动 ⇒ `true`（8 条）

        #expect(FlipTransition.properties.hasMotion, Self.gateNote("`.flip`"))
        #expect(Rotate3DTransition.properties.hasMotion, Self.gateNote("`.rotate3D`"))
        #expect(SwooshTransition.properties.hasMotion, Self.gateNote("`.swoosh`"))
        #expect(BoingTransition.properties.hasMotion, Self.gateNote("`.boing`"))
        #expect(SkidTransition.properties.hasMotion, Self.gateNote("`.skid`"))
        #expect(PolarMoveTransition.properties.hasMotion, Self.gateNote("`.move`"))
        #expect(MaskRevealTransition.properties.hasMotion, Self.gateNote("`.iris` / `.wipe` / …"))
        #expect(ParticleTransition.properties.hasMotion, Self.gateNote("`.particle`"))

        // MARK: 纯成像滤镜、无几何运动 ⇒ `false`（4 条）

        #expect(BlurTransition.properties.hasMotion == false, Self.optOutNote("`.blur`"))
        #expect(FilmExposureTransition.properties.hasMotion == false, Self.optOutNote("`.filmExposure`"))
        #expect(SnapshotTransition.properties.hasMotion == false, Self.optOutNote("`.snapshot`"))
        #expect(FlickerTransition.properties.hasMotion == false, Self.optOutNote("`.flicker`"))
    }

    static func gateNote(_ name: String) -> Comment {
        Comment(rawValue: """
        \(name) 的 `hasMotion` 变成了 `false` —— 那是在声明"本转场不含运动"，与它的几何运动不符。
        本断言只核声明；Reduce Motion 降级由该转场自己那道手写闸负责（框架不替换，#407 实测）。
        """)
    }

    static func optOutNote(_ name: String) -> Comment {
        Comment(rawValue: """
        \(name) 的 `hasMotion` 不再是 `false` —— 该转场没有几何运动，应如实声明无运动。
        本断言只核声明；框架并不据此做 opacity 替换（#407 实测）。
        """)
    }
}
