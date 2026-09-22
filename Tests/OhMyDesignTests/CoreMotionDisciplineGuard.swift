import Foundation
import Testing

// MARK: - 核心库动效纪律 / Core motion discipline

@Suite("核心库动效纪律：动画只经 CoreMotion 取、含动效的文件登记 Reduce Motion 策略")
struct CoreMotionDisciplineGuard {
    enum Strategy: Sendable {
        case tokenSource
        case gated
        case fadeOnly
        case staticTransform
    }

    static let tokenFile = "Tokens/CoreMotion.swift"

    static let ledger: [String: Strategy] = [
        "Tokens/CoreMotion.swift": .tokenSource,
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
    ]

    static let animationTriggers = [
        "withAnimation", ".animation(", ".transition(", ".coreAnimation(",
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
        var out: [String] = []
        for name in ["withAnimation", ".animation("] {
            for (line, args) in Self.callArguments(of: name, in: code) {
                guard let args else {
                    out.append("\(path):\(line) \(name) 没有实参 —— 曲线落到 SwiftUI 默认值，不经 CoreMotion")
                    continue
                }
                let trimmed = args.trimmingCharacters(in: .whitespacesAndNewlines)
                if !args.contains("CoreMotion") && !trimmed.hasPrefix("nil") {
                    out.append("\(path):\(line) \(name)(\(trimmed)) 的曲线不经 CoreMotion")
                }
            }
        }
        for literal in Self.curveLiterals where code.contains(literal) {
            out.append("\(path) 出现曲线字面量 `\(literal)` —— 曲线只许在 \(Self.tokenFile) 里定义")
        }
        return out
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

    @Test("核心库的动画曲线只经 CoreMotion 取")
    func curvesComeFromCoreMotion() {
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

    // MARK: - 自证：合成输入必须打红

    @Test("自证：扫描器对每一种违规形态都判红")
    func scannerCatchesSyntheticViolations() {
        let path = "Components/Fake/Fake.swift"
        #expect(!Self.curveViolations(path: path, code: "x.animation(.easeOut(duration: 0.2), value: v)").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "withAnimation {\n  v = 1\n}").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "withAnimation(.snappy) { v = 1 }").isEmpty)
        #expect(!Self.curveViolations(path: path, code: "let a: Animation = .smooth\nwithAnimation(a) { }").isEmpty)
        #expect(!Self.curveViolations(path: path, code: ".animation(.default, value: v)").isEmpty)
        #expect(Self.curveViolations(path: path, code: "withAnimation(CoreMotion.press.animation(for: p)) { }").isEmpty)
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
        #expect(Self.strategyViolations(
            path: path, code: "@Environment(\\.coreMotionPresentation) var m\n.scaleEffect(s)", strategy: .gated
        ).isEmpty)
    }
}
