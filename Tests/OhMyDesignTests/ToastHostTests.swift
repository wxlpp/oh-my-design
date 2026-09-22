import Testing
import Foundation
@testable import OhMyDesign

// MARK: - ManualToastClock

@MainActor
final class ManualToastClock: ToastClock {
    final class Timer: ToastTimer {
        let deadline: TimeInterval
        let fire: @MainActor () -> Void
        var isCancelled = false
        var hasFired = false

        init(deadline: TimeInterval, fire: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.fire = fire
        }

        func cancel() {
            self.isCancelled = true
        }
    }

    private(set) var now: TimeInterval = 0
    private var timers: [Timer] = []

    var pendingCount: Int {
        self.timers.filter { !$0.isCancelled && !$0.hasFired }.count
    }

    func schedule(after delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> any ToastTimer {
        let timer = Timer(deadline: self.now + max(0, delay), fire: fire)
        self.timers.append(timer)
        return timer
    }

    func advance(by delta: TimeInterval) {
        let target = self.now + delta
        while let next = self.timers
            .filter({ !$0.isCancelled && !$0.hasFired && $0.deadline <= target })
            .min(by: { $0.deadline < $1.deadline }) {
            self.now = next.deadline
            next.hasFired = true
            next.fire()
        }
        self.now = target
    }
}

// MARK: - ToastHost state machine tests

@Suite("ToastHost queue state machine")
@MainActor
struct ToastHostTests {
    private let exit = ToastDefaults.dismissAnimationDuration

    private func makeHost() -> (ToastHost, ManualToastClock) {
        let clock = ManualToastClock()
        return (ToastHost(clock: clock), clock)
    }

    // MARK: queue

    @Test("空队列 show(...) 立即开始显示")
    func showOnEmptyStartsImmediately() {
        let (host, clock) = self.makeHost()
        host.show("hi", description: "details")
        #expect(host.queue.count == 1)
        #expect(host.queue.first?.title == "hi")
        #expect(host.queue.first?.description == "details")
        #expect(host.isDismissing == false)
        #expect(clock.pendingCount == 1, "显示计时应已启动")
    }

    @Test("显示中 show(...) append 到队尾，不打断当前")
    func showWhileDisplayingAppends() {
        let (host, _) = self.makeHost()
        host.show("first", duration: .seconds(5))
        host.show("second")
        host.show("third")
        #expect(host.queue.map(\.title) == ["first", "second", "third"])
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 排队中的 item 直接移除")
    func dismissQueuedRemovesWithoutAffectingCurrent() {
        let (host, _) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(5))
        let b = ToastItem(title: "b", duration: .seconds(5))
        let c = ToastItem(title: "c", duration: .seconds(5))
        host.show(a)
        host.show(b)
        host.show(c)
        host.dismiss(b.id)
        #expect(host.queue.map(\.id) == [a.id, c.id])
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 不存在的 id 是 no-op")
    func dismissUnknownIdIsNoop() {
        let (host, _) = self.makeHost()
        host.show("only", duration: .seconds(5))
        host.dismiss(UUID())
        #expect(host.queue.count == 1)
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 当前项进入 dismissing，退场等待后出队")
    func dismissCurrentEntersDismissingState() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(5))
        host.show(a)
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        #expect(host.queue.first?.id == a.id, "退场动画期间当前项仍在队首")
        clock.advance(by: self.exit)
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 重复触发不 double-fire")
    func repeatedDismissIsIdempotent() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(5))
        let b = ToastItem(title: "b", duration: .seconds(5))
        host.show(a)
        host.show(b)
        host.dismiss(a.id)
        host.dismiss(a.id)
        host.dismiss(a.id)
        clock.advance(by: self.exit)
        #expect(host.queue.map(\.id) == [b.id], "重复 dismiss 不得把下一条也带走")
        #expect(host.isDismissing == false)
    }

    // MARK: timing

    @Test("到时自动 dismiss 并 advance；时长从开始显示起算")
    func durationCountsFromStartOfDisplay() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(1))
        let b = ToastItem(title: "b", duration: .seconds(2))
        host.show(a)
        clock.advance(by: 0.5)
        host.show(b)
        clock.advance(by: 0.49)
        #expect(host.queue.first?.id == a.id)
        #expect(host.isDismissing == false)
        clock.advance(by: 0.01)
        #expect(host.isDismissing == true)
        clock.advance(by: self.exit)
        #expect(host.queue.first?.id == b.id)
        #expect(host.isDismissing == false)
        clock.advance(by: 1.99)
        #expect(host.isDismissing == false, "b 在排队时不得计时")
        clock.advance(by: 0.01 + self.exit)
        #expect(host.queue.isEmpty)
    }

    @Test("seconds 非正值 / NaN 按缺省时长处理", arguments: [0, -1, TimeInterval.nan])
    func nonPositiveSecondsFallBackToDefault(seconds: TimeInterval) {
        let (host, clock) = self.makeHost()
        host.show("x", duration: .seconds(seconds))
        clock.advance(by: ToastDefaults.defaultSeconds - 0.01)
        #expect(host.isDismissing == false)
        clock.advance(by: 0.01)
        #expect(host.isDismissing == true)
    }

    @Test("ToastDefaults.duration 是 3 秒")
    func defaultDurationIsThreeSeconds() {
        #expect(ToastDefaults.duration == .seconds(3))
        #expect(ToastDuration.seconds(0).resolvedSeconds == 3)
        #expect(ToastDuration.seconds(1.5).resolvedSeconds == 1.5)
        #expect(ToastDuration.persistent.resolvedSeconds == nil)
        #expect(ToastDuration.seconds(.infinity).resolvedSeconds == nil)
    }

    // MARK: pause / resume

    @Test("按住暂停，松手按剩余时长恢复")
    func pressPausesAndResumesWithRemaining() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(3))
        host.show(a)
        clock.advance(by: 1)
        host.pause(.press)
        clock.advance(by: 10)
        #expect(host.isDismissing == false, "暂停期间不得到时")
        host.resume(.press)
        clock.advance(by: 1.99)
        #expect(host.isDismissing == false, "恢复后应只剩 2 秒")
        clock.advance(by: 0.01)
        #expect(host.isDismissing == true)
    }

    @Test("拖拽与按住重叠：两者都释放才恢复")
    func overlappingPauseReasonsResumeOnlyWhenAllReleased() {
        let (host, clock) = self.makeHost()
        host.show("a", duration: .seconds(2))
        clock.advance(by: 0.5)
        host.pause(.press)
        host.pause(.drag)
        host.resume(.press)
        clock.advance(by: 5)
        #expect(host.isDismissing == false, "拖拽仍在进行，不得恢复计时")
        host.resume(.drag)
        clock.advance(by: 1.49)
        #expect(host.isDismissing == false)
        clock.advance(by: 0.01)
        #expect(host.isDismissing == true)
    }

    @Test("手势取消（未配对的 resume / 重复 pause）同样恢复，且不双计")
    func cancelledGestureResumes() {
        let (host, clock) = self.makeHost()
        host.show("a", duration: .seconds(2))
        host.pause(.drag)
        host.pause(.drag)
        clock.advance(by: 3)
        host.resume(.drag)
        host.resume(.drag)
        #expect(clock.pendingCount == 1, "重复 resume 不得排出第二个显示计时")
        clock.advance(by: 2)
        #expect(host.isDismissing == true)
    }

    @Test("暂停状态在切换到下一条时清空")
    func pauseDoesNotLeakIntoNextItem() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(1))
        host.show(a)
        host.show("b", duration: .seconds(1))
        host.pause(.press)
        host.dismiss(a.id)
        clock.advance(by: self.exit)
        #expect(host.queue.first?.title == "b")
        clock.advance(by: 1)
        #expect(host.isDismissing == true, "上一条遗留的暂停原因不得冻结下一条")
    }

    @Test("退场中 pause / resume 是 no-op")
    func pauseWhileDismissingIsNoop() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(1))
        host.show(a)
        host.dismiss(a.id)
        host.pause(.press)
        host.resume(.press)
        clock.advance(by: self.exit)
        #expect(host.queue.isEmpty)
        #expect(clock.pendingCount == 0)
    }

    // MARK: persistent

    @Test(".persistent 不自动关闭，并在关闭前阻塞队列")
    func persistentBlocksQueueUntilDismissed() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .persistent)
        host.show(a)
        host.show("b", duration: .seconds(1))
        clock.advance(by: 3600)
        #expect(host.queue.first?.id == a.id)
        #expect(host.isDismissing == false)
        #expect(clock.pendingCount == 0, ".persistent 不得排显示计时")
        host.dismiss(a.id)
        clock.advance(by: self.exit)
        #expect(host.queue.first?.title == "b")
        clock.advance(by: 1)
        #expect(host.isDismissing == true)
    }

    // MARK: dismissAll

    @Test("dismissAll() 清空当前与排队项")
    func dismissAllClearsCurrentAndQueued() {
        let (host, clock) = self.makeHost()
        host.show("a")
        host.show("b")
        host.show("c")
        host.dismissAll()
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)
        #expect(clock.pendingCount == 0)
    }

    @Test("dismissAll() 在退场动画中调用也成立，之后立即 show 正常显示")
    func dismissAllDuringExitThenShow() {
        let (host, clock) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(5))
        host.show(a)
        host.show("queued")
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        host.dismissAll()
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)

        let fresh = ToastItem(title: "fresh", duration: .seconds(1))
        host.show(fresh)
        #expect(host.queue.map(\.id) == [fresh.id])
        clock.advance(by: self.exit)
        #expect(host.queue.map(\.id) == [fresh.id], "旧的退场等待不得落到新项上")
        #expect(host.isDismissing == false)
        clock.advance(by: 1 - self.exit)
        #expect(host.isDismissing == true, "新项必须按自己的时长自动关闭")
        clock.advance(by: self.exit)
        #expect(host.queue.isEmpty)
    }

    @Test("dismissAll() 后 persistent 与暂停状态一并清空")
    func dismissAllResetsPause() {
        let (host, clock) = self.makeHost()
        host.show("p", duration: .persistent)
        host.pause(.press)
        host.dismissAll()
        host.show("n", duration: .seconds(1))
        clock.advance(by: 1)
        #expect(host.isDismissing == true)
    }

    @Test("显示计时与退场等待是两个独立字段")
    func displayAndExitTimersAreSeparate() {
        let (host, _) = self.makeHost()
        let a = ToastItem(title: "a", duration: .seconds(5))
        host.show(a)
        #expect(host.hasDisplayTimer == true)
        #expect(host.hasExitTimer == false)
        host.dismiss(a.id)
        #expect(host.hasDisplayTimer == false)
        #expect(host.hasExitTimer == true)
    }

    // MARK: action

    @Test("performAction：先执行动作再关闭")
    func performActionRunsHandlerThenDismisses() {
        let (host, clock) = self.makeHost()
        let log = ToastEventRecorder()
        let item = ToastItem(title: "Deleted", action: ToastAction("Undo") { log.events.append("undo") })
        host.show(item)
        host.performAction(of: item.id)
        #expect(log.events == ["undo"])
        #expect(host.isDismissing == true)
        clock.advance(by: self.exit)
        #expect(host.queue.isEmpty)
    }

    @Test("performAction：动作内 dismissAll 后以同一 ID 重新 show，新 toast 不被关闭")
    func actionReshowingSameIdIsNotDismissed() {
        let (host, clock) = self.makeHost()
        let id = UUID()
        let hostRef = host
        let item = ToastItem(id: id, title: "Deleted", action: ToastAction("Undo") {
            hostRef.dismissAll()
            hostRef.show(ToastItem(id: id, title: "Restored", duration: .seconds(2)))
        })
        host.show(item)
        host.performAction(of: id)
        #expect(host.queue.map(\.title) == ["Restored"])
        #expect(host.isDismissing == false, "同 ID 的新一轮展示不得被旧动作的收尾关闭")
        clock.advance(by: 2)
        #expect(host.isDismissing == true, "新 toast 按自己的时长关闭")
    }

    @Test("performAction：动作内换一个 ID 重新 show，新 toast 不被关闭")
    func actionShowingDifferentIdIsNotDismissed() {
        let (host, _) = self.makeHost()
        let hostRef = host
        let item = ToastItem(title: "Deleted", action: ToastAction("Undo") {
            hostRef.dismissAll()
            hostRef.show("Restored")
        })
        host.show(item)
        host.performAction(of: item.id)
        #expect(host.queue.map(\.title) == ["Restored"])
        #expect(host.isDismissing == false)
    }

    @Test("performAction：动作只追加新项时，当前项照常关闭")
    func actionAppendingKeepsDismissingCurrent() {
        let (host, clock) = self.makeHost()
        let hostRef = host
        let item = ToastItem(title: "Deleted", action: ToastAction("Undo") {
            hostRef.show("Restored")
        })
        host.show(item)
        host.performAction(of: item.id)
        #expect(host.isDismissing == true)
        clock.advance(by: self.exit)
        #expect(host.queue.map(\.title) == ["Restored"])
    }

    @Test("performAction：非当前项 / 无动作 / 退场中 均不执行")
    func performActionGuards() {
        let (host, _) = self.makeHost()
        let log = ToastEventRecorder()
        let a = ToastItem(title: "a", action: ToastAction("Go") { log.events.append("a") })
        let b = ToastItem(title: "b", action: ToastAction("Go") { log.events.append("b") })
        let c = ToastItem(title: "c")
        host.show(a)
        host.show(b)
        host.show(c)
        host.performAction(of: b.id)
        host.performAction(of: c.id)
        #expect(log.events.isEmpty)
        host.dismiss(a.id)
        host.performAction(of: a.id)
        #expect(log.events.isEmpty, "退场中的 toast 不得再触发动作")
    }
}

// MARK: - SystemToastClock

@MainActor
final class ToastDeadlineRecorder {
    var deadline: ContinuousClock.Instant?
}

@Suite("SystemToastClock")
@MainActor
struct SystemToastClockTests {
    @Test("真实时钟：调度的回调在主 actor 上触发，取消的不触发")
    func firesOnMainActorAndHonoursCancel() async {
        let clock = SystemToastClock()
        let fired = ToastEventRecorder()
        let cancelled = clock.schedule(after: 0.01) { fired.events.append("cancelled") }
        cancelled.cancel()
        await withCheckedContinuation { continuation in
            _ = clock.schedule(after: 0.02) {
                MainActor.assertIsolated()
                fired.events.append("kept")
                continuation.resume()
            }
        }
        #expect(fired.events == ["kept"])
        #expect(clock.now > 0)
    }

    @Test("真实时钟：截止时刻在 schedule 时确定，Task 延迟启动不拉长时长")
    func deadlineIsFixedAtScheduleTime() async {
        let recorded = ToastDeadlineRecorder()
        let clock = SystemToastClock(sleeper: { deadline in recorded.deadline = deadline })
        let before = ContinuousClock.now
        await withCheckedContinuation { continuation in
            _ = clock.schedule(after: 0.3) { continuation.resume() }
            Self.blockMainThread(for: 0.2)
        }
        guard let deadline = recorded.deadline else {
            Issue.record("sleeper 没被调用 —— 截止时刻无从核对")
            return
        }
        let offset = deadline - before
        #expect(offset >= .seconds(0.3), "截止时刻早于排程时刻 + 时长：\(offset)")
        #expect(offset < .seconds(0.45), "截止时刻随 Task 启动推迟了（主线程占用 0.2s）：\(offset)")
    }

    private static func blockMainThread(for seconds: TimeInterval) {
        usleep(useconds_t(seconds * 1_000_000))
    }
}
