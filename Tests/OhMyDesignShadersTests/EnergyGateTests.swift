import Foundation
import OhMyDesign
import SwiftUI
import Testing

@testable import OhMyDesignShaders

// NFR-7 能耗闸的纯函数与源码接线判据。渲染级判据（`.hidden` 保留当前帧）在 `RenderProofTests`，只在 iOS 腿跑。
// ⚠️ 低电量 `.reduced` 唯一可观测的量是 `minimumInterval`，单帧位图看不见 ⇒ 这里的纯函数断言就是它的天花板。

@Suite("NFR-7 能耗闸：ProceduralBackground 的调度")
@MainActor
struct EnergyGateScheduleTests {

    private func schedule(
        phase: ScenePhase, lowPower: Bool, reduceMotion: Bool, motion: ShaderMotion = .regular
    ) -> ProceduralBackground.Schedule {
        let energy = EnergyState.resolve(
            injectedScenePhase: phase, systemScenePhase: .active, lowPowerModeOverride: lowPower
        )
        return ProceduralBackground.schedule(
            presentation: energy.presentation(reduceMotion: reduceMotion), policy: energy.policy, motion: motion
        )
    }

    @Test("后台 / inactive ⇒ 暂停，与低电量、Reduce Motion 无关")
    func notActivePauses() {
        for phase in [ScenePhase.background, .inactive] {
            for lowPower in [false, true] {
                for reduceMotion in [false, true] {
                    #expect(
                        self.schedule(phase: phase, lowPower: lowPower, reduceMotion: reduceMotion)
                            == .init(paused: true, minimumInterval: nil),
                        "\(phase) lowPower=\(lowPower) RM=\(reduceMotion)"
                    )
                }
            }
        }
    }

    @Test("前台 + Reduce Motion ⇒ 暂停")
    func reduceMotionPauses() {
        for lowPower in [false, true] {
            #expect(self.schedule(phase: .active, lowPower: lowPower, reduceMotion: true) == .init(paused: true, minimumInterval: nil))
        }
    }

    @Test("前台：满帧不设间隔，低电量降到 RenderPolicy.reduced 的间隔")
    func activeRunsAtPolicyInterval() {
        #expect(self.schedule(phase: .active, lowPower: false, reduceMotion: false) == .init(paused: false, minimumInterval: nil))
        let reduced = self.schedule(phase: .active, lowPower: true, reduceMotion: false)
        #expect(reduced.paused == false)
        #expect(reduced.minimumInterval == RenderPolicy.reduced.minimumInterval)
        #expect(reduced.minimumInterval != nil)
    }

    @Test(".still 档在前台照旧暂停")
    func stillMotionPauses() {
        #expect(self.schedule(phase: .active, lowPower: false, reduceMotion: false, motion: .still).paused)
    }

    @Test("离开 .hidden 时原点顺延暂停时长，回前台接着最后一帧走")
    func resumeShiftsOrigin() {
        let origin = Date(timeIntervalSinceReferenceDate: 1000)
        let pausedAt = origin.addingTimeInterval(12)
        let resumedAt = pausedAt.addingTimeInterval(5)
        let shifted = ProceduralBackground.resumedOrigin(origin: origin, pausedAt: pausedAt, resumedAt: resumedAt)
        #expect(shifted == origin.addingTimeInterval(5))
        let atPause = ProceduralBackground.elapsed(at: pausedAt, origin: origin, motion: .regular, reduceMotion: false)
        let afterResume = ProceduralBackground.elapsed(at: resumedAt, origin: shifted, motion: .regular, reduceMotion: false)
        #expect(atPause == afterResume, "恢复瞬间时间前跳：\(atPause) → \(afterResume)")
        #expect(ProceduralBackground.resumedOrigin(origin: origin, pausedAt: resumedAt, resumedAt: pausedAt) == origin, "时钟回拨不得把原点往回拨")
    }
}

@Suite("NFR-7 能耗闸：ProceduralBackground 的源码接线")
struct EnergyGateWiringTests {

    private static func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/OhMyDesignShaders/ShaderSupport.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("读注入键与系统场景阶段、经 presentation 裁决，TimelineView 的参数取自 schedule")
    func gateIsWired() throws {
        let source = try Self.source()
        for line in [
            "@Environment(\\.scenePhase) private var systemScenePhase",
            "@Environment(\\.scenePhaseOverride) private var scenePhaseOverride",
            "@Environment(\\.lowPowerModeOverride) private var lowPowerModeOverride",
            "injectedScenePhase: self.scenePhaseOverride,",
            "systemScenePhase: self.systemScenePhase,",
            "lowPowerModeOverride: self.lowPowerModeOverride",
            "let presentation = energy.presentation(reduceMotion: self.reduceMotion)",
            "let schedule = Self.schedule(presentation: presentation, policy: energy.policy, motion: self.motion)",
            "TimelineView(.animation(minimumInterval: schedule.minimumInterval, paused: schedule.paused)) { timeline in",
            "let t = self.elapsed(at: self.pausedAt ?? timeline.date)",
            "self.origin = Self.resumedOrigin(origin: self.origin, pausedAt: pausedAt, resumedAt: now)",
        ] {
            #expect(source.contains(line), "ShaderSupport.swift 缺少接线：\(line)")
        }
        #expect(source.components(separatedBy: "TimelineView(").count - 1 == 1, "只允许一个 TimelineView 调用点")
    }
}
