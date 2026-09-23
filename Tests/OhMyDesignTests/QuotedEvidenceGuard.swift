import Foundation
import Testing

// MARK: - 散文引用须带可核引文（Issue #337）

@Suite("散文引用须带可核引文（#337）")
struct QuotedEvidenceGuard {
    /// 登记项 = （文档文件, 源文件, 被引原文）。
    ///
    /// 判据（与 `#337` 方案逐字一致）：**每条 quote（空白折叠后）仍存在于 source 文件中**。
    /// 文档侧**不核** —— `#337` 的验收就一句「被引原文仍在源文件」；quote 的选取标准：
    /// 优先逐字片段（含符号时保留其修饰符），签名 / 符号类引用允许「名字级」（如函数名）。
    ///
    /// ⚠️ **为什么是「引文逐字核」而不是「核行号」**（`#337` 普查：六成失真是纯坐标漂移、
    /// 被引文字还在）：引行号漂了指向的是「看起来合理的别的内容」（读者**以为**自己核过了）；
    /// 引逐字片段漂了会 `grep` 得 0 命中（读者**知道**自己没核到）。判据按「整段逐字 + 名字」
    /// 匹配，**不按行号 / 形状**。
    ///
    /// ⚠️ **登记面**：`#337` 改写后**选定的登记子集**（本批全部以逐字引文形态写下的源码引用）；
    /// 纯文件级引用、跨仓引用、史料性坐标叙述不构成逐字声称、不入表（跨仓清单见
    /// `crossRepoCitations`）；**未登记为引文的符号引用仍靠人工**。签名简写（如
    /// `init(title:action:)`）按名字级收。**不写死条数**（表允许增长）。
    ///
    /// ⚠️ **表本身必须 fail-closed**：清单漏登记只会静默少测一条 —— 所以另有一条判据核
    /// 「表非空」「quote 非空」「源文件落在已知扫描面内」「doc 文件存在」；而**新增裸行号
    /// 引用**的拦截由 `BareLineRefGate`（同批清零后已升级为零容忍）承担。
    private nonisolated static let citations: [(doc: String, source: String, quote: String)] = [
        // ---- docs/contract-defects.md ----
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/SurfaceModifier.swift", "case canvasSubtle"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/SurfaceModifier.swift", "/// 兼容别名：更淡的画布。"),
        ("docs/contract-defects.md", "Tests/OhMyDesignTests/ComponentJudgeRules.swift", "let declared = scan.styleProtocolNames.contains(custom)"),
        ("docs/contract-defects.md", "Tests/OhMyDesignTests/ComponentJudgeRules.swift", "if declared && !implementations.isEmpty"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/AvatarGroup/AvatarGroup.swift", "HStack(spacing: self.layout == .overlapped ? self.overlapOffset : CoreSpacing.xxs)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Form/Form.swift", "Image(systemName: \"chevron.forward\")"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Form/Form.swift", ".accessibilityHidden(true)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Form/Form.swift", "Image(systemName: \"exclamationmark.circle.fill\")"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Form/Form.swift", ".foregroundStyle(Color.statusDangerForeground)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Form/Form.swift", ".accessibilityLabel(Text(\"Alert\", bundle: .module))"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/FloatingGlassModifier.swift", "public let shape: S"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/FloatingGlassModifier.swift", "in shape: some InsettableShape = Capsule(style: .continuous)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Toast/Toast.swift", "RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/SettingsRow/SettingsRow.swift", ".font(.footnote.weight(.semibold))"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/SettingsRow/SettingsRow.swift", ".foregroundStyle(Color.contentTertiary)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "@ViewBuilder node: () -> Node,"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "private var nodeContent: some View"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/StateLabel/StateLabel.swift", "let defaultLabel: String"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/TelegramGlassButtonModifier.swift", "self.border ?? Color.white.opacity(CoreButtonMetrics.glassBorderOpacity)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Modifier/TelegramGlassButtonModifier.swift", "isPressed: self.pressFeedback && self.isPressed,"),
        ("docs/contract-defects.md", "Tests/OhMyDesignTests/ComponentJudgeRules.swift", "judgeTextParamCoverage"),
        ("docs/contract-defects.md", "Tests/OhMyDesignTests/ComponentJudgeRules.swift", "entry.repo == \"ohmydesign\" && entry.kind == \"semantic\" && entry.needsExtensionPoint"),
        ("docs/contract-defects.md", "Tests/OhMyDesignTests/ComponentExtensionPointGuard.swift", "entries.filter { $0.repo == \"storyui\" && $0.kind == \"semantic\" }.isEmpty"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Section/SectionFooter.swift", ".foregroundStyle(Color.contentSecondary)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Section/SectionFooter.swift", ".frame(maxWidth: .infinity, alignment: .leading)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Section/SectionHeader.swift", ".textCase(.uppercase)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Section/SectionHeader.swift", ".accessibilityAddTraits(.isHeader)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Style/Descriptions.swift", ".labeledContentStyle(.core)"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Style/Descriptions.swift", "DescriptionsColumns"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Style/Descriptions.swift", "DescriptionsDividerDensity"),
        ("docs/contract-defects.md", "Sources/OhMyDesign/Components/Rating/Rating.swift", "AnyView(self.style.makeBody("),
        // ---- docs/component-registry.json ----
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/AvatarGroup/AvatarGroup.swift", "HStack(spacing: self.layout == .overlapped ? self.overlapOffset : CoreSpacing.xxs)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Form/Form.swift", "Image(systemName: \"chevron.forward\")"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Form/Form.swift", ".foregroundStyle(Color.statusDangerForeground)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Style/Descriptions.swift", "DescriptionsColumns"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Style/Descriptions.swift", "DescriptionsDividerDensity"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Modifier/FloatingGlassModifier.swift", "in shape: some InsettableShape = Capsule(style: .continuous)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Toast/Toast.swift", "RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)"),
        ("docs/component-registry.json", "Sources/OhMyDesignEffects/OrbitRing.swift", "static let ringCount: Int = 4"),
        ("docs/component-registry.json", "Sources/OhMyDesignEffects/OrbitRing.swift", "seats(particleScale:"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Style/CoreProgressViewStyle.swift", "public func makeBody(configuration: Configuration) -> some View"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Radio/Radio.swift", "与 `CheckBoxToggleStyle` 同套 token、方框换圆点"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Section/SectionFooter.swift", ".foregroundStyle(Color.contentSecondary)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/SettingsRow/SettingsRow.swift", "icon: SettingsRowIcon?"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/SettingsRow/SettingsRow.swift", ".font(.footnote.weight(.semibold))"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/StateLabel/StateLabel.swift", "let defaultLabel: String"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Modifier/TelegramGlassButtonModifier.swift", "self.border ?? Color.white.opacity(CoreButtonMetrics.glassBorderOpacity)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Modifier/TelegramGlassButtonModifier.swift", "isPressed: self.pressFeedback && self.isPressed,"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "static let nodeColumnWidth: CGFloat = 24"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/Tree.swift", "content.disclosureGroupStyle(TreeDisclosureGroupStyle())"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeCore.swift", "nonisolated struct TreeExpansionState<ID: Hashable>: Equatable {"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeCore.swift", "static func effective<ID: Hashable>( _ focus: ID?, visibleRows rows: [TreeRow<ID>], selection: Set<ID>, ancestors: (ID) -> [ID] ) -> ID? {"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeCore.swift", "static func reconciled<ID: Hashable>("),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeInteraction.swift", "TreeFocusing.ancestors(of: hidden, in: oldRows)"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeStyle.swift", "public struct TreeStyle {"),
        ("docs/component-registry.json", "Sources/OhMyDesign/Components/Tree/TreeStyle.swift", "func treeStyle(_ style: TreeStyle) -> some View {"),
        // ---- docs/issues/234-a11y-smoke.md ----
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/Section/SectionHeader.swift", ".accessibilityAddTraits(.isHeader)"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/Radio/Radio.swift", "[.isButton, .isSelected] : .isButton"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/Carousel/Carousel.swift", "[.isButton, .isSelected] : .isButton"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/SegmentedControl/SegmentedControl.swift", ".accessibilityAddTraits(segment.isSelected ? .isSelected : [])"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/PinCode/PinCode.swift", ".accessibilityAddTraits(isCurrent ? .isSelected : [])"),
        ("docs/issues/234-a11y-smoke.md", "App/Sources/ComponentData.swift", "SearchField(text: self.$text)"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/SearchField/SearchField.swift", "placeholder: String = \"Search\""),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/SearchField/SearchField.swift", "String(localized: \"Search\", bundle: .module)"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Components/Rating/Rating.swift", "RatingAdjustableModifier"),
        ("docs/issues/234-a11y-smoke.md", "Sources/OhMyDesign/Modifier/SpinningModifier.swift", ".updatesFrequently"),
        // ---- docs/component-contract.md ----
        ("docs/component-contract.md", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "@ViewBuilder node: () -> Node,"),
        ("docs/component-contract.md", "Sources/OhMyDesign/Components/Steps/Steps.swift", "public enum StepsIndicatorStyle"),
        ("docs/component-contract.md", "Sources/OhMyDesign/Components/Timeline/Timeline.swift", "private var nodeContent: some View"),
        ("docs/component-contract.md", "Sources/OhMyDesign/Components/Banner/Banner.swift", "public protocol BannerStyle"),
        ("docs/component-contract.md", "Sources/OhMyDesign/Components/SegmentedControl/SegmentedControl.swift", "public protocol SegmentedControlStyle"),
        ("docs/component-contract.md", "Tests/OhMyDesignTests/ComponentJudgeScanner.swift", "bareTextTypeNames"),
        // ---- docs/components/orbiting-logos.md ----
        ("docs/components/orbiting-logos.md", "Sources/OhMyDesignEffects/OrbitRing.swift", "static let ringCount: Int = 4"),
        ("docs/components/orbiting-logos.md", "Sources/OhMyDesignEffects/OrbitRing.swift", "seats(particleScale:"),
        // ---- docs/components/checkbox.md ----
        ("docs/components/checkbox.md", "Sources/OhMyDesign/Components/CheckBox/CheckBox.swift", "if isMixed { return .mixed }"),
        ("docs/components/checkbox.md", "Sources/OhMyDesign/Components/CheckBox/CheckBox.swift", "case .mixed: \"minus.square.fill\""),
        ("docs/components/checkbox.md", "Sources/OhMyDesign/Components/CheckBox/CheckBox.swift", ".contentTransition(self.motionPresentation.symbolReplacement)"),
        // ---- docs/components/tree.md ----
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/Tree.swift", "CoreMotionToken.treeExpansion(for:"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/Tree.swift", "CoreMotionToken.reveal.transformAnimation(for:"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/Tree.swift", ".coreAnimation(.selection, value: self.selection)"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "expansionAnimationHonoursReduceMotion"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TouchTargetTests.swift", "treeDisclosureMeetsMinimumTouchTarget"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TouchTargetTests.swift", "treeRowMeetsMinimumTouchTarget"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/TreeStyle.swift", "Color.quaternaryFill"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Colors/InteractionColors.swift", "accentSelectedRowBackground"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/TreeStyle.swift", "Color.borderDefault"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", ".allowsWindowActivationEvents(true)"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "TreeStyleRenderTests"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "selectionIsStrongerThanHover"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "TreeGuideLineTests"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "TreeHoverTests"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeHoverMotionGuard.swift", "TreeHoverMotionGuard"),
        ("docs/components/tree.md", "Sources/OhMyDesign/Components/Tree/Tree.swift", "func rowContextMenu<M: View>(@ViewBuilder _ menu: @escaping (Set<ID>) -> M) -> Tree"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "TreeContextMenuTests"),
        ("docs/components/tree.md", "Tests/OhMyDesignTests/TreeTests.swift", "UIContextMenuInteraction"),
        // ---- docs/superpowers/ ----
        ("docs/superpowers/specs/2026-05-13-async-button-design.md", "Sources/OhMyDesign/Components/Button/styles/SolidButtonStyle.swift", "? self.role.resolvedOnColor("),
        ("docs/superpowers/specs/2026-05-13-async-button-design.md", "Sources/OhMyDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift", "onTapGesture(count: 1, perform: configuration.trigger)"),
        ("docs/superpowers/specs/2026-05-13-async-button-design.md", "Sources/OhMyDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift", "CoreBorderlessButtonStyle"),
        ("docs/superpowers/specs/2026-05-13-async-button-design.md", "Sources/OhMyDesign/Components/Toast/Toast.swift", "@Entry public var toastHost: ToastHost? = nil"),
        ("docs/spikes/248-metal-packaging.md", "Tests/OhMyDesignTests/ColorAssetGuardTests.swift", "rawXcassetsAvailable"),
        // ---- 台账 JSON ----
        ("docs/bool-exemptions.json", "Sources/OhMyDesign/Modifier/FloatingGlassModifier.swift", "let glass = self.isInteractive ? Glass.regular.interactive() : Glass.regular"),
        ("docs/a11y-exemptions.json", "Sources/OhMyDesign/Components/TagInput/TagInput.swift", ".fieldAccessibility(fallbackLabel: Text(self.placeholder))"),
    ]

    /// 跨仓引用（`#337` 如实登记，**不追进他仓、不加假核**）：doc 侧引用对面仓
    /// `wxlpp/oh-my-story` 的源码。⚠️ 只核「文档里确实还带着这条引用」；引用本身的状态
    /// 去对面仓读（`component-contract.md` 的 G-8 行已写明「以逐字引文为准」）。
    private nonisolated static let crossRepoCitations: [(doc: String, symbol: String)] = [
        ("docs/contract-defects.md", "FocusModeContainer"),
        ("docs/contract-defects.md", "StoryScaffold"),
        ("docs/contract-defects.md", "ToolCallRow"),
        ("docs/component-contract.md", "CodexEntry.swift"),
        ("docs/component-contract.md", "CrossRepoRegistryGuard.swift"),
        ("docs/component-contract.md", "TextParamScan.swift"),
        ("docs/component-contract-revisions.md", "CodexEntry.swift"),
        ("docs/reachable-type-registry.json", "CodexEntry.swift"),
    ]

    /// 把连续空白（含换行 / tab / CR）折成单个空格 —— 与 `SingleSourceOfTruthGuard.folded` 同形。
    private nonisolated static func folded(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    @Test("每条被引原文仍逐字存在于源文件")
    func quotesStillExistInSources() throws {
        #expect(Self.citations.count >= 74,
                "登记表只剩 \(Self.citations.count) 条 —— 表被删空就全绿，这不是「零违规」")
        var missing: [String] = []
        for citation in Self.citations {
            let url = GuardScanRoots.repoRoot.appendingPathComponent(citation.source)
            guard FileManager.default.fileExists(atPath: url.path) else {
                missing.append("源文件不存在：\(citation.source)（登记自 \(citation.doc)）")
                continue
            }
            let body = try String(contentsOf: url, encoding: .utf8)
            if !Self.folded(body).contains(Self.folded(citation.quote)) {
                missing.append("\(citation.source) 里找不到引文「\(citation.quote)」（\(citation.doc) 引用它）")
            }
        }
        #expect(missing.isEmpty, """
        \(missing.count) 条被引原文在源文件里找不到了：
        \(missing.joined(separator: "\n"))

        —— 处理方向：源侧改动若是有意的，同步改写登记表对应条目**与文档里的引用**；
        文档侧引用若已过时，删引用或换仍存在的证据。⚠️ 不要直接把登记项删掉换绿
        （那正是 `#337` 要治的「静默陈旧」）。⚠️ 行号**不在**本判据的比对面上，
        改源文件的上下文/补注释不会红——只有被引原文本身被改动 / 删除才红。
        """)
    }

    @Test("文档侧引文与登记表逐字一致（改文档引文一个字即红）")
    func docSideQuotesMatchRegistry() throws {
        for citation in Self.citations {
            let url = GuardScanRoots.repoRoot.appendingPathComponent(citation.doc)
            var body = try String(contentsOf: url, encoding: .utf8)
            if url.pathExtension == "json" {
                body = body.replacingOccurrences(of: "\\\"", with: "\"")
            }
            #expect(Self.folded(body).contains(Self.folded(citation.quote)), """
            \(citation.doc) 里找不到引文「\(citation.quote)」（登记来源：\(citation.source)）。
            —— 文档侧引文被改写 / 删除时判红：要么把引文改回逐字，要么同步登记表。
            """)
        }
    }

    @Test("登记表的文档与源文件都在已知扫描面内（表自身 fail-closed）")
    func registryIsSelfConsistent() {
        let sourceRoots = GuardScanRoots.allRoots.map { $0.url.path }
        for citation in Self.citations {
            let sourcePath = GuardScanRoots.repoRoot
                .appendingPathComponent(citation.source).standardizedFileURL.path
            // 三 target 根之外只放过两处：`Tests/`（判据所在 target，存在性由编译器保证）
            // 与 `App/`（预览宿主，不在三 target 内但同样是活引用）。
            let isKnownRoot = sourceRoots.contains { sourcePath.hasPrefix($0 + "/") }
            #expect(isKnownRoot || citation.source.hasPrefix("Tests/") || citation.source.hasPrefix("App/"),
                    "\(citation.source) 不在已知扫描面内（登记自 \(citation.doc)）")
            #expect(!citation.quote.trimmingCharacters(in: .whitespaces).isEmpty,
                    "空 quote：\(citation.doc) → \(citation.source)")
            let docPath = GuardScanRoots.repoRoot.appendingPathComponent(citation.doc).path
            #expect(FileManager.default.fileExists(atPath: docPath),
                    "登记表里的文档不存在：\(citation.doc)（改名 / 删除时同步本表）")
        }
    }

    @Test("跨仓引用如实登记、且仍被文档引着")
    func crossRepoCitationsAreRegistered() throws {
        #expect(Self.crossRepoCitations.count >= 8,
                "跨仓登记表只剩 \(Self.crossRepoCitations.count) 条 —— 删表即静默，这不是「跨仓清零」")
        for citation in Self.crossRepoCitations {
            let url = GuardScanRoots.repoRoot.appendingPathComponent(citation.doc)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "登记表里的文档不存在：\(citation.doc)")
            let body = try String(contentsOf: url, encoding: .utf8)
            #expect(body.contains(citation.symbol),
                    "\(citation.doc) 里已找不到跨仓符号「\(citation.symbol)」—— 引用被删时同步本表")
        }
    }
}
