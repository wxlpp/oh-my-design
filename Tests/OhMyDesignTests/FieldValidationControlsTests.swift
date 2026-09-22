import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - 渲染辅助 / Rendering helpers

@MainActor
private enum ControlRender {
    static let schemes: [ColorScheme] = [.light, .dark]

    static func image(_ view: some View, scheme: ColorScheme) -> CGImage? {
        let renderer = ImageRenderer(
            content: view
                .padding(8)
                .frame(width: 360)
                .background(Color.surfaceCanvas)
                .environment(\.colorScheme, scheme)
                .dynamicTypeSize(.large)
        )
        renderer.scale = 2
        _ = renderer.cgImage
        return renderer.cgImage
    }

    static func pixels(_ image: CGImage?) -> [UInt8]? {
        guard let image else { return nil }
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    static func pixels(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
        Self.pixels(Self.image(view, scheme: scheme))
    }

    static func dangerPixelCount(_ bytes: [UInt8]?, scheme: ColorScheme) -> Int {
        guard let bytes else { return -1 }
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let target = Color.statusDangerForeground.resolve(in: environment)
        let tr = Int(target.red * 255), tg = Int(target.green * 255), tb = Int(target.blue * 255)
        var count = 0
        for index in stride(from: 0, to: bytes.count, by: 4) where bytes[index + 3] > 200 {
            let delta = abs(Int(bytes[index]) - tr) + abs(Int(bytes[index + 1]) - tg) + abs(Int(bytes[index + 2]) - tb)
            if delta < 30 { count += 1 }
        }
        return count
    }
}

private let sampleInvalid = FieldValidation.invalid("Something is wrong.")

// MARK: - 控件样本 / Control samples

@MainActor
enum FieldControlSample: CaseIterable, CustomStringConvertible {
    case pinCode
    case pinCodeSecure
    case tagInput
    case checkBoxOff
    case checkBoxOn
    case radioVertical
    case radioHorizontal

    var description: String {
        switch self {
        case .pinCode: "PinCode"
        case .pinCodeSecure: "PinCode(isSecure)"
        case .tagInput: "TagInput"
        case .checkBoxOff: "CheckBox(off)"
        case .checkBoxOn: "CheckBox(on)"
        case .radioVertical: "RadioGroup(.vertical)"
        case .radioHorizontal: "RadioGroup(.horizontal)"
        }
    }

    private static let options = [
        RadioOption(value: "basic", title: "Basic"),
        RadioOption(value: "pro", title: "Pro"),
    ]

    var current: AnyView {
        switch self {
        case .pinCode: AnyView(PinCode(value: .constant(""), length: 6))
        case .pinCodeSecure: AnyView(PinCode(value: .constant(""), length: 4, isSecure: true))
        case .tagInput: AnyView(TagInput(tags: .constant(["design", "ios"])))
        case .checkBoxOff: AnyView(Toggle("Accept", isOn: .constant(false)).toggleStyle(CheckBoxToggleStyle()))
        case .checkBoxOn: AnyView(Toggle("Accept", isOn: .constant(true)).toggleStyle(CheckBoxToggleStyle()))
        case .radioVertical: AnyView(RadioGroup(selection: .constant("basic"), options: Self.options))
        case .radioHorizontal: AnyView(RadioGroup(selection: .constant("pro"), options: Self.options, axis: .horizontal))
        }
    }

    var legacy: AnyView {
        switch self {
        case .pinCode: AnyView(LegacyPinCode(value: "", length: 6, isSecure: false))
        case .pinCodeSecure: AnyView(LegacyPinCode(value: "", length: 4, isSecure: true))
        case .tagInput: AnyView(LegacyTagInput(tags: ["design", "ios"]))
        case .checkBoxOff: AnyView(Toggle("Accept", isOn: .constant(false)).toggleStyle(LegacyCheckBoxToggleStyle()))
        case .checkBoxOn: AnyView(Toggle("Accept", isOn: .constant(true)).toggleStyle(LegacyCheckBoxToggleStyle()))
        case .radioVertical: AnyView(LegacyRadioGroup(selection: "basic", options: Self.options, axis: .vertical))
        case .radioHorizontal: AnyView(LegacyRadioGroup(selection: "pro", options: Self.options, axis: .horizontal))
        }
    }
}

// MARK: - 外观 / Appearance

@Suite("五个控件接入校验态：外观")
@MainActor
struct FieldValidationControlsAppearanceTests {
    @Test("选择类指示色：只有 invalid 换成 danger，其余外观原样")
    func indicatorColorMapping() {
        #expect(FieldAppearance.invalid.indicatorColor(normal: .contentPrimary) == Color.statusDangerForeground)
        #expect(FieldAppearance.normal.indicatorColor(normal: .contentPrimary) == Color.contentPrimary)
        #expect(FieldAppearance.focused.indicatorColor(normal: .contentSecondary) == Color.contentSecondary)
        #expect(FieldAppearance.disabled.indicatorColor(normal: .contentSecondary) == Color.contentSecondary)
    }

    @Test("valid 与改动前实现（92d224b 原样拷贝）在光栅化噪声内逐像素一致（light / dark，两条腿都跑）", arguments: FieldControlSample.allCases)
    func validMatchesLegacyPixels(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectBitmapsEquivalent(
                ControlRender.pixels(sample.current, scheme: scheme),
                ControlRender.pixels(sample.legacy, scheme: scheme),
                maxChannelDelta: 1,
                "\(sample) \(scheme)：valid 外观与旧实现不同"
            )
        }
    }

    @Test("显式 .fieldValidation(.valid) 与旧实现在光栅化噪声内逐像素一致", arguments: FieldControlSample.allCases)
    func explicitValidMatchesLegacyPixels(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectBitmapsEquivalent(
                ControlRender.pixels(sample.current.fieldValidation(.valid), scheme: scheme),
                ControlRender.pixels(sample.legacy, scheme: scheme),
                maxChannelDelta: 1,
                "\(sample) \(scheme)"
            )
        }
    }

    @Test("disabled 压过 invalid：disabled + invalid 与旧实现的 disabled 在光栅化噪声内逐像素一致", arguments: FieldControlSample.allCases)
    func disabledInvalidMatchesLegacyDisabled(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectBitmapsEquivalent(
                ControlRender.pixels(sample.current.fieldValidation(sampleInvalid).disabled(true), scheme: scheme),
                ControlRender.pixels(sample.legacy.disabled(true), scheme: scheme),
                maxChannelDelta: 1,
                "\(sample) \(scheme)：disabled + invalid 仍画出了 invalid 外观"
            )
        }
    }

    @Test(
        "invalid 画出 danger 色，valid 没有（light / dark）",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：bundle 里没有 Assets.car（SwiftPM native 腿），statusDangerForeground 取自 asset catalog，\
            在这条腿上解析为全透明，invalid 分支画不出任何像素。本条在 iOS Simulator 腿上跑；\
            native 腿由「valid / disabled + invalid 与旧实现在光栅化噪声内逐像素一致」兜住不回归的一侧。
            """
        ),
        arguments: FieldControlSample.allCases
    )
    func invalidDrawsDanger(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            let valid = ControlRender.pixels(sample.current, scheme: scheme)
            let broken = ControlRender.pixels(sample.current.fieldValidation(sampleInvalid), scheme: scheme)
            #expect(ControlRender.dangerPixelCount(valid, scheme: scheme) == 0, "\(sample) \(scheme)：valid 里出现了 danger 色")
            #expect(ControlRender.dangerPixelCount(broken, scheme: scheme) > 40, "\(sample) \(scheme)：invalid 没画出 danger 色")
            expectBitmapsDiffer(valid, broken, "\(sample) \(scheme)：invalid 与 valid 外观相同")
        }
    }
}

// MARK: - 无障碍 label 策略 / Accessibility label policy

@Suite("无障碍 label 策略的判定函数（只测 FieldAccessibilityLabel.resolved，不读真实无障碍节点）")
struct FieldAccessibilityLabelPolicyTests {
    private let field = Text(verbatim: "Code")
    private let own = Text(verbatim: "Verification code")

    @Test("fieldLabel(fallback:)：有字段 label 时取字段 label（含必填），没有时取回退值")
    func textEntryUsesFieldLabelThenFallback() {
        let policy = FieldAccessibilityLabel.fieldLabel(fallback: self.own)
        #expect(policy.resolved(fieldLabel: self.field, requirement: .optional) == self.field)
        #expect(
            policy.resolved(fieldLabel: self.field, requirement: .required)
                == FormFieldAccessibility.label(self.field, requirement: .required)
        )
        #expect(policy.resolved(fieldLabel: nil, requirement: .required) == self.own)
    }

    @Test("keepOwn：不产出 label")
    func choiceKeepsOwnLabel() {
        #expect(FieldAccessibilityLabel.keepOwn.resolved(fieldLabel: self.field, requirement: .required) == nil)
    }

    @Test("fieldLabel(fallback: nil)：没有字段 label 时不产出 label")
    func publicModifierHasNoFallback() {
        #expect(FieldAccessibilityLabel.fieldLabel(fallback: nil).resolved(fieldLabel: nil, requirement: .optional) == nil)
    }
}

// MARK: - SearchField 描边 / SearchField stroke

@Suite("SearchField 包装层（ImageRenderer 不渲染原生控件，只看 SwiftUI 叠加层）")
@MainActor
struct SearchFieldWrapperStrokeTests {
    @Test(
        "包装层：invalid 叠加 danger 描边，valid 与 disabled + invalid 不叠加（light / dark）",
        .enabled(
            if: assetCatalogIsCompiled,
            "跳过：bundle 里没有 Assets.car，statusDangerForeground 解析为全透明；本条在 iOS Simulator 腿上跑。"
        )
    )
    func invalidDrawsDangerStroke() {
        for scheme in ControlRender.schemes {
            let field = SearchField(text: .constant("release"))
            let valid = ControlRender.pixels(field, scheme: scheme)
            let broken = ControlRender.pixels(field.fieldValidation(sampleInvalid), scheme: scheme)
            let disabled = ControlRender.pixels(field.fieldValidation(sampleInvalid).disabled(true), scheme: scheme)
            #expect(ControlRender.dangerPixelCount(valid, scheme: scheme) == 0, "\(scheme)")
            #expect(ControlRender.dangerPixelCount(broken, scheme: scheme) > 200, "\(scheme)：invalid 没画出描边")
            #expect(ControlRender.dangerPixelCount(disabled, scheme: scheme) == 0, "\(scheme)：disabled 压不过 invalid")
        }
    }

    @Test("包装层：disabled + invalid 与 disabled + valid 在光栅化噪声内一致（两条腿都跑）")
    func disabledInvalidMatchesDisabledValid() {
        for scheme in ControlRender.schemes {
            let field = SearchField(text: .constant("release"))
            expectBitmapsEquivalent(
                ControlRender.pixels(field.fieldValidation(sampleInvalid).disabled(true), scheme: scheme),
                ControlRender.pixels(field.disabled(true), scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)"
            )
        }
    }
}

// MARK: - 旧实现原样拷贝（92d224b）/ Legacy copies

private struct LegacyPinCode: View {
    let value: String
    let length: Int
    let isSecure: Bool

    var body: some View {
        ZStack {
            TextField("", text: .constant(self.value))
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                #if os(iOS)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                #endif
                .fixedSize()
                .opacity(0.01)
                .accessibilityHidden(true)
            HStack(spacing: CoreSpacing.sm) {
                ForEach(0..<self.length, id: \.self) { index in
                    LegacyPinCodeCell(value: self.value, index: index, isSecure: self.isSecure)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

private struct LegacyPinCodeCell: View {
    let value: String
    let index: Int
    let isSecure: Bool

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let character = PinCode.character(at: self.index, in: self.value)
        let isCurrent = false
        let shape = CoreShape.rounded(CoreRadius.medium)
        let cellSize = CoreControlMetrics.height(for: self.controlSize)

        Text(PinCode.displayText(for: character, isSecure: self.isSecure))
            .coreFont(.title2)
            .foregroundStyle(self.isEnabled ? Color.contentPrimary : Color.contentDisabled)
            .frame(width: cellSize, height: cellSize)
            .background {
                shape.fill(Color.surfaceInteractive)
            }
            .overlay {
                shape.strokeBorder(
                    isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.borderMuted),
                    lineWidth: isCurrent ? CoreBorderWidth.thick : CoreBorderWidth.thin
                )
            }
    }
}

private struct LegacyTagInput: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: CoreSpacing.sm) {
            ForEach(Array(self.tags.enumerated()), id: \.offset) { _, tag in
                Tag(tag, color: .contentSecondary, removable: true) {}
            }

            TextField("Add tag", text: .constant(""))
                .textFieldStyle(.plain)
                .coreFont(CoreControlMetrics.fontToken(for: .regular))
                .foregroundStyle(Color.contentPrimary)
                .frame(minWidth: 80)
                .frame(minHeight: CoreControlMetrics.height(for: .regular))
                .accessibilityLabel(Text("Add tag"))
        }
    }
}

private struct LegacyCheckBoxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            if configuration.isOn {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentPrimary)
            } else {
                Image(systemName: "square")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentSecondary)
            }
            configuration.label
        }
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.25), value: configuration.isOn)
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

private struct LegacyRadioGroup: View {
    let selection: String
    let options: [RadioOption<String>]
    let axis: Axis

    var body: some View {
        Group {
            if self.axis == .horizontal {
                HStack(spacing: CoreSpacing.sm) {
                    ForEach(self.options) { option in
                        self.row(for: option)
                    }
                }
            } else {
                VStack(spacing: CoreSpacing.sm) {
                    ForEach(self.options) { option in
                        self.row(for: option)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for option: RadioOption<String>) -> some View {
        let selected = option.value == self.selection
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: selected ? "circle.inset.filled" : "circle")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(selected ? Color.contentPrimary : Color.contentSecondary)
                .accessibilityHidden(true)
            Text(option.title)
        }
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.25), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
