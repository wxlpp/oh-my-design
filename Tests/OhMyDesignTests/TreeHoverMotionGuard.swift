import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - Tree 悬停的源码纪律 / Tree hover source discipline

@Suite("Tree 悬停源码纪律：行宿主与 .navigator 行内不出现任何补间调用；悬停状态只在行级、只在 .navigator 下追踪")
struct TreeHoverMotionGuard {
    nonisolated static let rowHostType = "TreeRowHost"
    nonisolated static let navigatorRowType = "NavigatorTreeRow"
    nonisolated static let containerType = "Tree"
    nonisolated static let automaticRowType = "AutomaticTreeRow"
    nonisolated static let motionCalls: Set<String> = [
        "animation", "coreAnimation", "withAnimation", "transaction", "withTransaction",
    ]
    nonisolated static let navigatorCase = ".navigator"
    nonisolated static let hoverCalls: Set<String> = ["onHover", "onContinuousHover"]

    nonisolated static var treeDirectory: URL {
        GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName).appendingPathComponent("Components/Tree")
    }

    static func scan() throws -> TreeHoverScan {
        let files = GuardScanRoots.swiftFiles(in: Self.treeDirectory)
        #expect(!files.isEmpty, "Components/Tree 下一个 .swift 都没扫到——判据在空输入上恒绿")
        let collector = TreeHoverCollector(viewMode: .sourceAccurate)
        for url in files {
            let tree = Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
            collector.file = url.lastPathComponent
            collector.walk(tree)
        }
        return TreeHoverScan(
            declaredTypes: collector.declaredTypes,
            calls: collector.calls,
            memberVariables: collector.memberVariables
        )
    }

    @Test("被守的四个类型都在 Components/Tree 里——改名后判据不会在空集合上恒绿")
    func guardedTypesExist() throws {
        let scan = try Self.scan()
        for name in [Self.rowHostType, Self.navigatorRowType, Self.automaticRowType, Self.containerType] {
            #expect(scan.declaredTypes.contains(name), "找不到 struct \(name)——改了类型名要同步本判据")
        }
    }

    @Test("行宿主与 .navigator 行内不得出现 animation( / coreAnimation( / withAnimation / transaction / withTransaction——悬停高亮即时生效，按名禁调用")
    func rowHostAndNavigatorRowNeverAnimate() throws {
        let scan = try Self.scan()
        let hits = scan.calls.filter {
            [Self.rowHostType, Self.navigatorRowType].contains($0.owner) && Self.motionCalls.contains($0.name)
        }
        #expect(hits.isEmpty, "悬停所在的层出现了补间调用：\(hits.map(\.description))")
    }

    @Test("悬停只由行宿主追踪、只在 .navigator 分支挂：onHover 至少一处，全部在行宿主内的 case .navigator 下")
    func hoverIsTrackedOnlyByTheRowHost() throws {
        let scan = try Self.scan()
        let hover = scan.calls.filter { Self.hoverCalls.contains($0.name) }
        #expect(!hover.isEmpty, "Components/Tree 里没有任何 onHover——.navigator 的悬停没有接线")
        let elsewhere = hover.filter { $0.owner != Self.rowHostType }
        #expect(elsewhere.isEmpty, "onHover 出现在行宿主之外：\(elsewhere.map(\.description))")
        let unconditional = hover.filter { !($0.switchCase ?? "").contains(Self.navigatorCase) }
        #expect(unconditional.isEmpty, "onHover 不在 case .navigator 分支内——.automatic 不画悬停，却也在追踪指针：\(unconditional.map(\.description))")
    }

    @Test("无障碍取值与点选手势只挂在行宿主上（外观之外），两种外观因此共用同一份")
    func accessibilityAndSelectionLiveOutsideTheAppearances() throws {
        let scan = try Self.scan()
        let owned: Set<String> = ["accessibilityValue", "accessibilityAddTraits", "onTapGesture", "contentShape"]
        for name in owned {
            let owners = Set(scan.calls.filter { $0.name == name }.map(\.owner))
            #expect(owners.contains(Self.rowHostType), "行宿主上没有 \(name)(——行为 / 无障碍没挂在外观之外")
        }
        let appearanceTypes: Set<String> = [Self.navigatorRowType, Self.automaticRowType]
        let leaked = scan.calls.filter { appearanceTypes.contains($0.owner) && owned.contains($0.name) }
        #expect(leaked.isEmpty, "外观类型里出现了行为 / 无障碍调用：\(leaked.map(\.description))")
    }

    @Test("容器 Tree 不持有悬停状态（名字含 hover 的成员变量）——容器级悬停会让指针每跨一行就重算整棵树")
    func containerHoldsNoHoverState() throws {
        let scan = try Self.scan()
        let members = scan.memberVariables[Self.containerType] ?? []
        #expect(!members.isEmpty, "没读到 Tree 的任何成员变量——扫描没走进容器类型")
        let hover = members.filter { $0.lowercased().contains("hover") }
        #expect(hover.isEmpty, "容器 Tree 持有悬停状态：\(hover)")
    }
}

// MARK: - 扫描结果 / Scan result

nonisolated struct TreeHoverCall: Sendable, CustomStringConvertible {
    let file: String
    let owner: String
    let name: String
    let switchCase: String?

    var description: String { "\(self.file) · \(self.owner) · \(self.switchCase ?? "-") · \(self.name)(" }
}

nonisolated struct TreeHoverScan: Sendable {
    let declaredTypes: Set<String>
    let calls: [TreeHoverCall]
    let memberVariables: [String: [String]]
}

private nonisolated final class TreeHoverCollector: SyntaxVisitor {
    var file = ""
    private(set) var declaredTypes: Set<String> = []
    private(set) var calls: [TreeHoverCall] = []
    private(set) var memberVariables: [String: [String]] = [:]
    private var owners: [String] = []
    private var switchCases: [String] = []

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        self.switchCases.append(node.label.trimmedDescription)
        return .visitChildren
    }

    override func visitPost(_ node: SwitchCaseSyntax) {
        self.switchCases.removeLast()
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypes.insert(node.name.text)
        self.owners.append(node.name.text)
        for member in node.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                self.memberVariables[node.name.text, default: []].append(pattern.identifier.text)
            }
        }
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        self.owners.removeLast()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        self.owners.append(node.extendedType.trimmedDescription.components(separatedBy: "<").first ?? "")
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        self.owners.removeLast()
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let name: String?
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
            name = member.declName.baseName.text
        } else if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            name = reference.baseName.text
        } else {
            name = nil
        }
        if let name {
            self.calls.append(TreeHoverCall(
                file: self.file, owner: self.owners.last ?? "<file>", name: name, switchCase: self.switchCases.last
            ))
        }
        return .visitChildren
    }
}
