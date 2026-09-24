import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - 播报规则 / Announcement rule

@Suite("FormField 播报：仅 valid→invalid 或错误文本变化时播报一次")
struct FieldValidationAnnouncerTests {
    private let en = Locale(identifier: "en_US")

    @Test("首次渲染即 invalid 不播报")
    func firstRenderInvalidIsSilent() {
        var announcer = FieldValidationAnnouncer()
        #expect(announcer.observe(.invalid("Required"), locale: self.en) == nil)
    }

    @Test("值未变的重建不播报")
    func unchangedRebuildIsSilent() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.valid, locale: self.en)
        #expect(announcer.observe(.invalid("Bad"), locale: self.en) == "Bad")
        #expect(announcer.observe(.invalid("Bad"), locale: self.en) == nil)
        #expect(announcer.observe(.invalid("Bad"), locale: self.en) == nil)
    }

    @Test("valid → invalid 播报错误原因一次")
    func validToInvalidAnnounces() {
        var announcer = FieldValidationAnnouncer()
        #expect(announcer.observe(.valid, locale: self.en) == nil)
        #expect(announcer.observe(.invalid("Bad"), locale: self.en) == "Bad")
    }

    @Test("invalid 的错误文本变化时播报新文本")
    func reasonChangeAnnounces() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.invalid("A"), locale: self.en)
        #expect(announcer.observe(.invalid("B"), locale: self.en) == "B")
    }

    @Test("转回 valid 或 valid 重建都不播报")
    func becomingValidIsSilent() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.valid, locale: self.en)
        _ = announcer.observe(.invalid("A"), locale: self.en)
        #expect(announcer.observe(.valid, locale: self.en) == nil)
        #expect(announcer.observe(.valid, locale: self.en) == nil)
        #expect(announcer.observe(.invalid("A"), locale: self.en) == "A")
    }

    @Test("一条完整序列的播报次数")
    func sequenceCount() {
        var announcer = FieldValidationAnnouncer()
        let sequence: [FieldValidation] = [
            .invalid("A"), .invalid("A"), .valid, .valid, .invalid("A"), .invalid("B"), .invalid("B"),
        ]
        let announced = sequence.compactMap { announcer.observe($0, locale: self.en) }
        #expect(announced == ["A", "B"])
    }

    @Test("播报按环境 locale 解析：同一错误原因在 en_US / de_DE 下得到不同文本")
    func resolvesInEnvironmentLocale() {
        let reason: LocalizedStringResource = "Limit \(1234.5)"
        let english = FieldValidationAnnouncer.resolve(reason, locale: self.en)
        let german = FieldValidationAnnouncer.resolve(reason, locale: Locale(identifier: "de_DE"))
        #expect(english.contains("1,234.5"), "\(english)")
        #expect(german.contains("1.234,5"), "\(german)")

        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.valid, locale: Locale(identifier: "de_DE"))
        #expect(announcer.observe(.invalid(reason), locale: Locale(identifier: "de_DE")) == german)
    }
}

// MARK: - 外观优先级 / Appearance priority

@Suite("FormField 外观：disabled > invalid > focused")
struct FieldAppearanceTests {
    private let invalid = FieldValidation.invalid("Bad")

    @Test("disabled 压过 invalid 与 focused")
    func disabledWins() {
        #expect(FieldAppearance.resolve(isEnabled: false, validation: self.invalid, isFocused: true) == .disabled)
        #expect(FieldAppearance.resolve(isEnabled: false, validation: .valid, isFocused: false) == .disabled)
    }

    @Test("invalid 压过 focused")
    func invalidBeatsFocus() {
        #expect(FieldAppearance.resolve(isEnabled: true, validation: self.invalid, isFocused: true) == .invalid)
    }

    @Test("valid 时按焦点区分 focused / normal")
    func focusWhenValid() {
        #expect(FieldAppearance.resolve(isEnabled: true, validation: .valid, isFocused: true) == .focused)
        #expect(FieldAppearance.resolve(isEnabled: true, validation: .valid, isFocused: false) == .normal)
    }

    @Test("invalid 时 label 与错误行取 danger；disabled 时二者退到 contentDisabled")
    func colorMapping() {
        #expect(FieldAppearance.invalid.labelColor == Color.statusDangerForeground)
        #expect(FieldAppearance.invalid.messageColor == Color.statusDangerForeground)
        #expect(FieldAppearance.normal.labelColor == Color.contentPrimary)
        #expect(FieldAppearance.disabled.labelColor == Color.contentDisabled)
        #expect(FieldAppearance.disabled.messageColor == Color.contentDisabled)
        #expect(FieldAppearance.normal.requiredMarkColor == Color.contentSecondary)
        #expect(FieldAppearance.invalid.requiredMarkColor == Color.statusDangerForeground)
        #expect(FieldAppearance.disabled.requiredMarkColor == Color.contentDisabled)
    }
}

// MARK: - 无障碍文本 / Accessibility text

@Suite("FormField 无障碍文本：hint 拼装与必填 label")
struct FormFieldAccessibilityTextTests {
    @Test("hint：错误原因在前、description 在后")
    func hintOrder() {
        let parts = FieldAccessibilityHint.parts(
            validation: .invalid("E"),
            description: Text(verbatim: "D")
        )
        #expect(parts == [Text(LocalizedStringResource("E")), Text(verbatim: "D")])
    }

    @Test("hint：无错误无 description 时为 nil，单项时原样")
    func hintEmptyAndSingle() {
        #expect(FieldAccessibilityHint.text(validation: .valid, description: nil) == nil)
        #expect(FieldAccessibilityHint.text(validation: .valid, description: Text(verbatim: "D")) == Text(verbatim: "D"))
        #expect(
            FieldAccessibilityHint.text(validation: .invalid("E"), description: nil)
                == Text(LocalizedStringResource("E"))
        )
    }

    @Test("必填 label 追加文案，选填原样")
    func requiredLabel() {
        let label = Text(verbatim: "Email")
        #expect(FormFieldAccessibility.label(label, requirement: .optional) == label)
        #expect(FormFieldAccessibility.label(label, requirement: .required) != label)
        let sentinel = "__missing__"
        let format = Bundle.module.localizedString(forKey: "%@, required", value: sentinel, table: nil)
        #expect(format != sentinel, "Localizable.strings 里没有 \"%@, required\" 键")
        #expect(String(format: format, "Email") == "Email, required")
    }
}

// MARK: - 环境值 / Environment

@Suite("字段校验环境值：modifier 写入，嵌套最近一层生效")
@MainActor
struct FieldEnvironmentTests {
    private final class Probe {
        var validation: FieldValidation?
        var requirement: FieldRequirement?
    }

    private struct Reader: View {
        let probe: Probe
        @Environment(\.fieldValidation) private var validation
        @Environment(\.fieldRequirement) private var requirement

        var body: some View {
            self.probe.validation = self.validation
            self.probe.requirement = self.requirement
            return Color.clear.frame(width: 1, height: 1)
        }
    }

    private func render(_ view: some View) {
        let renderer = ImageRenderer(content: view)
        _ = renderer.cgImage
    }

    @Test("缺省为 valid / optional")
    func defaults() {
        let probe = Probe()
        self.render(Reader(probe: probe))
        #expect(probe.validation == .valid)
        #expect(probe.requirement == .optional)
    }

    @Test("嵌套时最近一层生效")
    func nearestWins() {
        let probe = Probe()
        self.render(
            Reader(probe: probe)
                .fieldValidation(.invalid("inner"))
                .fieldRequirement(.required)
                .fieldValidation(.valid)
                .fieldRequirement(.optional)
        )
        #expect(probe.validation == .invalid("inner"))
        #expect(probe.requirement == .required)
    }
}

// MARK: - 布局 / Layout

@Suite("FormField 布局：错误行与 description 共用一个槽位")
@MainActor
struct FormFieldLayoutTests {
    private func height(_ view: some View) -> CGFloat {
        let renderer = ImageRenderer(content: view.frame(width: 320).fixedSize(horizontal: false, vertical: true))
        renderer.scale = 1
        return CGFloat(renderer.cgImage?.height ?? 0)
    }

    private func field(_ validation: FieldValidation, layout: FormFieldLayout = .stacked) -> some View {
        FormField("Email", layout: layout) {
            Text(verbatim: "someone@example.com")
        }
        .fieldValidation(validation)
    }

    @Test("无 description 时 invalid 多出错误行；设回 valid 错误行消失")
    func errorRowPresence() {
        let valid = self.height(self.field(.valid))
        let invalid = self.height(self.field(.invalid("Enter a valid email address.")))
        #expect(valid > 0)
        #expect(invalid > valid)
        #expect(self.height(self.field(.valid)) == valid)
    }

    @Test("槽位：enabled + invalid 显示错误行并替换 description；disabled 不显示错误行")
    func slotResolution() {
        let invalid = FieldValidation.invalid("Bad")
        #expect(FormFieldSlot.resolve(appearance: .invalid, validation: invalid, hasDescription: true) == .error("Bad"))
        #expect(FormFieldSlot.resolve(appearance: .normal, validation: .valid, hasDescription: true) == .description)
        #expect(FormFieldSlot.resolve(appearance: .normal, validation: .valid, hasDescription: false) == .empty)
        #expect(FormFieldSlot.resolve(appearance: .disabled, validation: invalid, hasDescription: true) == .description)
        #expect(FormFieldSlot.resolve(appearance: .disabled, validation: invalid, hasDescription: false) == .empty)
    }

    @Test("disabled + invalid 与 disabled + valid 同高：错误行不渲染")
    func disabledHidesErrorRow() {
        let valid = self.height(self.field(.valid).disabled(true))
        let invalid = self.height(self.field(.invalid("Enter a valid email address.")).disabled(true))
        #expect(invalid == valid)
    }

    @Test(".inline 把 label 放进前一列：比 .stacked 矮，且错误行照样出现")
    func inlineLayout() {
        let stacked = self.height(self.field(.valid))
        let inline = self.height(self.field(.valid, layout: .inline))
        #expect(inline > 0)
        #expect(inline < stacked)
        #expect(self.height(self.field(.invalid("Enter a valid email address."), layout: .inline)) > inline)
    }

    @Test(".inline 在辅助功能大字号下回退为 .stacked；.stacked 始终不变")
    func inlineFallsBackAtAccessibilitySizes() {
        #expect(FormFieldLayout.inline.resolved(for: .large) == .inline)
        #expect(FormFieldLayout.inline.resolved(for: .accessibility1) == .stacked)
        #expect(FormFieldLayout.stacked.resolved(for: .large) == .stacked)
        #expect(FormFieldLayout.stacked.resolved(for: .accessibility5) == .stacked)
    }

    @Test("必填星号不改变行高")
    func requiredMarkDoesNotGrow() {
        let optional = self.height(self.field(.valid))
        let required = self.height(self.field(.valid).fieldRequirement(.required))
        #expect(required == optional)
    }
}

// MARK: - 托管视图 / Hosted behaviour

@MainActor
private final class HostHarness<Root: View> {
    #if canImport(UIKit)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    private let controller: UIHostingController<Root>
    #else
    private let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 390, height: 844),
        styleMask: [.titled], backing: .buffered, defer: false
    )
    private let host: NSHostingView<Root>
    #endif

    init(_ root: Root) {
        #if canImport(UIKit)
        self.controller = UIHostingController(rootView: root)
        self.window.rootViewController = self.controller
        self.window.makeKeyAndVisible()
        #else
        self.host = NSHostingView(rootView: root)
        self.host.frame = self.window.contentRect(forFrameRect: self.window.frame)
        self.window.contentView = self.host
        #endif
        self.pump()
    }

    func update(_ root: Root) {
        #if canImport(UIKit)
        self.controller.rootView = root
        #else
        self.host.rootView = root
        #endif
        self.pump()
    }

    func pump() {
        for _ in 0..<5 {
            #if canImport(UIKit)
            self.controller.view.layoutIfNeeded()
            #else
            self.host.layoutSubtreeIfNeeded()
            #endif
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func tearDown() {
        #if canImport(UIKit)
        self.window.isHidden = true
        #else
        self.window.orderOut(nil)
        #endif
    }
}

@MainActor
private final class Recorder {
    var posts: [String] = []
    var appears = 0
    var leadingEdges: [String: CGFloat] = [:]
}

@Suite("FormField 托管行为：身份保持、播报归属、label 列对齐")
@MainActor
struct FormFieldHostedTests {
    private struct AppearProbe: View {
        let recorder: Recorder
        var body: some View {
            Color.clear
                .frame(width: 10, height: 10)
                .onAppear { self.recorder.appears += 1 }
        }
    }

    private struct EdgeProbe: View {
        let recorder: Recorder
        let key: String
        var body: some View {
            GeometryReader { proxy in
                Color.clear.onAppear { self.recorder.leadingEdges[self.key] = proxy.frame(in: .global).minX }
                    .onChange(of: proxy.frame(in: .global).minX) { _, x in self.recorder.leadingEdges[self.key] = x }
            }
            .frame(height: 20)
        }
    }

    @Test("辅助功能大字号切换 .inline → .stacked 时控件子树不重建（onAppear 只触发一次）")
    func layoutFallbackKeepsIdentity() {
        let recorder = Recorder()
        func root(_ size: DynamicTypeSize) -> some View {
            FormField("City", layout: .inline) { AppearProbe(recorder: recorder) }
                .dynamicTypeSize(size)
        }
        let harness = HostHarness(root(.large))
        #expect(recorder.appears == 1)
        harness.update(root(.accessibility2))
        harness.update(root(.large))
        #expect(recorder.appears == 1, "布局回退重建了控件子树，onAppear 触发了 \(recorder.appears) 次")
        harness.tearDown()
    }

    @Test("嵌套 FormField 继承同一校验源时只播报一次；内层自带 .fieldValidation 时各播各的")
    func nestedAnnouncementOwnership() {
        let recorder = Recorder()
        let poster = FieldAnnouncementPoster { recorder.posts.append($0) }
        func inherited(_ validation: FieldValidation) -> some View {
            FormField("Outer") {
                FormField("Inner") { Color.clear.frame(height: 10) }
            }
            .fieldValidation(validation)
            .environment(\.fieldAnnouncementPoster, poster)
            .environment(\.locale, Locale(identifier: "en_US"))
        }
        let harness = HostHarness(inherited(.valid))
        harness.update(inherited(.invalid("Bad")))
        #expect(recorder.posts == ["Bad"])
        harness.tearDown()

        recorder.posts = []
        func separate(_ outer: FieldValidation, _ inner: FieldValidation) -> some View {
            FormField("Outer") {
                FormField("Inner") { Color.clear.frame(height: 10) }
                    .fieldValidation(inner)
            }
            .fieldValidation(outer)
            .environment(\.fieldAnnouncementPoster, poster)
            .environment(\.locale, Locale(identifier: "en_US"))
        }
        let second = HostHarness(separate(.valid, .valid))
        second.update(separate(.invalid("Outer bad"), .invalid("Inner bad")))
        #expect(recorder.posts.sorted() == ["Inner bad", "Outer bad"])
        second.tearDown()
    }

    @Test(".formFieldLabelColumn() 让相邻 .inline 字段的控件左缘对齐；不加时不对齐")
    func sharedLabelColumnAlignsControls() {
        func fields(_ recorder: Recorder) -> some View {
            VStack {
                FormField("City", layout: .inline) { EdgeProbe(recorder: recorder, key: "short") }
                FormField("Postal code", layout: .inline) { EdgeProbe(recorder: recorder, key: "long") }
            }
            .frame(width: 360)
        }
        let aligned = Recorder()
        let harness = HostHarness(fields(aligned).formFieldLabelColumn())
        let short = try? #require(aligned.leadingEdges["short"])
        let long = try? #require(aligned.leadingEdges["long"])
        #expect(short != nil && short == long, "\(aligned.leadingEdges)")
        harness.tearDown()

        let ragged = Recorder()
        let plain = HostHarness(fields(ragged))
        #expect(ragged.leadingEdges["short"] != ragged.leadingEdges["long"], "\(ragged.leadingEdges)")
        plain.tearDown()
    }
}

// MARK: - iOS 位图 / iOS bitmap

#if os(iOS)
@Suite("FormField iOS 位图：invalid 态的 danger 色可见")
@MainActor
struct FormFieldDangerBitmapTests {
    private func dangerPixelCount(_ validation: FieldValidation) throws -> Int {
        let view = FormField("Email") {
            Text(verbatim: "someone@example.com")
        }
        .fieldValidation(validation)
        .padding()
        .frame(width: 320)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let target = Color.statusDangerForeground.resolve(in: EnvironmentValues())
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let tr = Int(target.red * 255), tg = Int(target.green * 255), tb = Int(target.blue * 255)
        var count = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let dr = abs(Int(pixels[index]) - tr), dg = abs(Int(pixels[index + 1]) - tg), db = abs(Int(pixels[index + 2]) - tb)
            if dr + dg + db < 30 { count += 1 }
        }
        return count
    }

    @Test("invalid 渲染出 danger 色像素，valid 没有")
    func dangerVisibleOnlyWhenInvalid() throws {
        #expect(Color.statusDangerForeground.resolve(in: EnvironmentValues()).opacity > 0.9)
        #expect(try self.dangerPixelCount(.valid) == 0)
        #expect(try self.dangerPixelCount(.invalid("Enter a valid email address.")) > 50)
    }
}
#endif
