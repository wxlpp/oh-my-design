import Foundation
import SwiftUI
import Synchronization
import Testing
@testable import OhMyDesign

// 等待一律事件驱动、不设时限：全量并行跑时测试排队等 MainActor 就能超过 60 s，连纯同步的条目也会被时限误判。
@Suite("StatefulButton 编排：点击 → 执行 → 停留 → 复位，离屏取消与作废")
@MainActor
struct StatefulButtonRunnerTests {
    private struct DemoError: Error {}

    private static let successDwell: Duration = .milliseconds(1234)
    private static let failureDwell: Duration = .milliseconds(4321)

    private static func runner(sleeper: StatefulSuspension) -> StatefulButtonRunner {
        StatefulButtonRunner { try await sleeper.suspend(recording: $0) }
    }

    @discardableResult
    private static func tap(
        _ runner: StatefulButtonRunner,
        host: StatefulButtonState? = nil,
        action: StatefulSuspension
    ) -> Bool {
        runner.tap(
            host: host,
            successDwell: Self.successDwell,
            failureDwell: Self.failureDwell,
            action: { try await action.suspend() }
        )
    }

    @Test("自管一轮：点击 → loading → 结果 → 按对应时长停留 → idle")
    func selfManagedRunWalksThroughDwellBackToIdle() async throws {
        for (fails, result, dwell) in [
            (false, StatefulButtonState.success, Self.successDwell),
            (true, .failure, Self.failureDwell),
        ] {
            let action = StatefulSuspension(.cooperative)
            let sleeper = StatefulSuspension(.cooperative)
            let runner = Self.runner(sleeper: sleeper)

            #expect(Self.tap(runner, action: action), "idle 下点击未被准入")
            try #require(await action.waitForArrivals(1), "action 没被调起")
            #expect(runner.core.display(host: nil) == .loading)

            action.release(throwing: fails ? DemoError() : nil)
            try #require(await sleeper.waitForArrivals(1), "\(result)：没有进入停留")
            #expect(runner.core.display(host: nil) == result, "停留期间外观实得 \(runner.core.display(host: nil))")
            #expect(sleeper.durations == [dwell], "\(result)：停留时长实得 \(sleeper.durations)")

            sleeper.release()
            await runner.task?.value
            #expect(
                runner.core.display(host: nil) == .idle,
                "\(result)：停留结束后外观实得 \(runner.core.display(host: nil))，期望 idle"
            )
        }
    }

    @Test("运行中离屏：action 收到取消；旧运行未结束时再点被忽略；它结束后不给回执、不停留")
    func disappearingMidRunCancelsAndKeepsGateClosed() async throws {
        let action = StatefulSuspension(.ignoresCancellation)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        Self.tap(runner, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        runner.disappear(host: nil)
        #expect(action.cancelled, "离屏后 action 没收到取消")
        #expect(runner.core.display(host: nil) == .loading, "旧运行仍在跑时外观应如实保持 loading")

        #expect(!Self.tap(runner, action: action), "旧运行未结束时再点被准入了——会并发重入")
        #expect(action.arrivals == 1, "action 被调起 \(action.arrivals) 次，期望 1")

        action.release()
        await runner.task?.value
        #expect(
            runner.core.display(host: nil) == .idle,
            "被作废的运行结束后外观实得 \(runner.core.display(host: nil))，期望 idle（不给回执）"
        )
        #expect(sleeper.arrivals == 0, "被作废的运行进入了停留 \(sleeper.arrivals) 次")
        #expect(Self.tap(runner, action: action), "旧运行结束后门闩应打开")
        try #require(await action.waitForArrivals(2), "新一轮 action 没被调起")
        action.release()
        await runner.task?.value
        #expect(sleeper.arrivals == 1, "新一轮进入停留 \(sleeper.arrivals) 次，期望 1")
    }

    @Test("运行中离屏、action 响应取消：静默回 idle，不进停留")
    func cooperativeCancellationReturnsToIdle() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        Self.tap(runner, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        runner.disappear(host: nil)
        #expect(action.cancelled, "离屏后 action 没收到取消")
        action.release()
        await runner.task?.value
        #expect(runner.core.display(host: nil) == .idle, "取消后外观实得 \(runner.core.display(host: nil))")
        #expect(sleeper.arrivals == 0, "取消后进入了停留 \(sleeper.arrivals) 次")
    }

    @Test("停留期间离屏：立即回 idle，停留被取消")
    func disappearingDuringDwellReturnsToIdle() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.cooperative)
        let runner = Self.runner(sleeper: sleeper)

        Self.tap(runner, action: action)
        try #require(await action.waitForArrivals(1), "action 没被调起")
        action.release()
        try #require(await sleeper.waitForArrivals(1), "没有进入停留")
        #expect(runner.core.display(host: nil) == .success)

        runner.disappear(host: nil)
        #expect(
            runner.core.display(host: nil) == .idle,
            "停留期间离屏后外观实得 \(runner.core.display(host: nil))，期望立即回 idle"
        )
        #expect(sleeper.cancelled, "停留没被取消")
        sleeper.release()
        await runner.task?.value
        #expect(runner.core.display(host: nil) == .idle)
    }

    @Test("托管模式：不写视觉态、不停留")
    func hostManagedRunNeverDwells() async throws {
        let action = StatefulSuspension(.cooperative)
        let sleeper = StatefulSuspension(.passThrough)
        let runner = Self.runner(sleeper: sleeper)

        #expect(Self.tap(runner, host: .idle, action: action))
        try #require(await action.waitForArrivals(1), "action 没被调起")
        #expect(!Self.tap(runner, host: .idle, action: action), "托管模式下执行期间再点被准入了")
        action.release()
        await runner.task?.value
        #expect(runner.core.display(host: nil) == .idle, "托管模式下组件写了自己那份视觉态")
        #expect(sleeper.arrivals == 0, "托管模式下进入了停留 \(sleeper.arrivals) 次")
    }

    // 单测进程里合成点击激活不了 SwiftUI `Button`、无障碍树里也找不到它，视图到编排器的两处接线只能在源码层核。
    @Test("视图接线：Button 的 action 与 onDisappear 各自转交编排器")
    func viewForwardsToRunner() {
        let url = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
            .appendingPathComponent("Components/Button/StatefulButton.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record(Comment(rawValue: "读不到 StatefulButton 源码：\(url.path)"))
            return
        }
        let required = [
            "@State private var runner = StatefulButtonRunner()",
            """
                    return Button {
                        self.runner.tap(
                            host: self.hostState,
                            successDwell: self.successDwell,
                            failureDwell: self.failureDwell,
                            action: self.action
                        )
                    } label: {
            """,
            """
                    .onDisappear {
                        self.runner.disappear(host: self.hostState)
                    }
            """,
        ]
        let missing = required.filter { !source.contains($0) }
        #expect(
            missing.isEmpty,
            "视图接线缺 \(missing.count) 处，期望 0：\(missing) —— 缺第 2 条 ⇒ 点击不进编排器；缺第 3 条 ⇒ 离屏不取消、不作废"
        )
    }
}

// MARK: - 可控挂起 / Controlled suspension

// 一次挂起一个调用方，由测试显式放行。
nonisolated final class StatefulSuspension: Sendable {
    enum Mode: Sendable {
        // 取消时立刻以 CancellationError 结束。
        case cooperative
        // 只记下「收到过取消」、继续挂着，模拟不响应取消的 action。
        case ignoresCancellation
        // 只记到达、立即返回：用在「不应进入停留」的场景，变异让它进了停留时判红而不是挂死。
        case passThrough
    }

    private struct State {
        var pending: CheckedContinuation<Void, any Error>?
        var arrivals = 0
        var cancelled = false
        var durations: [Duration] = []
        var waiters: [(id: UUID, count: Int, continuation: CheckedContinuation<Bool, Never>)] = []

        mutating func arrive(_ duration: Duration?) -> [CheckedContinuation<Bool, Never>] {
            self.arrivals += 1
            if let duration { self.durations.append(duration) }
            let ready = self.waiters.filter { $0.count <= self.arrivals }
            self.waiters.removeAll { $0.count <= self.arrivals }
            return ready.map(\.continuation)
        }
    }

    private let state = Mutex(State())
    private let mode: Mode

    init(_ mode: Mode) {
        self.mode = mode
    }

    var arrivals: Int { self.state.withLock { $0.arrivals } }
    var cancelled: Bool { self.state.withLock { $0.cancelled } }
    var durations: [Duration] { self.state.withLock { $0.durations } }

    func suspend(recording duration: Duration? = nil) async throws {
        if self.mode == .passThrough {
            self.state.withLock { $0.arrive(duration) }.forEach { $0.resume(returning: true) }
            return
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let (cancelNow, ready) = self.state.withLock { state -> (Bool, [CheckedContinuation<Bool, Never>]) in
                    let ready = state.arrive(duration)
                    if Task.isCancelled {
                        state.cancelled = true
                        if self.mode == .cooperative { return (true, ready) }
                    }
                    state.pending = continuation
                    return (false, ready)
                }
                ready.forEach { $0.resume(returning: true) }
                if cancelNow { continuation.resume(throwing: CancellationError()) }
            }
        } onCancel: {
            let continuation = self.state.withLock { state -> CheckedContinuation<Void, any Error>? in
                state.cancelled = true
                guard self.mode == .cooperative else { return nil }
                defer { state.pending = nil }
                return state.pending
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    func release(throwing error: (any Error)? = nil) {
        let continuation = self.state.withLock { state in
            defer { state.pending = nil }
            return state.pending
        }
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    func waitForArrivals(_ count: Int) async -> Bool {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let immediate = self.state.withLock { state -> Bool? in
                    if state.arrivals >= count { return true }
                    if Task.isCancelled { return false }
                    state.waiters.append((id, count, continuation))
                    return nil
                }
                if let immediate { continuation.resume(returning: immediate) }
            }
        } onCancel: {
            let waiter = self.state.withLock { state in
                defer { state.waiters.removeAll { $0.id == id } }
                return state.waiters.first { $0.id == id }
            }
            waiter?.continuation.resume(returning: false)
        }
    }
}
