import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - 三态真值表 / Tri-state truth table

@Suite("CheckBox 指示符三态：off / mixed / on 的判定与取值")
struct CheckBoxIndicatorTests {
    @Test("resolve：mixed 压过 isOn —— 四种 (isOn, isMixed) 组合落到三个态")
    func resolveTruthTable() {
        #expect(CheckBoxIndicator.resolve(isOn: false, isMixed: false) == .off)
        #expect(CheckBoxIndicator.resolve(isOn: true, isMixed: false) == .on)
        #expect(CheckBoxIndicator.resolve(isOn: false, isMixed: true) == .mixed)
        #expect(CheckBoxIndicator.resolve(isOn: true, isMixed: true) == .mixed)
    }

    @Test("三个态的 symbol 名两两不同")
    func symbolNamesAreDistinct() {
        let names = CheckBoxIndicator.allCases.map(\.symbolName)
        #expect(
            Set(names).count == CheckBoxIndicator.allCases.count,
            "三个态只给出 \(Set(names).count) 个不同的 symbol 名：\(names)"
        )
    }

    @Test("旧两态的 symbol 名一字未改，mixed 取同族的 minus.square.fill")
    func symbolNamesAreTheSquareFamily() {
        #expect(CheckBoxIndicator.off.symbolName == "square")
        #expect(CheckBoxIndicator.on.symbolName == "checkmark.square.fill")
        #expect(CheckBoxIndicator.mixed.symbolName == "minus.square.fill")
        let offFamily = CheckBoxIndicator.allCases.map(\.symbolName).filter { !$0.contains("square") }
        #expect(offFamily.isEmpty, "指示符离开方框族会与 RadioGroup 的圆族语汇撞车：\(offFamily)")
    }

    @Test("mixed 与 on 同取 contentPrimary（都已作用），off 取 contentSecondary")
    func normalColorsFollowEngagement() {
        #expect(CheckBoxIndicator.mixed.normalColor == Color.contentPrimary)
        #expect(CheckBoxIndicator.on.normalColor == Color.contentPrimary)
        #expect(CheckBoxIndicator.off.normalColor == Color.contentSecondary)
    }

    @Test("符号替换按 MotionPresentation 降级：RM 下 ContentTransition.identity，不描画")
    func symbolReplacementDegradesForCheckBox() {
        #expect(MotionPresentation.animated.symbolReplacement == ContentTransition.symbolEffect(.replace))
        #expect(MotionPresentation.resting.symbolReplacement == ContentTransition.identity)
        #expect(MotionPresentation.hidden.symbolReplacement == ContentTransition.identity)
        #expect(
            MotionPresentation.animated.symbolReplacement != MotionPresentation.resting.symbolReplacement,
            "两档取值相同 ⇒ 上面三条恒真"
        )
    }
}

// MARK: - 渲染辅助 / Rendering helpers

@MainActor
private enum CheckBoxRender {
    static let schemes: [ColorScheme] = [.light, .dark]

    static func pixels(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
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
        guard let image = renderer.cgImage else { return nil }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}

/// 三个态一律由**系统**从一组绑定派生（`Toggle(sources:isOn:)`），不由本库拼装：
/// 判据要证的正是「`configuration.isMixed` 真的被读到了」，自己造一个 mixed 标志就绕开了它。
@MainActor
enum CheckBoxStateSample: CaseIterable, CustomStringConvertible {
    case off
    case mixed
    case on

    var description: String {
        switch self {
        case .off: "off（两个绑定都 false）"
        case .mixed: "mixed（一真一假）"
        case .on: "on（两个绑定都 true）"
        }
    }

    var sources: [Binding<Bool>] {
        switch self {
        case .off: [.constant(false), .constant(false)]
        case .mixed: [.constant(true), .constant(false)]
        case .on: [.constant(true), .constant(true)]
        }
    }

    var view: AnyView {
        AnyView(
            Toggle(sources: self.sources, isOn: \.self) { Text(verbatim: "Accept") }
                .toggleStyle(CheckBoxToggleStyle())
        )
    }

    /// 期望画出的那一个符号，**逐字写死**（不经 `CheckBoxIndicator`）——否则「画的是哪个符号」
    /// 这件事只是自我复述。取色一并写死，因为「三态两两不同」单靠取色就能满足。
    var expectedSymbolName: String {
        switch self {
        case .off: "square"
        case .mixed: "minus.square.fill"
        case .on: "checkmark.square.fill"
        }
    }

    var expectedColor: Color {
        switch self {
        case .off: Color.contentSecondary
        case .mixed, .on: Color.contentPrimary
        }
    }

    /// 同一棵视图树、只把符号与取色换成上面两个字面量。
    func reference(symbolName: String, color: Color) -> AnyView {
        AnyView(
            Toggle(sources: self.sources, isOn: \.self) { Text(verbatim: "Accept") }
                .toggleStyle(FixedSymbolCheckBoxToggleStyle(symbolName: symbolName, color: color))
        )
    }

    var expectedReference: AnyView {
        self.reference(symbolName: self.expectedSymbolName, color: self.expectedColor)
    }
}

// MARK: - 三态真的画出三种样子 / The three states really render differently

@Suite("CheckBox 三态呈现：系统派生的 mixed 与 on / off 都能分辨")
@MainActor
struct CheckBoxMixedRenderTests {
    @Test("三个态两两渲染不同（light / dark，两条腿）")
    func threeStatesRenderDistinctly() {
        for scheme in CheckBoxRender.schemes {
            let frames = CheckBoxStateSample.allCases.map {
                (sample: $0, bytes: CheckBoxRender.pixels($0.view, scheme: scheme))
            }
            for (index, lhs) in frames.enumerated() {
                for rhs in frames[(index + 1)...] {
                    expectBitmapsDiffer(
                        lhs.bytes, rhs.bytes,
                        "\(scheme)：\(lhs.sample) 与 \(rhs.sample) 渲染相同 —— mixed 没被读到，或两态取了同一个 symbol"
                    )
                }
            }
        }
    }

    @Test(
        "每个态画出的就是写死的那个符号 + 取色（light / dark，两条腿）",
        arguments: CheckBoxStateSample.allCases
    )
    func eachStateDrawsItsOwnSymbol(_ sample: CheckBoxStateSample) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(sample.view, scheme: scheme),
                CheckBoxRender.pixels(sample.expectedReference, scheme: scheme),
                "\(sample) \(scheme)：画出的不是 \(sample.expectedSymbolName)"
            )
        }
    }

    @Test("上面那条不是只在比取色：同色下三个符号仍两两不同（light / dark）")
    func symbolsDifferAtIdenticalColor() {
        for scheme in CheckBoxRender.schemes {
            let frames = CheckBoxStateSample.allCases.map {
                (
                    name: $0.expectedSymbolName,
                    bytes: CheckBoxRender.pixels(
                        $0.reference(symbolName: $0.expectedSymbolName, color: Color.contentPrimary),
                        scheme: scheme
                    )
                )
            }
            for (index, lhs) in frames.enumerated() {
                for rhs in frames[(index + 1)...] {
                    expectBitmapsDiffer(
                        lhs.bytes, rhs.bytes,
                        "\(scheme)：\(lhs.name) 与 \(rhs.name) 同色下渲染相同 —— 符号本身分不开，上面那条只在比取色"
                    )
                }
            }
        }
    }

    @Test("两个绑定同值时与单绑定 Toggle 逐像素相同 —— sources 形态没有额外外观", arguments: [false, true])
    func uniformSourcesMatchSingleBinding(_ isOn: Bool) {
        let sample: CheckBoxStateSample = isOn ? .on : .off
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(sample.view, scheme: scheme),
                CheckBoxRender.pixels(
                    Toggle(isOn: .constant(isOn)) { Text(verbatim: "Accept") }
                        .toggleStyle(CheckBoxToggleStyle()),
                    scheme: scheme
                ),
                "\(scheme) isOn=\(isOn)"
            )
        }
    }

    @Test("静息外观与 Reduce Motion 开关无关（三态 × light / dark）", arguments: CheckBoxStateSample.allCases)
    func restingAppearanceIgnoresReduceMotion(_ sample: CheckBoxStateSample) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEquivalent(
                CheckBoxRender.pixels(
                    sample.view.environment(\.coreMotionPresentationOverride, .animated), scheme: scheme
                ),
                CheckBoxRender.pixels(
                    sample.view.environment(\.coreMotionPresentationOverride, .resting), scheme: scheme
                ),
                maxChannelDelta: 1,
                "\(sample) \(scheme)"
            )
        }
    }
}

// MARK: - 旧外观逐像素不变 / Legacy appearance is untouched

@MainActor
enum CheckBoxLegacyCase: CaseIterable, CustomStringConvertible {
    case offNormal
    case onNormal
    case offDisabled
    case onDisabled
    case offInvalid
    case onInvalid

    var description: String {
        switch self {
        case .offNormal: "off/normal"
        case .onNormal: "on/normal"
        case .offDisabled: "off/disabled"
        case .onDisabled: "on/disabled"
        case .offInvalid: "off/invalid"
        case .onInvalid: "on/invalid"
        }
    }

    /// invalid 的指示色是 `statusDangerForeground`（走 asset catalog）—— macOS native 腿上解析为
    /// 全透明，指示符一个像素都不画 ⇒ 「相等」会因为两张都没画出指示符而成立。
    nonisolated static let catalogBoundCases: [CheckBoxLegacyCase] = [.offInvalid, .onInvalid]

    nonisolated static let catalogFreeCases: [CheckBoxLegacyCase] = [
        .offNormal, .onNormal, .offDisabled, .onDisabled,
    ]

    private var isOn: Bool {
        switch self {
        case .onNormal, .onDisabled, .onInvalid: true
        case .offNormal, .offDisabled, .offInvalid: false
        }
    }

    private var isDisabled: Bool {
        switch self {
        case .offDisabled, .onDisabled: true
        default: false
        }
    }

    private var isInvalid: Bool {
        switch self {
        case .offInvalid, .onInvalid: true
        default: false
        }
    }

    private func dressed(_ view: AnyView) -> AnyView {
        var out = view
        if self.isInvalid { out = AnyView(out.fieldValidation(.invalid("Something is wrong."))) }
        if self.isDisabled { out = AnyView(out.disabled(true)) }
        return out
    }

    var current: AnyView {
        self.dressed(AnyView(
            Toggle(isOn: .constant(self.isOn)) { Text(verbatim: "Accept") }
                .toggleStyle(CheckBoxToggleStyle())
        ))
    }

    var legacy: AnyView {
        self.dressed(AnyView(
            Toggle(isOn: .constant(self.isOn)) { Text(verbatim: "Accept") }
                .toggleStyle(LegacyTwoStateCheckBoxToggleStyle())
        ))
    }
}

@Suite("CheckBox 旧外观：off / on × normal / disabled / invalid 与 mixed 之前的实现逐像素一致")
@MainActor
struct CheckBoxLegacyAppearanceTests {
    private static let catalogOnly = """
    跳过：bundle 里没有 Assets.car（SwiftPM native 腿），invalid 的指示色 statusDangerForeground \
    取自 asset catalog、在这条腿上解析为全透明 ⇒ 新旧两张都不画指示符，「相等」会凭空成立。\
    本条在 iOS Simulator 腿上跑。
    """

    @Test("两张参数表恰好是 allCases 的一个划分 —— 漏一格就是一格无人看管")
    func caseListsPartitionAllCases() {
        let listed = CheckBoxLegacyCase.catalogFreeCases + CheckBoxLegacyCase.catalogBoundCases
        #expect(
            listed.map(\.description).sorted() == CheckBoxLegacyCase.allCases.map(\.description).sorted(),
            "参数表 \(listed.map(\.description).sorted()) 与 allCases \(CheckBoxLegacyCase.allCases.map(\.description).sorted()) 不一致"
        )
        #expect(
            Set(CheckBoxLegacyCase.catalogFreeCases.map(\.description))
                .isDisjoint(with: Set(CheckBoxLegacyCase.catalogBoundCases.map(\.description))),
            "两张表有重叠"
        )
    }

    @Test(
        "与 mixed 之前的实现（ce20fad 原样拷贝）逐像素一致（light / dark）",
        arguments: CheckBoxLegacyCase.catalogFreeCases
    )
    func matchesLegacy(_ sample: CheckBoxLegacyCase) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(sample.current, scheme: scheme),
                CheckBoxRender.pixels(sample.legacy, scheme: scheme),
                "\(sample) \(scheme)"
            )
        }
    }

    @Test(
        "invalid 两格同样逐像素一致（只在编译过 catalog 的那条腿上）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly)),
        arguments: CheckBoxLegacyCase.catalogBoundCases
    )
    func matchesLegacyUnderInvalid(_ sample: CheckBoxLegacyCase) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(sample.current, scheme: scheme),
                CheckBoxRender.pixels(sample.legacy, scheme: scheme),
                "\(sample) \(scheme)"
            )
        }
    }

    @Test("上面那两条不是恒真的：六格里每一格都与 off/normal 之外的某一格画得不一样")
    func legacyCasesAreNotAllIdentical() {
        let frames = CheckBoxLegacyCase.allCases.map {
            (sample: $0, bytes: CheckBoxRender.pixels($0.current, scheme: .light))
        }
        let distinct = Set(frames.compactMap(\.bytes))
        #expect(
            distinct.count >= 4,
            "六格只画出 \(distinct.count) 种不同位图 —— 逐像素相等的判据有一部分是恒真的"
        )
    }

    @Test("invalid 那两格真的与 normal 不同（否则 catalog 门控之外的格子已覆盖它）")
    func invalidDiffersFromNormal() {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsDiffer(
                CheckBoxRender.pixels(CheckBoxLegacyCase.onInvalid.current, scheme: scheme),
                CheckBoxRender.pixels(CheckBoxLegacyCase.onNormal.current, scheme: scheme),
                "\(scheme)：invalid 与 normal 渲染相同"
            )
        }
    }
}

// MARK: - 符号 / 取色写死的参照样式 / Fixed-symbol reference style

private struct FixedSymbolCheckBoxToggleStyle: ToggleStyle {
    let symbolName: String
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: self.symbolName)
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(self.color)
            configuration.label
                .fieldAccessibilityHint()
        }
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
    }
}

// MARK: - 旧实现原样拷贝（ce20fad）/ Legacy copy

private struct LegacyTwoStateCheckBoxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        LegacyTwoStateCheckBoxBody(configuration: configuration)
    }
}

private struct LegacyTwoStateCheckBoxBody: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fieldValidation) private var validation
    @Environment(\.coreMotionPresentation) private var motionPresentation

    var body: some View {
        let appearance = FieldAppearance.resolve(isEnabled: self.isEnabled, validation: self.validation, isFocused: false)
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: self.configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(appearance.indicatorColor(
                    normal: self.configuration.isOn ? Color.contentPrimary : Color.contentSecondary
                ))
                .contentTransition(self.motionPresentation.symbolReplacement)
            self.configuration.label
                .fieldAccessibilityHint()
        }
        .opacity(appearance.controlOpacity)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .coreAnimation(.selection, value: self.configuration.isOn)
        .onTapGesture {
            self.configuration.isOn.toggle()
        }
    }
}
