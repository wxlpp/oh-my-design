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
    static let canvasWidth = 360
    static let scale = 2

    static func image(_ view: some View, scheme: ColorScheme) -> CGImage? {
        let renderer = ImageRenderer(
            content: view
                .padding(8)
                .frame(width: CGFloat(Self.canvasWidth))
                .background(Color.surfaceCanvas)
                .environment(\.colorScheme, scheme)
                .dynamicTypeSize(.large)
        )
        renderer.scale = CGFloat(Self.scale)
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

// MARK: - 原生输入框占位块 / Native text field placeholder

// ImageRenderer 画不出原生 TextField，只画一块纯黄占位，该块偶发整块移 1px；
// 所以占位块只比位置（±1px），块外照常比位图。
private struct NativePlaceholderBounds: Equatable, CustomStringConvertible {
    let minX: Int, maxX: Int, minY: Int, maxY: Int

    var description: String { "x \(self.minX)...\(self.maxX) y \(self.minY)...\(self.maxY)" }

    static func find(in bytes: [UInt8], width: Int) -> Self? {
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        for index in stride(from: 0, to: bytes.count, by: 4)
        where bytes[index] >= 250 && (198...210).contains(bytes[index + 1]) && bytes[index + 2] <= 8 {
            let x = index / 4 % width, y = index / 4 / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        return maxX < 0 ? nil : Self(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    func isWithinOnePixel(of other: Self) -> Bool {
        abs(self.minX - other.minX) <= 1 && abs(self.maxX - other.maxX) <= 1
            && abs(self.minY - other.minY) <= 1 && abs(self.maxY - other.maxY) <= 1
    }

    func blanking(_ bytes: [UInt8], width: Int, union other: Self) -> [UInt8] {
        var result = bytes
        let height = bytes.count / 4 / width
        for y in max(0, min(self.minY, other.minY) - 1)...min(height - 1, max(self.maxY, other.maxY) + 1) {
            for x in max(0, min(self.minX, other.minX) - 1)...min(width - 1, max(self.maxX, other.maxX) + 1) {
                let index = (y * width + x) * 4
                result.replaceSubrange(index..<index + 4, with: [0, 0, 0, 0])
            }
        }
        return result
    }
}

private func expectEquivalentAroundNativePlaceholder(
    _ a: [UInt8]?, _ b: [UInt8]?, _ comment: String, sourceLocation: SourceLocation = #_sourceLocation
) {
    let width = ControlRender.canvasWidth * ControlRender.scale
    guard let a, let b else {
        expectBitmapsEquivalent(a, b, maxChannelDelta: 1, comment, sourceLocation: sourceLocation)
        return
    }
    let placeholders = (NativePlaceholderBounds.find(in: a, width: width), NativePlaceholderBounds.find(in: b, width: width))
    guard let lhs = placeholders.0, let rhs = placeholders.1 else {
        #expect(placeholders.0 == nil && placeholders.1 == nil, "\(comment)：只有一侧有原生输入框占位块 \(placeholders)", sourceLocation: sourceLocation)
        expectBitmapsEquivalent(a, b, maxChannelDelta: 1, comment, sourceLocation: sourceLocation)
        return
    }
    #expect(lhs.isWithinOnePixel(of: rhs), "\(comment)：原生输入框位置 / 尺寸不同（\(lhs) vs \(rhs)）", sourceLocation: sourceLocation)
    expectBitmapsEquivalent(
        lhs.blanking(a, width: width, union: rhs), rhs.blanking(b, width: width, union: lhs),
        maxChannelDelta: 1, "\(comment)（原生输入框占位块以外）", sourceLocation: sourceLocation
    )
}

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

    nonisolated static let choiceCases: [FieldControlSample] = [.checkBoxOff, .checkBoxOn, .radioVertical, .radioHorizontal]

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

    var legacyDisabled: AnyView {
        switch self {
        case .pinCode, .pinCodeSecure: AnyView(self.legacy.disabled(true))
        case .tagInput:
            AnyView(LegacyTagInput(tags: ["design", "ios"], chipOpacity: FieldAppearance.disabledControlOpacity).disabled(true))
        case .checkBoxOff, .checkBoxOn, .radioVertical, .radioHorizontal:
            AnyView(self.legacy.disabled(true).opacity(FieldAppearance.disabledControlOpacity))
        }
    }

    var legacy: AnyView {
        switch self {
        case .pinCode: AnyView(LegacyPinCode(value: "", length: 6, isSecure: false, hiddenField: .omitted))
        case .pinCodeSecure: AnyView(LegacyPinCode(value: "", length: 4, isSecure: true, hiddenField: .omitted))
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
            expectEquivalentAroundNativePlaceholder(
                ControlRender.pixels(sample.current, scheme: scheme),
                ControlRender.pixels(sample.legacy, scheme: scheme),
                "\(sample) \(scheme)：valid 外观与旧实现不同"
            )
        }
    }

    @Test("显式 .fieldValidation(.valid) 与旧实现在光栅化噪声内逐像素一致", arguments: FieldControlSample.allCases)
    func explicitValidMatchesLegacyPixels(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectEquivalentAroundNativePlaceholder(
                ControlRender.pixels(sample.current.fieldValidation(.valid), scheme: scheme),
                ControlRender.pixels(sample.legacy, scheme: scheme),
                "\(sample) \(scheme)"
            )
        }
    }

    @Test(
        "disabled 压过 invalid：disabled + invalid 与旧实现的 disabled（CheckBox / Radio 另整体降到禁用不透明度）在光栅化噪声内逐像素一致",
        arguments: FieldControlSample.allCases
    )
    func disabledInvalidMatchesLegacyDisabled(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectEquivalentAroundNativePlaceholder(
                ControlRender.pixels(sample.current.fieldValidation(sampleInvalid).disabled(true), scheme: scheme),
                ControlRender.pixels(sample.legacyDisabled, scheme: scheme),
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

// MARK: - #384 跟进 / Follow-ups

private extension ControlRender {
    static func matches(_ bytes: [UInt8], at index: Int, _ color: Color.Resolved, tolerance: Int = 30) -> Bool {
        let delta = abs(Int(bytes[index]) - Int(color.red * 255)) + abs(Int(bytes[index + 1]) - Int(color.green * 255))
            + abs(Int(bytes[index + 2]) - Int(color.blue * 255))
        return bytes[index + 3] > 200 && delta < tolerance
    }

    static func resolved(_ color: Color, scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }

    static func count(_ bytes: [UInt8]?, _ color: Color, scheme: ColorScheme) -> Int {
        guard let bytes else { return -1 }
        let target = Self.resolved(color, scheme: scheme)
        return stride(from: 0, to: bytes.count, by: 4).filter { Self.matches(bytes, at: $0, target) }.count
    }
}

@Suite("输入控件跟进：TagInput 下划线 / Radio 圆环 / PinCode 获焦 / 禁用变淡")
@MainActor
struct FieldControlFollowUpTests {
    private static let catalogOnly = "跳过：bundle 里没有 Assets.car，status* 取自 asset catalog，在 SwiftPM native 腿上解析为全透明；本条在 iOS Simulator 腿上跑。"

    @Test(
        "TagInput invalid 下划线横跨整个字段宽度并位于最后一行底部（单行 / 多行换行，light / dark）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly)),
        arguments: [["design", "ios"], ["bug", "enhancement", "help wanted", "documentation", "good first issue"]]
    )
    func tagInputUnderlineSpansField(_ tags: [String]) throws {
        for scheme in ControlRender.schemes {
            let image = try #require(ControlRender.image(TagInput(tags: .constant(tags)).fieldValidation(sampleInvalid), scheme: scheme))
            let bytes = try #require(ControlRender.pixels(image))
            let target = ControlRender.resolved(.statusDangerForeground, scheme: scheme)
            var rows: [Int: (minX: Int, maxX: Int)] = [:]
            for index in stride(from: 0, to: bytes.count, by: 4) where ControlRender.matches(bytes, at: index, target) {
                let pixel = index / 4
                let x = pixel % image.width, y = pixel / image.width
                let row = rows[y] ?? (x, x)
                rows[y] = (min(row.minX, x), max(row.maxX, x))
            }
            let bottom = try #require(rows.keys.max(), "\(scheme)：没画出下划线")
            let span = try #require(rows[bottom])
            let fieldWidth = (360 - 16) * 2
            #expect(span.maxX - span.minX + 1 >= fieldWidth - 2, "\(scheme)：下划线只覆盖 \(span.maxX - span.minX + 1)px，字段宽 \(fieldWidth)px")
            #expect(image.height - bottom <= 8 * 2 + 2, "\(scheme)：下划线不在字段底部（距底 \(image.height - bottom)px）")
        }
    }

    @Test(
        "Radio invalid：只有圆环变红，选中实心点保持正常色（light / dark）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly))
    )
    func radioInvalidKeepsDotColor() {
        let option = [RadioOption(value: "basic", title: "Basic")]
        for scheme in ControlRender.schemes {
            let selected = ControlRender.pixels(RadioGroup(selection: .constant("basic"), options: option).fieldValidation(sampleInvalid), scheme: scheme)
            let unselected = ControlRender.pixels(RadioGroup(selection: .constant("other"), options: option).fieldValidation(sampleInvalid), scheme: scheme)
            let ringOnly = ControlRender.count(unselected, .statusDangerForeground, scheme: scheme)
            let selectedDanger = ControlRender.count(selected, .statusDangerForeground, scheme: scheme)
            #expect(ringOnly > 40, "\(scheme)：未选中 invalid 没画出红色圆环")
            #expect(selectedDanger > 40 && Double(selectedDanger) <= Double(ringOnly) * 1.25, "\(scheme)：选中 invalid 的红色像素 \(selectedDanger)，圆环只有 \(ringOnly)——实心点也变红了")
            let dot = ControlRender.count(selected, .contentPrimary, scheme: scheme) - ControlRender.count(unselected, .contentPrimary, scheme: scheme)
            #expect(dot > 100, "\(scheme)：选中实心点没有保持 contentPrimary（多出 \(dot) 个像素）")
        }
    }

    @Test(
        "PinCode 获焦 + invalid 格与其他 invalid 格可区分：格外多一圈光晕、红边更粗（light / dark）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly))
    )
    func pinCodeFocusedInvalidCellIsDistinct() throws {
        for scheme in ControlRender.schemes {
            let focused = try #require(ControlRender.image(PinCodeCell(character: nil, isSecure: false, isCurrent: true).fieldValidation(sampleInvalid), scheme: scheme))
            let other = try #require(ControlRender.image(PinCodeCell(character: nil, isSecure: false, isCurrent: false).fieldValidation(sampleInvalid), scheme: scheme))
            let focusedBytes = ControlRender.pixels(focused), otherBytes = ControlRender.pixels(other)
            expectBitmapsDiffer(focusedBytes, otherBytes, "\(scheme)")
            #expect(
                ControlRender.count(focusedBytes, .statusDangerForeground, scheme: scheme)
                    > ControlRender.count(otherBytes, .statusDangerForeground, scheme: scheme) * 3 / 2,
                "\(scheme)：获焦格红边没有明显更粗"
            )
            let canvas = ControlRender.resolved(.surfaceCanvas, scheme: scheme)
            func haloPixels(_ image: CGImage, _ bytes: [UInt8]?, tolerance: Int) -> Int {
                guard let bytes else { return -1 }
                let cellSide = Int(CoreControlMetrics.height(for: .regular)) * 2
                let minX = (image.width - cellSide) / 2, minY = (image.height - cellSide) / 2
                var count = 0
                for index in stride(from: 0, to: bytes.count, by: 4) {
                    let pixel = index / 4
                    let x = pixel % image.width, y = pixel / image.width
                    let outside = x < minX - 1 || x > minX + cellSide || y < minY - 1 || y > minY + cellSide
                    if outside && !ControlRender.matches(bytes, at: index, canvas, tolerance: tolerance) { count += 1 }
                }
                return count
            }
            #expect(haloPixels(focused, focusedBytes, tolerance: 60) > 200, "\(scheme)：获焦 invalid 格外没有与底色拉开差距的光晕")
            #expect(haloPixels(other, otherBytes, tolerance: 6) == 0, "\(scheme)：非获焦 invalid 格外出现了像素")
        }
    }

    @Test(
        "PinCode 获焦 invalid 格的光晕与相邻格之间留出 ≥ 6pt（light / dark）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly))
    )
    func pinCodeHaloLeavesRoomForNeighbor() throws {
        for scheme in ControlRender.schemes {
            let row = HStack(spacing: CoreSpacing.sm) {
                PinCodeCell(character: nil, isSecure: false, isCurrent: true)
                PinCodeCell(character: nil, isSecure: false, isCurrent: false)
            }
            .fieldValidation(sampleInvalid)
            let image = try #require(ControlRender.image(row, scheme: scheme))
            let bytes = try #require(ControlRender.pixels(image))
            let canvas = ControlRender.resolved(.surfaceCanvas, scheme: scheme)
            let y = image.height / 2
            let inked = (0..<image.width).map { x in !ControlRender.matches(bytes, at: (y * image.width + x) * 4, canvas, tolerance: 6) }
            let first = try #require(inked.firstIndex(of: true))
            let firstEnd = try #require(inked[first...].firstIndex(of: false))
            let second = try #require(inked[firstEnd...].firstIndex(of: true))
            let gap = CGFloat(second - firstEnd) / CGFloat(ControlRender.scale)
            #expect(gap >= 6, "\(scheme)：光晕外沿离相邻格只有 \(gap)pt")
        }
    }

    @Test("PinCode 获焦 valid 格与旧实现在光栅化噪声内逐像素一致（光晕只属于 invalid，light / dark）")
    func pinCodeFocusedValidCellUnchanged() {
        for scheme in ControlRender.schemes {
            expectBitmapsEquivalent(
                ControlRender.pixels(PinCodeCell(character: "4", isSecure: false, isCurrent: true), scheme: scheme),
                ControlRender.pixels(LegacyPinCodeCell(value: "4", index: 0, isSecure: false, isCurrent: true), scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)"
            )
        }
    }

    @Test("CheckBox / Radio disabled 整体变淡：与旧实现整体降到禁用不透明度等价，且与 enabled 不同（light / dark，两条腿）", arguments: FieldControlSample.choiceCases)
    func choiceControlsDimWhenDisabled(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            let disabled = ControlRender.pixels(sample.current.disabled(true), scheme: scheme)
            expectBitmapsDiffer(disabled, ControlRender.pixels(sample.current, scheme: scheme), "\(scheme)：disabled 没有变淡")
            expectBitmapsEquivalent(
                disabled,
                ControlRender.pixels(sample.legacy.opacity(FieldAppearance.disabledControlOpacity), scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)"
            )
        }
    }

    @Test("TagInput disabled 时 chip 整体降到禁用不透明度，且与改动前（chip 不变淡）不同（light / dark，两条腿）")
    func tagInputChipsDimWhenDisabled() {
        for scheme in ControlRender.schemes {
            let disabled = ControlRender.pixels(TagInput(tags: .constant(["design", "ios"])).disabled(true), scheme: scheme)
            expectEquivalentAroundNativePlaceholder(
                disabled,
                ControlRender.pixels(
                    LegacyTagInput(tags: ["design", "ios"], chipOpacity: FieldAppearance.disabledControlOpacity).disabled(true),
                    scheme: scheme
                ),
                "\(scheme)"
            )
            expectBitmapsDiffer(
                disabled,
                ControlRender.pixels(LegacyTagInput(tags: ["design", "ios"]).disabled(true), scheme: scheme),
                "\(scheme)：disabled 下 chip 没有变淡"
            )
        }
    }

    @Test("CheckBox / Radio enabled 与旧实现在光栅化噪声内逐像素一致（light / dark，两条腿）", arguments: FieldControlSample.choiceCases)
    func choiceControlsEnabledUnchanged(_ sample: FieldControlSample) {
        for scheme in ControlRender.schemes {
            expectBitmapsEquivalent(
                ControlRender.pixels(sample.current, scheme: scheme),
                ControlRender.pixels(sample.legacy, scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)"
            )
        }
    }

    @Test("PinCode 有值时与旧实现的格子行在光栅化噪声内一致：隐藏输入框不再出像素（light / dark，两条腿）")
    func pinCodeReferenceOmitsOnlyTheHiddenField() {
        for scheme in ControlRender.schemes {
            let current = ControlRender.pixels(PinCode(value: .constant("12"), length: 6), scheme: scheme)
            expectBitmapsEquivalent(
                current,
                ControlRender.pixels(LegacyPinCode(value: "12", length: 6, isSecure: false, hiddenField: .omitted), scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)"
            )
        }
    }

    @Test("禁用不透明度与外观解析同源：只有 disabled 降低")
    func disabledOpacityFollowsAppearance() {
        #expect(FieldAppearance.disabled.controlOpacity == FieldAppearance.disabledControlOpacity)
        #expect(FieldAppearance.disabledControlOpacity < 1)
        for appearance in [FieldAppearance.normal, .focused, .invalid] {
            #expect(appearance.controlOpacity == 1)
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

private enum LegacyHiddenField {
    case included
    case omitted
}

private struct LegacyPinCode: View {
    let value: String
    let length: Int
    let isSecure: Bool
    var hiddenField: LegacyHiddenField = .included

    var body: some View {
        ZStack {
            if self.hiddenField == .included {
                self.legacyHiddenField
            }
            HStack(spacing: CoreSpacing.sm) {
                ForEach(0..<self.length, id: \.self) { index in
                    LegacyPinCodeCell(value: self.value, index: index, isSecure: self.isSecure)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private var legacyHiddenField: some View {
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
    }
}

private struct LegacyPinCodeCell: View {
    let value: String
    let index: Int
    let isSecure: Bool
    var isCurrent = false

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let character = PinCode.character(at: self.index, in: self.value)
        let isCurrent = self.isCurrent
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
    var chipOpacity: Double = 1

    var body: some View {
        FlowLayout(spacing: CoreSpacing.sm) {
            ForEach(Array(self.tags.enumerated()), id: \.offset) { _, tag in
                Tag(tag, color: .contentSecondary, removable: true) {}
                    .opacity(self.chipOpacity)
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
