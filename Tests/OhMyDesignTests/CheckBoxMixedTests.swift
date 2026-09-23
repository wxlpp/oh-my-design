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

    // `.coreAnimation(.selection, value: indicator)` 的触发靠的正是这个 `==`：
    // 自定义成恒等（`static func == (_, _) -> Bool { true }`）时真值表、符号名、静息截图
    // 全部照绿，而动画从此分辨不出任何两个状态、永不触发。这条是那个缺口的唯一网。
    @Test("三个态在 Equatable 下两两不等 —— 动画触发值的承重判据")
    func statesArePairwiseUnequal() {
        let cases = CheckBoxIndicator.allCases
        #expect(cases.count == 3, "只枚举到 \(cases.count) 个态 —— 下面的两两比较会缩水")
        var unequalPairs = 0
        for (index, lhs) in cases.enumerated() {
            for rhs in cases[(index + 1)...] {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 相等 —— .animation(value:) 分辨不出这次状态切换")
                if lhs != rhs { unequalPairs += 1 }
            }
            #expect(lhs == lhs, "\(lhs) 与自身不等 —— 相等关系坏了，动画会每帧重启")
        }
        #expect(unequalPairs == 3, "只有 \(unequalPairs) 对互异，期望 3")
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

    // 本条只证公共辅助值 `MotionPresentation.symbolReplacement` 的降级，**不证** CheckBox 那条
    // 消费链路——链路由 `CoreMotionTokenDisciplineGuard.transformLedger` 的逐调用点台账看着，
    // 所以下面第二段把台账键一并钉住：台账键被删时本 suite 也红，源码调用被删时那条判据红。
    @Test("符号替换按 MotionPresentation 降级；CheckBox 的消费点在动效台账里")
    func symbolReplacementDegradesAndIsLedgered() {
        #expect(MotionPresentation.animated.symbolReplacement == ContentTransition.symbolEffect(.replace))
        #expect(MotionPresentation.resting.symbolReplacement == ContentTransition.identity)
        #expect(MotionPresentation.hidden.symbolReplacement == ContentTransition.identity)
        #expect(
            MotionPresentation.animated.symbolReplacement != MotionPresentation.resting.symbolReplacement,
            "两档取值相同 ⇒ 上面三条恒真"
        )

        let key = "Components/CheckBox/CheckBox.swift|contentTransition(self.motionPresentation.symbolReplacement)"
        #expect(
            CoreMotionTokenDisciplineGuard.transformLedger[key] != nil,
            "动效台账里找不到 CheckBox 的 contentTransition 调用点键「\(key)」—— 那条链路失去机器兜底"
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

// MARK: - 三态样本（由系统派生）/ Tri-state samples, derived by the system

// 三个态一律由系统从一组绑定派生（`Toggle(sources:isOn:)`）：判据要证的正是
// 「`configuration.isMixed` 真的被读到了」，自己造一个 mixed 标志就绕开了它。
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

    // 期望值**逐字写死**，不经 `CheckBoxIndicator`——否则「画的是哪个符号」只是自我复述。
    var expectedSymbolName: String {
        switch self {
        case .off: "square"
        case .mixed: "minus.square.fill"
        case .on: "checkmark.square.fill"
        }
    }

    var expectedNormalColor: Color {
        switch self {
        case .off: Color.contentSecondary
        case .mixed, .on: Color.contentPrimary
        }
    }

    func reference(symbolName: String, color: Color, opacity: Double) -> AnyView {
        AnyView(
            Toggle(sources: self.sources, isOn: \.self) { Text(verbatim: "Accept") }
                .toggleStyle(FixedSymbolCheckBoxToggleStyle(
                    symbolName: symbolName, color: color, opacity: opacity
                ))
        )
    }
}

@MainActor
enum CheckBoxAppearanceCase: CaseIterable, CustomStringConvertible {
    case normal
    case disabled
    case invalid

    // invalid 的指示色是 `statusDangerForeground`（走 asset catalog）—— macOS native 腿上解析为
    // 全透明、指示符一个像素都不画 ⇒ 任何拿它做对照的位图判据在那条腿上都向绿失效。
    nonisolated static let catalogFree: [CheckBoxAppearanceCase] = [.normal, .disabled]

    nonisolated static let catalogBound: [CheckBoxAppearanceCase] = [.invalid]

    var description: String {
        switch self {
        case .normal: "normal"
        case .disabled: "disabled"
        case .invalid: "invalid"
        }
    }

    func dressed(_ view: AnyView) -> AnyView {
        switch self {
        case .normal: view
        case .disabled: AnyView(view.disabled(true))
        case .invalid: AnyView(view.fieldValidation(.invalid("Something is wrong.")))
        }
    }

    var expectedOpacity: Double {
        self == .disabled ? FieldAppearance.disabledControlOpacity : 1
    }

    func expectedColor(normal: Color) -> Color {
        self == .invalid ? Color.statusDangerForeground : normal
    }
}

@MainActor
struct CheckBoxCell: CustomStringConvertible, Sendable {
    let state: CheckBoxStateSample
    let appearance: CheckBoxAppearanceCase

    nonisolated static let catalogFreeCells: [CheckBoxCell] = CheckBoxStateSample.allCases
        .flatMap { state in CheckBoxAppearanceCase.catalogFree.map { CheckBoxCell(state: state, appearance: $0) } }

    nonisolated static let catalogBoundCells: [CheckBoxCell] = CheckBoxStateSample.allCases
        .flatMap { state in CheckBoxAppearanceCase.catalogBound.map { CheckBoxCell(state: state, appearance: $0) } }

    nonisolated static let allCells: [CheckBoxCell] = CheckBoxStateSample.allCases
        .flatMap { state in CheckBoxAppearanceCase.allCases.map { CheckBoxCell(state: state, appearance: $0) } }

    var description: String { "\(self.state) / \(self.appearance)" }

    var current: AnyView { self.appearance.dressed(self.state.view) }

    var expectedReference: AnyView {
        self.appearance.dressed(self.state.reference(
            symbolName: self.state.expectedSymbolName,
            color: self.appearance.expectedColor(normal: self.state.expectedNormalColor),
            opacity: self.appearance.expectedOpacity
        ))
    }
}

// MARK: - 三态真的画出三种样子 / The three states really render differently

@Suite("CheckBox 三态呈现：系统派生的 mixed 与 on / off 都能分辨")
@MainActor
struct CheckBoxMixedRenderTests {
    private static let catalogOnly = """
    跳过：bundle 里没有 Assets.car（SwiftPM native 腿），invalid 的指示色 statusDangerForeground \
    取自 asset catalog、在这条腿上解析为全透明 ⇒ 指示符一个像素都不画，位图对照会向绿失效。\
    本条在 iOS Simulator 腿上跑。
    """

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

    @Test("三张单元格表恰好是「三态 × 三外观」的一个划分 —— 漏一格就是一格无人看管")
    func cellListsPartitionAllCells() {
        let listed = (CheckBoxCell.catalogFreeCells + CheckBoxCell.catalogBoundCells).map(\.description).sorted()
        #expect(
            listed == CheckBoxCell.allCells.map(\.description).sorted(),
            "参数表 \(listed) 与全集 \(CheckBoxCell.allCells.map(\.description).sorted()) 不一致"
        )
        #expect(CheckBoxCell.allCells.count == 9, "全集只有 \(CheckBoxCell.allCells.count) 格，期望 3 态 × 3 外观 = 9")
        #expect(
            Set(CheckBoxCell.catalogFreeCells.map(\.description))
                .isDisjoint(with: Set(CheckBoxCell.catalogBoundCells.map(\.description))),
            "两张表有重叠"
        )
    }

    @Test(
        "每格画出的就是写死的那个符号 + 取色 + 不透明度（light / dark，两条腿）",
        arguments: CheckBoxCell.catalogFreeCells
    )
    func eachCellDrawsItsOwnSymbol(_ cell: CheckBoxCell) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(cell.current, scheme: scheme),
                CheckBoxRender.pixels(cell.expectedReference, scheme: scheme),
                "\(cell) \(scheme)：画出的不是 \(cell.state.expectedSymbolName)"
            )
        }
    }

    @Test(
        "invalid 三格同样对得上写死的期望（三态共用取色通路，mixed 没有例外）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly)),
        arguments: CheckBoxCell.catalogBoundCells
    )
    func eachInvalidCellDrawsItsOwnSymbol(_ cell: CheckBoxCell) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsEqual(
                CheckBoxRender.pixels(cell.current, scheme: scheme),
                CheckBoxRender.pixels(cell.expectedReference, scheme: scheme),
                "\(cell) \(scheme)：画出的不是 \(cell.state.expectedSymbolName) + statusDangerForeground"
            )
        }
    }

    @Test(
        "invalid 的期望参照与 normal 的期望参照画得不一样 —— 上面那条不是恒真的",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly)),
        arguments: CheckBoxStateSample.allCases
    )
    func invalidReferenceDiffersFromNormal(_ state: CheckBoxStateSample) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsDiffer(
                CheckBoxRender.pixels(CheckBoxCell(state: state, appearance: .invalid).current, scheme: scheme),
                CheckBoxRender.pixels(CheckBoxCell(state: state, appearance: .normal).current, scheme: scheme),
                "\(state) \(scheme)：invalid 与 normal 渲染相同"
            )
        }
    }

    @Test("上面那几条不是只在比取色：同色下三个符号仍两两不同（light / dark）")
    func symbolsDifferAtIdenticalColor() {
        for scheme in CheckBoxRender.schemes {
            let frames = CheckBoxStateSample.allCases.map {
                (
                    name: $0.expectedSymbolName,
                    bytes: CheckBoxRender.pixels(
                        $0.reference(symbolName: $0.expectedSymbolName, color: Color.contentPrimary, opacity: 1),
                        scheme: scheme
                    )
                )
            }
            for (index, lhs) in frames.enumerated() {
                for rhs in frames[(index + 1)...] {
                    expectBitmapsDiffer(
                        lhs.bytes, rhs.bytes,
                        "\(scheme)：\(lhs.name) 与 \(rhs.name) 同色下渲染相同 —— 符号本身分不开，上面那几条只在比取色"
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

// MARK: - mixed 下的 isOn 与点击写回方向 / isOn under mixed, and click write-back

@MainActor
final class BoolPairBox {
    var values: [Bool]

    init(_ values: [Bool]) {
        self.values = values
    }

    var bindings: [Binding<Bool>] {
        (0..<self.values.count).map { index in
            Binding(get: { self.values[index] }, set: { self.values[index] = $0 })
        }
    }
}

@MainActor
final class ToggleConfigurationSink {
    var captured: ToggleStyleConfiguration?
}

@Suite("mixed 下 configuration.isOn 的取值与点击写回方向（可写绑定，非 .constant）")
@MainActor
struct CheckBoxMixedWriteBackTests {
    private static func capture(_ initial: [Bool]) -> (box: BoolPairBox, configuration: ToggleStyleConfiguration?) {
        let box = BoolPairBox(initial)
        let sink = ToggleConfigurationSink()
        _ = CheckBoxRender.pixels(
            Toggle(sources: box.bindings, isOn: \.self) { Text(verbatim: "Accept") }
                .toggleStyle(ToggleConfigurationProbe(sink: sink)),
            scheme: .light
        )
        return (box, sink.captured)
    }

    // 实测读数（两种混合顺序各一遍）：mixed 下 `configuration.isOn` 为 `false`，
    // `isOn.toggle()` 把整组绑定写成全 `true`（= PRD 真值表里的「点 mixed 父节点 ⇒ 全选」）。
    @Test("mixed 下 isOn == false，toggle() 后整组绑定全为 true", arguments: [[true, false], [false, true]])
    func mixedIsOnIsFalseAndToggleSelectsAll(_ initial: [Bool]) throws {
        let captured = Self.capture(initial)
        let configuration = try #require(
            captured.configuration, "探针没拿到 configuration —— ImageRenderer 没有求值 makeBody，本条无法下结论"
        )
        #expect(configuration.isMixed, "初值 \(initial) 一真一假，却不是 mixed")
        #expect(configuration.isOn == false, "mixed 下 configuration.isOn 实测为 \(configuration.isOn)")
        configuration.$isOn.wrappedValue.toggle()
        #expect(
            captured.box.values == [true, true],
            "点一下之后那组绑定是 \(captured.box.values)，期望全选 [true, true]"
        )
    }

    @Test("对照：全 false 的一组不是 mixed，toggle() 同样写成全 true")
    func uniformOffIsNotMixed() throws {
        let captured = Self.capture([false, false])
        let configuration = try #require(captured.configuration, "探针没拿到 configuration")
        #expect(!configuration.isMixed, "两个绑定都 false 却判成 mixed")
        #expect(configuration.isOn == false)
        configuration.$isOn.wrappedValue.toggle()
        #expect(captured.box.values == [true, true], "实测 \(captured.box.values)")
    }

    @Test("对照：全 true 的一组不是 mixed，toggle() 写成全 false —— 证明写回是双向的")
    func uniformOnIsNotMixed() throws {
        let captured = Self.capture([true, true])
        let configuration = try #require(captured.configuration, "探针没拿到 configuration")
        #expect(!configuration.isMixed, "两个绑定都 true 却判成 mixed")
        #expect(configuration.isOn == true)
        configuration.$isOn.wrappedValue.toggle()
        #expect(captured.box.values == [false, false], "实测 \(captured.box.values)")
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

    private var appearance: CheckBoxAppearanceCase {
        switch self {
        case .offNormal, .onNormal: .normal
        case .offDisabled, .onDisabled: .disabled
        case .offInvalid, .onInvalid: .invalid
        }
    }

    var current: AnyView {
        self.appearance.dressed(AnyView(
            Toggle(isOn: .constant(self.isOn)) { Text(verbatim: "Accept") }
                .toggleStyle(CheckBoxToggleStyle())
        ))
    }

    var legacy: AnyView {
        self.appearance.dressed(AnyView(
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

    @Test("catalog 门控之外的四格两两画得不一样 —— 上面逐像素相等的判据不是恒真的")
    func catalogFreeCasesArePairwiseDistinct() {
        for scheme in CheckBoxRender.schemes {
            let frames = CheckBoxLegacyCase.catalogFreeCases.map {
                (sample: $0, bytes: CheckBoxRender.pixels($0.current, scheme: scheme))
            }
            #expect(frames.count == 4, "只取到 \(frames.count) 格，期望 4")
            for (index, lhs) in frames.enumerated() {
                for rhs in frames[(index + 1)...] {
                    expectBitmapsDiffer(
                        lhs.bytes, rhs.bytes,
                        "\(scheme)：\(lhs.sample) 与 \(rhs.sample) 渲染相同 —— 对应那格的逐像素相等是恒真的"
                    )
                }
            }
        }
    }

    @Test(
        "invalid 两格与同状态的 normal 画得不一样（只在编译过 catalog 的那条腿上）",
        .enabled(if: assetCatalogIsCompiled, Comment(rawValue: Self.catalogOnly)),
        arguments: [
            (CheckBoxLegacyCase.offInvalid, CheckBoxLegacyCase.offNormal),
            (CheckBoxLegacyCase.onInvalid, CheckBoxLegacyCase.onNormal),
        ]
    )
    func invalidDiffersFromNormal(_ pair: (invalid: CheckBoxLegacyCase, normal: CheckBoxLegacyCase)) {
        for scheme in CheckBoxRender.schemes {
            expectBitmapsDiffer(
                CheckBoxRender.pixels(pair.invalid.current, scheme: scheme),
                CheckBoxRender.pixels(pair.normal.current, scheme: scheme),
                "\(scheme)：\(pair.invalid) 与 \(pair.normal) 渲染相同"
            )
        }
    }
}

// MARK: - 符号 / 取色写死的参照样式 / Fixed-symbol reference style

// 刻意不读 `CheckBoxIndicator` / `FieldAppearance`：符号、取色、不透明度全部由调用方以
// 字面量传入。谁把它「简化」成复用生产枚举，这套判据就退化成自我复述。
private struct FixedSymbolCheckBoxToggleStyle: ToggleStyle {
    let symbolName: String
    let color: Color
    let opacity: Double

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: self.symbolName)
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(self.color)
            configuration.label
                .fieldAccessibilityHint()
        }
        .opacity(self.opacity)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
    }
}

private struct ToggleConfigurationProbe: ToggleStyle {
    let sink: ToggleConfigurationSink

    func makeBody(configuration: Configuration) -> some View {
        ToggleConfigurationProbeBody(configuration: configuration, sink: self.sink)
    }
}

private struct ToggleConfigurationProbeBody: View {
    let configuration: ToggleStyleConfiguration
    let sink: ToggleConfigurationSink

    var body: some View {
        self.sink.captured = self.configuration
        return HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: "square")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
            self.configuration.label
        }
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
