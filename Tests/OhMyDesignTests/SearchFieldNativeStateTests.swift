import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
private final class DisabledModel {
    var disabled = false
}

private struct DisabledHost: View {
    let model: DisabledModel

    var body: some View {
        SearchField(text: .constant("")).disabled(self.model.disabled)
    }
}

// MARK: - 原生控件状态 / Native control state

@Suite("SearchField 原生控件：isEnabled 透传与回车键")
@MainActor
struct SearchFieldNativeStateTests {
    #if canImport(UIKit)
    private typealias NativeField = UISearchTextField
    #else
    private typealias NativeField = NSSearchField
    #endif

    private func nativeField(in root: some View) throws -> (NativeField, () -> Void) {
        #if canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        let controller = UIHostingController(rootView: AnyView(root))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        for _ in 0..<5 {
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        let field = try #require(Self.first(NativeField.self, in: controller.view), "视图树里没有 UISearchTextField")
        return (field, { window.isHidden = true })
        #else
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 390, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let host = NSHostingView(rootView: AnyView(root))
        host.frame = window.contentRect(forFrameRect: window.frame)
        window.contentView = host
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        let field = try #require(Self.first(NativeField.self, in: host), "视图树里没有 NSSearchField")
        return (field, { window.orderOut(nil) })
        #endif
    }

    #if canImport(UIKit)
    private static func first<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = Self.first(type, in: subview) { return match }
        }
        return nil
    }
    #else
    private static func first<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = Self.first(type, in: subview) { return match }
        }
        return nil
    }
    #endif

    @Test("默认启用：底层原生搜索框 isEnabled 为 true")
    func enabledByDefault() throws {
        let (field, tearDown) = try self.nativeField(in: SearchField(text: .constant("")))
        defer { tearDown() }
        #expect(field.isEnabled)
    }

    @Test(".disabled(true) 透传到底层原生搜索框：isEnabled 为 false")
    func disabledPropagatesToNativeField() throws {
        let (field, tearDown) = try self.nativeField(in: SearchField(text: .constant("")).disabled(true))
        defer { tearDown() }
        #expect(field.isEnabled == false)
    }

    @Test("运行期切换 disabled ↔ enabled：底层 isEnabled 跟随")
    func togglingDisabledAtRuntimeFollows() throws {
        let model = DisabledModel()
        let (field, tearDown) = try self.nativeField(in: DisabledHost(model: model))
        defer { tearDown() }
        #expect(field.isEnabled)
        model.disabled = true
        self.pump()
        #expect(field.isEnabled == false)
        model.disabled = false
        self.pump()
        #expect(field.isEnabled)
    }

    private func pump() {
        for _ in 0..<5 { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    }

    #if canImport(UIKit)
    @Test("iOS 回车键为「搜索」：returnKeyType == .search")
    func returnKeyIsSearch() throws {
        let (field, tearDown) = try self.nativeField(in: SearchField(text: .constant("")))
        defer { tearDown() }
        #expect(field.returnKeyType == .search)
    }
    #endif
}
