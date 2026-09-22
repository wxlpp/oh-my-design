import Foundation
import Testing
@testable import OhMyDesign

@MainActor
final class ToastEventRecorder {
    var events: [String] = []
}

@Suite("ToastAction concurrency")
struct ToastActionConcurrencyTests {
    nonisolated static func makeItem(recorder: ToastEventRecorder) -> (item: ToastItem, onMainThread: Bool) {
        let item = ToastItem(
            title: "Archived",
            description: "3 conversations",
            level: .neutral,
            duration: .persistent,
            action: ToastAction("Undo") {
                MainActor.assertIsolated()
                recorder.events.append("undo")
            }
        )
        return (item, Thread.isMainThread)
    }

    @Test("后台构造 ToastItem（含动作），主线程展示与执行")
    func constructedOffMainShownAndPerformedOnMain() async {
        let recorder = await ToastEventRecorder()
        let built = await Task.detached { Self.makeItem(recorder: recorder) }.value
        #expect(built.onMainThread == false, "构造必须真的发生在主线程之外，否则本条验不到跨 actor 传递")
        let item = built.item
        #expect(item.action?.label == "Undo")

        await MainActor.run {
            let host = ToastHost(clock: ManualToastClock())
            host.show(item)
            #expect(host.queue.first?.id == item.id)
            host.performAction(of: item.id)
            #expect(recorder.events == ["undo"])
            #expect(host.isDismissing == true)
        }
    }

    @Test("ToastAction.perform 在主 actor 上执行")
    @MainActor
    func performRunsOnMainActor() {
        let recorder = ToastEventRecorder()
        let action = ToastAction("Retry") {
            MainActor.assertIsolated()
            recorder.events.append("retry")
        }
        action.perform()
        #expect(recorder.events == ["retry"])
    }
}
