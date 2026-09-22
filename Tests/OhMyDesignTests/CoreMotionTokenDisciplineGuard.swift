import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 核心库动效纪律 / Core motion discipline

/// 核心库动效纪律的源码判据（SwiftSyntax 逐调用点）。
///
/// 覆盖：`withAnimation` / `withTransaction` / `Transaction(animation:)` / `.transaction { }` /
/// `animation(_:value:)`（带或不带前导点）/ `x.animation = …` 赋值 / `Animation` 类型或构造的存储值，
/// 每个调用点必须引用 `CoreMotionToken`（或恰为 `nil`）；位移 / 缩放 / 旋转 / matchedGeometry 调用点逐点登记门控理由。
///
/// 不覆盖（已知）：实参里任何位置提到 `CoreMotionToken` 即放行，同一表达式的另一分支若给出系统曲线
/// （如 `flag ? CoreMotionToken.press.animation : .spring`，`.spring` 不带括号时字面量表也抓不到）照样通过；
/// `phaseAnimator` / `keyframeAnimator` 的 `animation:` 闭包；经 `.modifier(…)` / `GeometryEffect` /
/// `visualEffect` 施加的变换；`.transition(…)` 未逐点登记（只在 fadeOnly 文件里禁 move / scale）；
/// 布局尺寸变化被动画插值产生的位移。台账键是调用点实参的归一化文本，改写实参即须同步台账。
@Suite("核心库动效纪律：动画只经 CoreMotionToken 取、含动效的文件登记 Reduce Motion 策略")
struct CoreMotionTokenDisciplineGuard {
    enum Strategy: Sendable {
        case tokenSource
        case gated
        case fadeOnly
        case staticTransform
    }

    static let tokenFile = "Tokens/CoreMotionToken.swift"

    static let ledger: [String: Strategy] = [
        "Tokens/CoreMotionToken.swift": .tokenSource,
        "Modifier/ButtonBackgroundModifier.swift": .gated,
        "Modifier/TelegramGlassButtonModifier.swift": .gated,
        "Modifier/SpinningModifier.swift": .gated,
        "Components/Button/styles/PressableButtonStyles.swift": .gated,
        "Components/Button/styles/CoreBorderlessButtonStyle.swift": .fadeOnly,
        "Components/Button/AsyncButton.swift": .fadeOnly,
        "Components/CheckBox/CheckBox.swift": .fadeOnly,
        "Components/Radio/Radio.swift": .fadeOnly,
        "Components/FormField/FormField.swift": .fadeOnly,
        "Components/Skeleton/Skeleton.swift": .gated,
        "Components/Toast/Toast.swift": .gated,
        "Components/TabBar/UnderlinedTabBar.swift": .gated,
        "Components/SegmentedControl/SegmentedControl.swift": .gated,
        "Components/Style/CoreDisclosureGroupStyle.swift": .gated,
        "Components/Style/CoreCircularProgressViewStyle.swift": .staticTransform,
        "Components/Carousel/Carousel.swift": .gated,
        "Components/TagInput/TagInput.swift": .gated,
        "Components/TagGroup/TagGroup.swift": .gated,
    ]

    static let transformLedger: [String: String] = [
        "Tokens/CoreMotionToken.swift|scaleEffect(Self.scale(for: self.presentation, phase: phase))":
            "CollectionItemTransition.scale(for:phase:) 在 resting / hidden 下每一相都是 1",
        "Components/Button/styles/PressableButtonStyles.swift|scaleEffect(feedback.scale)":
            "feedback 取自 PressFeedback.card(presentation:)，resting 下 scale = 1",
        "Modifier/ButtonBackgroundModifier.swift|scaleEffect(feedback.scale)":
            "feedback 取自 PressFeedback.chrome(presentation:)，resting 下 scale = 1",
        "Modifier/TelegramGlassButtonModifier.swift|scaleEffect(feedback.scale)":
            "feedback 取自 PressFeedback.chrome(presentation:)，resting 下 scale = 1",
        "Components/SegmentedControl/SegmentedControl.swift|matchedGeometryEffect(id: self.motionPresentation.slidingIndicatorID( \"SegmentedControl.thumb\", slot: AnyHashable(segment.index) ), in: self.namespace)":
            "resting 下每槽各自 ID，不滑",
        "Components/TabBar/UnderlinedTabBar.swift|matchedGeometryEffect(id: self.motionPresentation.slidingIndicatorID(\"underline\", slot: self.slot), in: self.namespace)":
            "resting 下每槽各自 ID，不滑",
        "Components/Skeleton/Skeleton.swift|offset(x: SkeletonShimmerMath.offset(at: timeline.date, width: width))":
            "只在 motionPresentation == .animated 的分支里建",
        "Components/Style/CoreCircularProgressViewStyle.swift|rotationEffect(.degrees(-90))":
            "常量变换，无动画",
        "Components/Style/CoreDisclosureGroupStyle.swift|rotationEffect(.degrees(self.rotation))":
            "补间走 CoreMotionToken.reveal.transformAnimation(for:)，resting 下不补间",
        "Components/Toast/Toast.swift|scaleEffect(Self.dismissScale( presentation: self.presentation, isDismissing: self.isDismissing, motion: self.motionPresentation ))":
            "dismissScale 在 resting 下恒为 1",
        "Components/Toast/Toast.swift|offset(y: self.verticalOffset)":
            "拖动跟手；退场位移经 dismissOffset(motion:releasedAt:)，resting 下停在松手位置",
        "Modifier/SpinningModifier.swift|offset(x: Self.offset(at: context.date, trackWidth: proxy.size.width))":
            "只在 TopBarIndicator.sweeps(for:) 为真（animated）的分支里建",
        "Modifier/SpinningModifier.swift|offset(x: Self.restingOffset(trackWidth: proxy.size.width))":
            "静止位，无动画",
    ]

    static let animationTriggers = [
        "withAnimation", "withTransaction", ".transaction", ".animation(", ".transition(", ".coreAnimation(",
        "TimelineView(", "phaseAnimator(", "keyframeAnimator(",
        "symbolEffect(", "contentTransition(", "matchedGeometryEffect(",
    ]

    static let transformCalls = [
        "scaleEffect(", "rotationEffect(", "rotation3DEffect(", "offset(",
        "matchedGeometryEffect(", ".move(edge", ".scale(", ".scale)", ".slide", ".push(",
        "symbolEffect(", "contentTransition(", "phaseAnimator(", "keyframeAnimator(", "TimelineView(",
    ]

    static let curveLiterals = [
        ".snappy", ".smooth", ".bouncy", ".spring(", ".spring)", ".interactiveSpring",
        ".easeIn", ".easeOut", ".linear(", ".linear)", "Animation.default", ".animation(.default",
    ]

    static let presentationEntry = "\\.coreMotionPresentation"

    // MARK: - 纯扫描器（供合成输入自证）

    static func stripComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let r = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<r.lowerBound])
            }
            .joined(separator: "\n")
    }

    static func hasMotion(_ code: String) -> Bool {
        (Self.animationTriggers + Self.transformCalls).contains { code.contains($0) }
    }

    static func callArguments(of name: String, in code: String) -> [(line: Int, args: String?)] {
        let chars = Array(code)
        var out: [(Int, String?)] = []
        var searchStart = code.startIndex
        while let r = code.range(of: name, range: searchStart..<code.endIndex) {
            searchStart = r.upperBound
            if r.lowerBound > code.startIndex {
                let before = code[code.index(before: r.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            let line = code[code.startIndex..<r.lowerBound].filter { $0 == "\n" }.count + 1
            var k = code.distance(from: code.startIndex, to: r.upperBound)
            if name.hasSuffix("(") {
                k -= 1
            } else {
                while k < chars.count, chars[k] == " " { k += 1 }
                guard k < chars.count, chars[k] == "(" else {
                    out.append((line, nil))
                    continue
                }
            }
            let open = k
            var depth = 0
            while k < chars.count {
                if chars[k] == "(" { depth += 1 } else if chars[k] == ")" {
                    depth -= 1
                    if depth == 0 { break }
                }
                k += 1
            }
            out.append((line, String(chars[(open + 1)..<min(k, chars.count)])))
        }
        return out
    }

    static func curveViolations(path: String, code: String) -> [String] {
        guard path != Self.tokenFile else { return [] }
        let sites = MotionSiteCollector.collect(code)
        var out: [String] = []
        for site in sites.animationSites + sites.assignments {
            let text = site.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.contains("CoreMotionToken") && text != "nil" {
                out.append("\(path):\(site.line) \(site.kind)(\(text)) 的曲线不经 CoreMotionToken")
            }
        }
        for site in sites.animationDecls where !site.text.contains("CoreMotionToken") {
            out.append("\(path):\(site.line) 声明了 Animation 类型的值（\(site.text)）—— 曲线只许经 CoreMotionToken 取")
        }
        for literal in Self.curveLiterals where code.contains(literal) {
            out.append("\(path) 出现曲线字面量 `\(literal)` —— 曲线只许在 \(Self.tokenFile) 里定义")
        }
        return out
    }

    static func transformSiteKeys(path: String, code: String) -> [String] {
        MotionSiteCollector.collect(code).transformSites.map { "\(path)|\($0.kind)(\($0.text))" }
    }

    static func strategyViolations(path: String, code: String, strategy: Strategy?) -> [String] {
        let motion = Self.hasMotion(code)
        guard let strategy else {
            return motion ? ["\(path) 含动效却不在台账里 —— 登记它的 Reduce Motion 策略"] : []
        }
        var out: [String] = []
        if !motion && strategy != .tokenSource {
            out.append("\(path) 在台账里，却已不含任何动效 —— 从台账删掉")
        }
        if strategy != .tokenSource && code.contains("accessibilityReduceMotion") {
            out.append("\(path) 直接读 accessibilityReduceMotion —— 改经 \(Self.presentationEntry)")
        }
        switch strategy {
        case .tokenSource:
            break
        case .gated:
            if !code.contains(Self.presentationEntry) {
                out.append("\(path) 登记为 gated，却不读 \(Self.presentationEntry)")
            }
        case .fadeOnly:
            for call in Self.transformCalls where code.contains(call) {
                out.append("\(path) 登记为 fadeOnly，却出现位移 / 缩放 / 旋转类调用 `\(call)`")
            }
        case .staticTransform:
            for trigger in Self.animationTriggers where code.contains(trigger) {
                out.append("\(path) 登记为 staticTransform（常量变换），却出现动画触发 `\(trigger)`")
            }
        }
        return out
    }

    // MARK: - 真实扫描

    static func coreSources() -> [(path: String, code: String)] {
        let root = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
        return GuardScanRoots.swiftFiles(in: root).compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (GuardScanRoots.relativePath(url, from: root), Self.stripComments(text))
        }
        .sorted { $0.path < $1.path }
    }

    @Test("核心库的动画曲线只经 CoreMotionToken 取")
    func curvesComeFromCoreMotionToken() {
        let sources = Self.coreSources()
        #expect(sources.count > 50, "只扫到 \(sources.count) 个文件 —— 扫描根不对，零违规不作数")
        let offenders = sources.flatMap { Self.curveViolations(path: $0.path, code: $0.code) }
        #expect(offenders.isEmpty, "\n\(offenders.joined(separator: "\n"))")
    }

    @Test("含动效的文件都登记了 Reduce Motion 策略，且策略与源码相符（双向）")
    func motionFilesAreRegistered() {
        let sources = Self.coreSources()
        let paths = Set(sources.map(\.path))
        let stale = Set(Self.ledger.keys).subtracting(paths)
        #expect(stale.isEmpty, "台账里有已不存在的文件：\(stale.sorted())")
        let offenders = sources.flatMap {
            Self.strategyViolations(path: $0.path, code: $0.code, strategy: Self.ledger[$0.path])
        }
        #expect(offenders.isEmpty, "\n\(offenders.joined(separator: "\n"))")
        let motionFiles = Set(sources.filter { Self.hasMotion($0.code) }.map(\.path))
        #expect(motionFiles == Set(Self.ledger.keys), "台账 \(Self.ledger.keys.sorted()) 与实际含动效文件 \(motionFiles.sorted()) 不一致")
    }

    static func transformLedgerViolations(sites: [String], ledger: [String: String]) -> [String] {
        let actual = Set(sites)
        let unregistered = actual.subtracting(ledger.keys).sorted().map { "未登记的位移 / 缩放 / 旋转调用点：\($0)" }
        let stale = Set(ledger.keys).subtracting(actual).sorted().map { "台账里的调用点已不存在：\($0)" }
        return unregistered + stale
    }

    @Test("每个位移 / 缩放 / 旋转调用点都逐点登记了 Reduce Motion 门控（双向）")
    func transformSitesAreRegistered() {
        let sites = Self.coreSources().flatMap { Self.transformSiteKeys(path: $0.path, code: $0.code) }
        #expect(sites.count >= Self.transformLedger.count, "只扫到 \(sites.count) 个调用点 —— 扫描器失灵")
        let offenders = Self.transformLedgerViolations(sites: sites, ledger: Self.transformLedger)
        #expect(offenders.isEmpty, "\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: - 自证：合成输入必须打红

    @Test("自证：扫描器对每一种违规形态都判红")
    func scannerCatchesSyntheticViolations() {
        let path = "Components/Fake/Fake.swift"
        #expect(!Self.curveViolations(path: path, code: "x.animation(.easeOut(duration: 0.2), value: v)").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "withAnimation {\n  v = 1\n}").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "withAnimation(.snappy) { v = 1 }").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "let a: Animation = .smooth\nwithAnimation(a) { }").isEmpty)
        #expect(!Self.curveViolations(path: path, code: ".animation(.default, value: v)").isEmpty)
        #expect(Self.curveViolations(path: path, code: "withAnimation(CoreMotionToken.press.animation(for: p)) { }").isEmpty)
        #expect(Self.curveViolations(path: path, code: ".animation(nil, value: v)").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "foo().animation(.easeInOut, value: v)").isEmpty,
                "链在调用结果后的 .animation 仍是修饰符，必须检查")
        #expect(Self.curveViolations(path: Self.tokenFile, code: ".snappy(duration: 0.16)").isEmpty)

        #expect(!Self.strategyViolations(path: path, code: ".scaleEffect(0.9)", strategy: nil).isEmpty,
                "未登记的含动效文件必须判红")
        #expect(!Self.strategyViolations(path: path, code: ".coreAnimation(.press, value: v)\n.scaleEffect(s)", strategy: .fadeOnly).isEmpty,
                "fadeOnly 里混进缩放必须判红")
        #expect(!Self.strategyViolations(path: path, code: ".transition(.move(edge: .top))", strategy: .fadeOnly).isEmpty,
                "fadeOnly 里混进 move 转场必须判红")
        #expect(!Self.strategyViolations(path: path, code: ".scaleEffect(s)", strategy: .gated).isEmpty,
                "gated 却不读入口必须判红")
        #expect(!Self.strategyViolations(
            path: path,
            code: "@Environment(\\.coreMotionPresentation) var m\n@Environment(\\.accessibilityReduceMotion) var r\n.scaleEffect(s)",
            strategy: .gated
        ).isEmpty, "绕过入口直接读 RM 必须判红")
        #expect(!Self.strategyViolations(path: path, code: ".rotationEffect(.degrees(-90))\n.animation(x, value: v)", strategy: .staticTransform).isEmpty,
                "staticTransform 里出现动画触发必须判红")
        #expect(!Self.strategyViolations(path: path, code: "let x = 1", strategy: .gated).isEmpty,
                "台账里的文件已无动效必须判红")
        let ungated = "@Environment(\\.coreMotionPresentation) var m\nvar body: some View { x.scaleEffect(s) }"
        #expect(!Self.transformLedgerViolations(
            sites: Self.transformSiteKeys(path: path, code: ungated), ledger: [:]
        ).isEmpty, "只读入口、却无条件缩放的 gated 文件必须判红（逐点台账）")
        #expect(Self.transformLedgerViolations(
            sites: Self.transformSiteKeys(path: path, code: ungated), ledger: ["\(path)|scaleEffect(s)": "测试"]
        ).isEmpty)
        #expect(Self.transformSiteKeys(path: path, code: "let y = Math.offset(at: d)").isEmpty, "类型上的纯函数不是变换调用点")
    }

    @Test("自证：已知的绕过写法逐条判红")
    func scannerCatchesKnownBypasses() {
        let path = "Components/Fake/Fake.swift"
        let bypasses: [(String, String)] = [
            ("transaction 闭包", "x.transaction { $0.animation = a }"),
            ("transaction 赋字面量", "x.transaction { t in t.animation = .easeIn }"),
            ("withTransaction", "withTransaction(Transaction(animation: a)) { v = 1 }"),
            ("Transaction 构造", "var t = Transaction(animation: a)"),
            ("存储的 Animation 值", "let a: Animation = .default"),
            ("存储的可选 Animation 值", "var a: Animation? = nil"),
            ("Animation 构造值", "let a = Animation.easeIn(duration: 1)"),
            ("隐式 self 的 animation", "extension View { func f() -> some View { animation(a, value: 1) } }"),
            ("nil ?? a", "x.animation(nil ?? a, value: v)"),
            ("无参 withAnimation", "withAnimation { v = 1 }"),
        ]
        for (name, code) in bypasses {
            #expect(!Self.curveViolations(path: path, code: code).isEmpty, "绕过写法没被抓住：\(name) —— \(code)")
        }
        let allowed = [
            "x.transaction { $0.animation = CoreMotionToken.press.animation }",
            "withTransaction(Transaction(animation: CoreMotionToken.press.animation)) { }",
            "let a = CoreMotionToken.press.animation(for: p)",
            "x.animation(nil, value: v)",
            "x.animation(CoreMotionToken.press.animation(for: p), value: v)",
        ]
        for code in allowed {
            #expect(Self.curveViolations(path: path, code: code).isEmpty, "合规写法被误判：\(code)")
        }
    }
}

// MARK: - 调用点收集 / Call-site collection

nonisolated final class MotionSiteCollector: SyntaxVisitor {
    struct Site: Sendable {
        let line: Int
        let kind: String
        let text: String
    }

    static let transformCallees: Set<String> = [
        "scaleEffect", "rotationEffect", "rotation3DEffect", "offset",
        "matchedGeometryEffect", "transformEffect", "projectionEffect",
    ]

    private let converter: SourceLocationConverter
    private(set) var animationSites: [Site] = []
    private(set) var assignments: [Site] = []
    private(set) var animationDecls: [Site] = []
    private(set) var transformSites: [Site] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    static func collect(_ code: String) -> MotionSiteCollector {
        let tree = Parser.parse(source: code)
        let collector = MotionSiteCollector(converter: SourceLocationConverter(fileName: "", tree: tree))
        collector.walk(tree)
        return collector
    }

    private func line(_ node: some SyntaxProtocol) -> Int {
        node.startLocation(converter: self.converter).line
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func calleeName(_ expression: ExprSyntax) -> String? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        if let member = expression.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        return nil
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let name = Self.calleeName(node.calledExpression) else { return .visitChildren }
        let arguments = Self.normalized(node.arguments.description)
        switch name {
        case "withAnimation":
            let first = node.arguments.first.map { Self.normalized($0.expression.description) } ?? ""
            self.animationSites.append(Site(line: self.line(node), kind: name, text: first))
        case "withTransaction":
            self.animationSites.append(Site(line: self.line(node), kind: name, text: arguments))
        case "animation":
            if node.arguments.first?.label == nil {
                let first = node.arguments.first.map { Self.normalized($0.expression.description) } ?? ""
                self.animationSites.append(Site(line: self.line(node), kind: name, text: first))
            }
        case "transaction":
            self.animationSites.append(Site(line: self.line(node), kind: name, text: Self.normalized(node.description)))
        case "Transaction":
            if let animation = node.arguments.first(where: { $0.label?.text == "animation" }) {
                self.animationSites.append(Site(line: self.line(node), kind: name, text: Self.normalized(animation.expression.description)))
            }
        default:
            if Self.transformCallees.contains(name), !Self.isTypeQualified(node.calledExpression) {
                self.transformSites.append(Site(line: self.line(node), kind: name, text: arguments))
            }
        }
        return .visitChildren
    }

    private static func isTypeQualified(_ expression: ExprSyntax) -> Bool {
        guard let base = expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) else { return false }
        return base.baseName.text.first?.isUppercase == true
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.is(AssignmentExprSyntax.self),
           let member = node.leftOperand.as(MemberAccessExprSyntax.self),
           member.declName.baseName.text == "animation" {
            self.assignments.append(Site(line: self.line(node), kind: "animation =", text: Self.normalized(node.rightOperand.description)))
        }
        return .visitChildren
    }

    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
        let type = node.typeAnnotation.map { Self.normalized($0.type.description) } ?? ""
        let initializer = node.initializer.map { Self.normalized($0.value.description) } ?? ""
        let typed = type == "Animation" || type == "Animation?" || type == "SwiftUI.Animation"
        let constructed = initializer.hasPrefix("Animation.") || initializer.hasPrefix("Animation(")
        if typed || constructed {
            self.animationDecls.append(Site(line: self.line(node), kind: "binding", text: Self.normalized(node.description)))
        }
        return .visitChildren
    }
}
