import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 播报规则 / Announcement rule

@Suite("FormField 播报：仅 valid→invalid 或错误文本变化时播报一次")
struct FieldValidationAnnouncerTests {
    @Test("首次渲染即 invalid 不播报")
    func firstRenderInvalidIsSilent() {
        var announcer = FieldValidationAnnouncer()
        #expect(announcer.observe(.invalid(Text(verbatim: "Required"))) == nil)
    }

    @Test("值未变的重建不播报")
    func unchangedRebuildIsSilent() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.valid)
        #expect(announcer.observe(.invalid(Text(verbatim: "Bad"))) == Text(verbatim: "Bad"))
        #expect(announcer.observe(.invalid(Text(verbatim: "Bad"))) == nil)
        #expect(announcer.observe(.invalid(Text(verbatim: "Bad"))) == nil)
    }

    @Test("valid → invalid 播报错误原因一次")
    func validToInvalidAnnounces() {
        var announcer = FieldValidationAnnouncer()
        #expect(announcer.observe(.valid) == nil)
        #expect(announcer.observe(.invalid(Text(verbatim: "Bad"))) == Text(verbatim: "Bad"))
    }

    @Test("invalid 的错误文本变化时播报新文本")
    func reasonChangeAnnounces() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.invalid(Text(verbatim: "A")))
        #expect(announcer.observe(.invalid(Text(verbatim: "B"))) == Text(verbatim: "B"))
    }

    @Test("转回 valid 或 valid 重建都不播报")
    func becomingValidIsSilent() {
        var announcer = FieldValidationAnnouncer()
        _ = announcer.observe(.valid)
        _ = announcer.observe(.invalid(Text(verbatim: "A")))
        #expect(announcer.observe(.valid) == nil)
        #expect(announcer.observe(.valid) == nil)
        #expect(announcer.observe(.invalid(Text(verbatim: "A"))) == Text(verbatim: "A"))
    }

    @Test("一条完整序列的播报次数")
    func sequenceCount() {
        var announcer = FieldValidationAnnouncer()
        let sequence: [FieldValidation] = [
            .invalid(Text(verbatim: "A")),
            .invalid(Text(verbatim: "A")),
            .valid,
            .valid,
            .invalid(Text(verbatim: "A")),
            .invalid(Text(verbatim: "B")),
            .invalid(Text(verbatim: "B")),
        ]
        let announced = sequence.compactMap { announcer.observe($0) }
        #expect(announced == [Text(verbatim: "A"), Text(verbatim: "B")])
    }
}

// MARK: - 外观优先级 / Appearance priority

@Suite("FormField 外观：disabled > invalid > focused")
struct FieldAppearanceTests {
    private let invalid = FieldValidation.invalid(Text(verbatim: "Bad"))

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
        #expect(FieldAppearance.normal.requiredMarkColor == Color.statusDangerForeground)
        #expect(FieldAppearance.disabled.requiredMarkColor == Color.contentDisabled)
    }
}

// MARK: - 无障碍文本 / Accessibility text

@Suite("FormField 无障碍文本：hint 拼装与必填 label")
struct FormFieldAccessibilityTextTests {
    @Test("hint：错误原因在前、description 在后")
    func hintOrder() {
        let parts = FieldAccessibilityHint.parts(
            validation: .invalid(Text(verbatim: "E")),
            description: Text(verbatim: "D")
        )
        #expect(parts == [Text(verbatim: "E"), Text(verbatim: "D")])
    }

    @Test("hint：无错误无 description 时为 nil，单项时原样")
    func hintEmptyAndSingle() {
        #expect(FieldAccessibilityHint.text(validation: .valid, description: nil) == nil)
        #expect(FieldAccessibilityHint.text(validation: .valid, description: Text(verbatim: "D")) == Text(verbatim: "D"))
        #expect(
            FieldAccessibilityHint.text(validation: .invalid(Text(verbatim: "E")), description: nil)
                == Text(verbatim: "E")
        )
    }

    @Test("必填 label 追加文案，选填原样")
    func requiredLabel() {
        let label = Text(verbatim: "Email")
        #expect(FormFieldAccessibility.label(label, requirement: .optional) == label)
        #expect(FormFieldAccessibility.label(label, requirement: .required) != label)
        let resolved = FormFieldAccessibility.label(label, requirement: .required)._resolveText(in: EnvironmentValues())
        #expect(resolved == "Email, required")
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
                .fieldValidation(.invalid(Text(verbatim: "inner")))
                .fieldRequirement(.required)
                .fieldValidation(.valid)
                .fieldRequirement(.optional)
        )
        #expect(probe.validation == .invalid(Text(verbatim: "inner")))
        #expect(probe.requirement == .required)
    }
}

// MARK: - 布局 / Layout

@Suite("FormField 布局：错误行随校验态出现 / 移除")
@MainActor
struct FormFieldLayoutTests {
    private func height(_ view: some View) -> CGFloat {
        let renderer = ImageRenderer(content: view.frame(width: 320).fixedSize(horizontal: false, vertical: true))
        renderer.scale = 1
        return CGFloat(renderer.cgImage?.height ?? 0)
    }

    private func field(_ validation: FieldValidation) -> some View {
        FormField("Email", description: "We never share it.") {
            Text(verbatim: "someone@example.com")
        }
        .fieldValidation(validation)
    }

    @Test("invalid 比 valid 多出错误行；设回 valid 错误行消失")
    func errorRowPresence() {
        let valid = self.height(self.field(.valid))
        let invalid = self.height(self.field(.invalid(Text(verbatim: "Enter a valid email address."))))
        #expect(valid > 0)
        #expect(invalid > valid)
        #expect(self.height(self.field(.valid)) == valid)
    }

    @Test("必填星号不改变行高")
    func requiredMarkDoesNotGrow() {
        let optional = self.height(self.field(.valid))
        let required = self.height(self.field(.valid).fieldRequirement(.required))
        #expect(required == optional)
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
        #expect(try self.dangerPixelCount(.invalid(Text(verbatim: "Enter a valid email address."))) > 50)
    }
}
#endif
