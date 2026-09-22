import Foundation

// MARK: - ToastClock

protocol ToastTimer: AnyObject {
    func cancel()
}

protocol ToastClock: AnyObject {
    var now: TimeInterval { get }
    func schedule(after delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> any ToastTimer
}

// MARK: - SystemToastClock

final class SystemToastClock: ToastClock {
    private let origin = ContinuousClock.now

    var now: TimeInterval {
        let elapsed = ContinuousClock.now - self.origin
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    func schedule(after delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> any ToastTimer {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, delay)))
            guard !Task.isCancelled else { return }
            fire()
        }
        return TaskToastTimer(task: task)
    }
}

private final class TaskToastTimer: ToastTimer {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        self.task.cancel()
    }
}
