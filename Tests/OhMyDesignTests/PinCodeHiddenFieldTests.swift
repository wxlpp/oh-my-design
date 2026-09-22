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
    #endif
}
