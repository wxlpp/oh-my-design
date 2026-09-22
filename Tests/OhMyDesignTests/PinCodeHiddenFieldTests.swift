import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
private typealias HiddenField = UITextField
#else
import AppKit
private typealias HiddenField = NSTextField
#endif

private struct EditablePinCode: View {
    @State var code: String
    let sink: (String) -> Void

    var body: some View {
        PinCode(value: self.$code, length: 6)
            .onChange(of: self.code) { _, newValue in self.sink(newValue) }
    }
}

@Suite("PinCode 隐藏输入框：不留残影，输入行为不变（托管窗口真实渲染）")
@MainActor
struct PinCodeHiddenFieldTests {
    @Test("隐藏输入框的文字与光标取透明色（light / dark）", arguments: [ColorScheme.light, .dark])
    func hiddenFieldDrawsNothing(_ scheme: ColorScheme) throws {
        let window = HostedWindow(PinCode(value: .constant("12"), length: 6), size: CGSize(width: 360, height: 120), scheme: scheme)
        defer { window.close() }
        let field = try #require(window.first(HiddenField.self), "托管树里找不到隐藏输入框")
        #if canImport(UIKit)
        #expect(field.text == "12")
        #expect(field.textColor.map { $0.cgColor.alpha == 0 } == true, "文字色不透明：\(String(describing: field.textColor))")
        #expect(field.tintColor.cgColor.alpha == 0, "光标色不透明：\(String(describing: field.tintColor))")
        #else
        #expect(field.stringValue == "12")
        #expect(field.textColor.map { $0.alphaComponent == 0 } == true, "文字色不透明：\(String(describing: field.textColor))")
        #endif
    }

    @Test("有值时隐藏输入框对位图零贡献：藏掉它前后逐像素相同（light / dark）", arguments: [ColorScheme.light, .dark])
    func hiddenFieldHasNoPixelFootprint(_ scheme: ColorScheme) throws {
        let window = HostedWindow(PinCode(value: .constant("12"), length: 6), size: CGSize(width: 360, height: 120), scheme: scheme)
        defer { window.close() }
        let field = try #require(window.first(HiddenField.self))
        let shown = window.pixels()
        field.isHidden = true
        let hidden = window.pixels()
        #if os(macOS)
        field.isHidden = false
        field.alphaValue = 0
        window.settle()
        expectBitmapsEqual(hidden.bytes, window.pixels().bytes, "\(scheme)：isHidden 与 alphaValue = 0 两种藏法渲染不同，编辑态判据的前提不成立")
        #endif
        expectBitmapsEqual(shown.bytes, hidden.bytes, "\(scheme)：隐藏输入框在画面上留下了像素")
    }

    #if canImport(UIKit)
    @Test("键盘与 OTP 自动填充配置不变，隐藏输入框仍可成为第一响应者")
    func keyboardConfigurationUnchanged() throws {
        let window = HostedWindow(PinCode(value: .constant("12"), length: 6), size: CGSize(width: 360, height: 120), scheme: .light)
        defer { window.close() }
        let field = try #require(window.first(UITextField.self))
        #expect(field.keyboardType == .numberPad)
        #expect(field.textContentType == .oneTimeCode)
        #expect(field.autocorrectionType == .no)
        #expect(field.becomeFirstResponder())
        field.resignFirstResponder()
    }

    @Test("iOS 获焦编辑（光标 / 全选）时，隐藏输入框对位图零贡献（light / dark）", arguments: [ColorScheme.light, .dark])
    func editingLeavesNoGhost(_ scheme: ColorScheme) throws {
        let window = HostedWindow(EditablePinCode(code: "1234") { _ in }, size: CGSize(width: 360, height: 120), scheme: scheme)
        defer { window.close() }
        let field = try #require(window.first(UITextField.self))
        let host = try #require(field.superview)
        #expect(field.becomeFirstResponder())
        window.settle()
        for select in [false, true] {
            host.alpha = 0.01
            if select { field.selectAll(nil) }
            window.settle()
            let editing = window.pixels()
            host.alpha = 0
            window.settle()
            #expect(field.isFirstResponder, "藏掉输入框后退出了编辑态，两次渲染不可比")
            expectBitmapsEqual(editing.bytes, window.pixels().bytes, "\(scheme) 全选=\(select)：编辑态的隐藏输入框在画面上留下了像素")
        }
        field.resignFirstResponder()
    }
    #endif

    #if os(macOS)
    private func editing(_ initial: String, scheme: ColorScheme = .light, _ body: (HostedWindow, NSTextField, NSTextView, () -> String) throws -> Void) throws {
        var latest = initial
        let window = HostedWindow(EditablePinCode(code: initial) { latest = $0 }, size: CGSize(width: 360, height: 120), scheme: scheme)
        defer { window.close() }
        let field = try #require(window.first(NSTextField.self))
        #expect(window.root.window?.makeFirstResponder(field) == true)
        window.settle()
        let editor = try #require(field.currentEditor() as? NSTextView, "隐藏输入框没有进入编辑态")
        try body(window, field, editor, { latest })
    }

    @Test("macOS 获焦编辑：在末尾键入经隐藏输入框写回绑定，并按数字过滤")
    func typingAtEndWritesBinding() throws {
        try self.editing("12") { window, _, editor, value in
            editor.setSelectedRange(NSRange(location: 2, length: 0))
            editor.insertText("3a4", replacementRange: NSRange(location: NSNotFound, length: 0))
            window.settle()
            #expect(value() == "1234")
        }
    }

    @Test("macOS 获焦编辑：选区替换（全选与部分选区）写回绑定")
    func selectionReplacementWritesBinding() throws {
        try self.editing("1234") { window, _, editor, value in
            editor.setSelectedRange(NSRange(location: 1, length: 2))
            editor.insertText("9", replacementRange: NSRange(location: NSNotFound, length: 0))
            window.settle()
            #expect(value() == "194")
            editor.selectAll(nil)
            editor.insertText("56", replacementRange: NSRange(location: NSNotFound, length: 0))
            window.settle()
            #expect(value() == "56")
        }
    }

    @Test("macOS 获焦编辑、光标在末尾时，隐藏输入框（文字与光标）对位图零贡献（light / dark）", arguments: [ColorScheme.light, .dark])
    func editingCaretLeavesNoGhost(_ scheme: ColorScheme) throws {
        try self.editing("1234", scheme: scheme) { window, field, editor, _ in
            editor.setSelectedRange(NSRange(location: 4, length: 0))
            window.settle()
            let editing = window.pixels()
            field.alphaValue = 0
            window.settle()
            #expect(field.currentEditor() != nil, "藏掉输入框后退出了编辑态，两次渲染不可比")
            expectBitmapsEqual(editing.bytes, window.pixels().bytes, "\(scheme)：编辑态的隐藏输入框在画面上留下了像素")
        }
    }

    @Test("macOS 获焦编辑且全选时，隐藏输入框（含系统选区高亮）对位图零贡献（light / dark）", arguments: [ColorScheme.light, .dark])
    func editingWithSelectionLeavesNoVisibleGhost(_ scheme: ColorScheme) throws {
        try self.editing("1234", scheme: scheme) { window, field, editor, _ in
            editor.selectAll(nil)
            window.settle()
            let editing = window.pixels()
            field.alphaValue = 0
            window.settle()
            #expect(field.currentEditor() != nil, "藏掉输入框后退出了编辑态，两次渲染不可比")
            expectBitmapsEqual(editing.bytes, window.pixels().bytes, "\(scheme)：编辑态的选区高亮在画面上留下了像素")
        }
    }
    #endif
}
