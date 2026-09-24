import Foundation
import Testing

@Suite("FR-4 文本参数分类覆盖")
struct ComponentTextParamGuard {
    static let ownerAliases: [String: String] = [
        "ToastItem": "Toast",
        "ToastHost": "Toast",
        "ToastAction": "Toast",
        "RadioOption": "RadioGroup",
        "StepItem": "Steps",
        "SegmentedControlStyleConfiguration.Segment": "SegmentedControl",
    ]

    static let knownUnmappedOwnerParams: Set<String> = [
        "Color.init#text",
        "SettingsRowIcon.init#systemName",
        "Text.init#content",
        "Text.init#query",
    ]

    static let knownFunctionSideBareText: Set<String> = [
        "ToastHost.show#description",
        "ToastHost.show#title",
        "Tree.searchFilter#query",
        "Tree.searchFilter#text",
        "Tree.searchMatches#query",
        "Tree.searchMatches#text",
        "View.spray#symbol",
    ]

    nonisolated static func contradiction(notes: String, hasParams: Bool) -> String? {
        let live = strippingRetractions(notes)
        if hasParams, let c = absenceClaims.first(where: { live.contains($0) }) {
            return "登记了 textParams，notes 却写着「\(c)」——散文与数据自相矛盾"
        }
        if !hasParams, let c = presenceClaims.first(where: { live.contains($0) }) {
            return "textParams 是空的，notes 却写着「\(c)」——散文与数据自相矛盾"
        }
        return nil
    }

    nonisolated static func strippingRetractions(_ notes: String) -> String {
        notes.split(separator: "。").filter { sentence in
            !retractionMarkers.contains { sentence.contains($0) }
        }.joined(separator: "。")
    }

    nonisolated static let retractionMarkers = ["原判", "上句原写", "推翻", "已作废"]
    nonisolated static let absenceClaims = [
        "不落入 textParams", "不进本表", "没有 textParams 条目", "无 textParams 条目",
        "无裸 String 展示参数",
    ]

    nonisolated static let presenceClaims = ["登记为 C", "登记为 B"]

    @Test("散文 ⟂ 数据判据必须抓得住 #67 真实发生过的三条矛盾")
    func proseDataJudgeCatchesRealIncidents() {
        #expect(Self.contradiction(
            notes: "文本以 AttributedString 承载，不落入 textParams 的 A/B/C 三分法（该判据面向 String/LocalizedStringKey/Resource 类型的展示文案参数）。",
            hasParams: true) != nil, "第 1 轮事故（ManuscriptReader / StoryTextView 形态）逃逸")

        #expect(Self.contradiction(
            notes: "组件自身 init 无裸 String 展示参数。⚠️ 但**不等于无 textParams**：text 是 AttributedString，由 #67 起按公约 §4 的 C 行登记为 C（用户手稿正文）。",
            hasParams: false) != nil, "第 2 轮事故（SuggestionStream 形态）逃逸")

        #expect(Self.contradiction(
            notes: "理由同 ManuscriptReader：步骤 1 无，步骤 3 视觉即含义（外观完全由 typography/theme 值参数化，组件自身无独立可换皮表面）。无裸 String 展示参数。",
            hasParams: true) != nil, "第 2 轮事故（ManuscriptEditor 形态）逃逸")

        #expect(Self.contradiction(
            notes: "text 以 AttributedString 承载。⚠️ 上句原判**该参数不进本表**，已由 #67 推翻。",
            hasParams: true) == nil, "撤回留痕被误判为活体断言")
    }

    @Test("措辞表与撤回标记表不得静默增删")
    func claimTablesMatchPinnedSets() {
        let pinnedAbsence: Set<String> = [
            "不落入 textParams", "不进本表", "没有 textParams 条目", "无 textParams 条目",
            "无裸 String 展示参数",
        ]
        let pinnedPresence: Set<String> = ["登记为 C", "登记为 B"]
        let pinnedMarkers: Set<String> = ["原判", "上句原写", "推翻", "已作废"]

        #expect(Set(Self.absenceClaims) == pinnedAbsence,
                "absenceClaims 变了：多出 \(Set(Self.absenceClaims).subtracting(pinnedAbsence).sorted())、少了 \(pinnedAbsence.subtracting(Set(Self.absenceClaims)).sorted())")
        #expect(Set(Self.presenceClaims) == pinnedPresence,
                "presenceClaims 变了：多出 \(Set(Self.presenceClaims).subtracting(pinnedPresence).sorted())、少了 \(pinnedPresence.subtracting(Set(Self.presenceClaims)).sorted())")
        #expect(Set(Self.retractionMarkers) == pinnedMarkers,
                "retractionMarkers 变了：多出 \(Set(Self.retractionMarkers).subtracting(pinnedMarkers).sorted())、少了 \(pinnedMarkers.subtracting(Set(Self.retractionMarkers)).sorted())")

        for claim in pinnedAbsence {
            #expect(Self.contradiction(notes: "占位。前段文字\(claim)后段文字。", hasParams: true) != nil, "缺席措辞「\(claim)」触发不了判定")
        }
        for claim in pinnedPresence {
            #expect(Self.contradiction(notes: "占位。前段文字\(claim)后段文字。", hasParams: false) != nil, "在场措辞「\(claim)」触发不了判定")
        }
        for marker in pinnedMarkers {
            #expect(Self.contradiction(notes: "正文。上一版\(marker)：不进本表。", hasParams: true) == nil, "撤回标记「\(marker)」失效，留痕会被误判为活体断言")
        }
    }

    @Test("FR-4：public init 的裸文本参数必须在登记表 textParams 里有分类条目")
    func publicInitTextParamsAreClassified() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeTextParamCoverage(
            entries: entries, scan: scan, ownerAliases: Self.ownerAliases
        )

        let registryTextParams = entries.filter { $0.repo == "ohmydesign" }.flatMap(\.textParams).count
        #expect(scan.bareTextKeys.count > 20,
                "只扫到 \(scan.bareTextKeys.count) 个裸文本参数 —— 扫描器失效，这不是『零违规』")
        #expect(scan.localizedTextKeys.count > 5,
                "只扫到 \(scan.localizedTextKeys.count) 个 LSK/LSR 参数 —— 扫描器失效")
        #expect(registryTextParams == 33,
                "OhMyDesign 侧 textParams 实测 33 条（`#373` 新增 FormField 的 label / description 后由 27 变为 29；`#376` Banner 便利 init 的 title / message 两条 by-type 使 29 变为 31；`#377` 把 Toast 的 message 改名 title 并新增 description / label 使 31 变为 33），实际 \(registryTextParams) —— 若为预期变化请同步改这个数字")
        #expect(result.covered.count == 26,
                "覆盖数实测 26（`#373` 新增 FormField 的 label / description 后由 22 变为 24；`#377` 的 ToastItem title / description、ToastAction label 取代 ToastItem.init#message 使 24 变为 26），实际 \(result.covered.count)：\(result.covered.keys.sorted())")
        #expect(abs(result.covered.count - registryTextParams) * 2 <= registryTextParams,
                "扫到的覆盖数 \(result.covered.count) 与登记表 \(registryTextParams) 条不在同一量级 —— 两侧口径可能已经脱节")

        #expect(result.violations.isEmpty, "这些裸文本参数没有分类条目：\n\(result.diagnostics.joined(separator: "\n"))")

        #expect(result.ghostRegistryParams.isEmpty,
                "登记表里这些 textParams 在源码里找不到对应参数（改名？改类型？删了？）：\(result.ghostRegistryParams)")

        #expect(Set(result.exemptedByRegistryNotes) == ["LabelIcon.init#systemName"],
                """
                notes 授权豁免集合变了：实际 \(result.exemptedByRegistryNotes)。这条通道是 FR-4 唯一的语义豁免入口，\
                授权者是登记表 notes 而不是判据作者，集合变化必须有人过目
                """)
        #expect(Set(result.exemptedByExcludedKind) == ["ProgressBar.init#label"],
                """
                弃用豁免集合变了：实际 \(result.exemptedByExcludedKind)。ProgressBar 已 kind=excluded、\
                textParams 留空是刻意的（公约弃用条款「不分类」）；#42 删掉该组件后本条会因集合变空而红，届时同步删除
                """)
        #expect(Set(result.unmappedOwners) == Self.knownUnmappedOwnerParams,
                """
                定义域外集合变了：实际 \(result.unmappedOwners)，已知 \(Self.knownUnmappedOwnerParams.sorted())。\
                新条目意味着出现了『有裸文本参数、但宿主不对应任何登记表条目』的类型 —— 要么补 ownerAliases，\
                要么退回登记表判断它该不该登记（#38 已 CLOSED，判定归属见 wxlpp/oh-my-story#51），**不能**默默跳过
                """)

        #expect(scan.bareTextKeys.contains("ProgressBar.init#label"),
                "ProgressBar.init#label 已不在源码里 —— 弃用豁免失去豁免对象，请删除对应断言")
        #expect(entries.first { $0.component == "ProgressBar" }?.kind == "excluded",
                "ProgressBar 不再是 kind=excluded —— 它的 textParams 留空就不再受弃用条款保护了")

        #expect(Set(result.functionSideBareText) == Self.knownFunctionSideBareText,
                """
                func 侧裸文本参数集合变了：实际 \(result.functionSideBareText)，已知 \(Self.knownFunctionSideBareText.sorted())。\
                本桶是留痕不是判据（AC 只点名 init）；集合变化说明新增了不受 FR-4 主判据覆盖的文案入口，\
                需要人来决定是扩 FR-4 定义域还是移交
                """)

        #expect(result.localizedByType.count == 25,
                """
                LSK/LSR 由类型判定的键实测 25 条（`#373` 新增 FormField 的 label / description 后由 17 变为 19；`#376` Banner 便利 init 的 title / message 使 19 变为 21；`#420` TimelineItem 的 title / description 使 21 变为 23；`#417` StatefulButton 便利 init 的 titleKey、`#418` SlideToConfirm 便利 init 的 titleKey 使 23 变为 25），实际 \(result.localizedByType.count)：\(result.localizedByType)。\
                变化意味着有参数在 LSK/LSR 与裸串之间换了类型 —— 要人过目，不能静默
                """)
        #expect(result.carrying.count == 7,
                """
                text-carrying 键实测 7 条（移除 BottomInputBar 后由 10 变为 7），\
                实际 \(result.carrying.count)：\(result.carrying)。\
                本桶（Binding<String> / 回调等）不进主判据，但它是**文案经此进入组件**的通道，\
                静默增长等于 FR-4 的定义域在无人过目的情况下缩小
                """)

        #expect(result.skippedRepos == ["storyui": 25], "跨仓跳过计数变了：实际 \(result.skippedRepos)")
        let storyuiTextParamFlat = entries.filter { $0.repo == "storyui" }
            .flatMap { e in e.textParams.map { "\(e.component).\($0.name)=\($0.category)" } }
        let storyuiTextParamEntries = Set(storyuiTextParamFlat)
        let expectedStoryuiTextParams: Set<String> = [
            "DynamicForm.header=B", "DynamicForm.footer=B", "ChapterStatusBadge.label=B",
            "ManuscriptEditor.text=C", "ManuscriptReader.text=C", "StoryTextView.initialText=C",
        ]
        let allClaims = Self.absenceClaims + Self.presenceClaims
        let overlaps = allClaims.flatMap { x in allClaims.filter { $0 != x && $0.contains(x) }.map { (x, $0) } }
        #expect(overlaps.isEmpty,
                "措辞表存在子串包含，判据会自造误报：\(overlaps.map { "「\($0.0)」⊂「\($0.1)」" }.joined(separator: "、"))")

        for e in entries {
            let c = Self.contradiction(notes: e.notes, hasParams: !e.textParams.isEmpty)
            #expect(c == nil, "\(e.component)：\(c ?? "")")
        }

        #expect(storyuiTextParamFlat.count == storyuiTextParamEntries.count,
                """
                storyui 的 textParams 有重复登记：展开 \(storyuiTextParamFlat.count) 条、去重后 \(storyuiTextParamEntries.count) 条。
                重复项：\(Dictionary(grouping: storyuiTextParamFlat, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())
                """)

        #expect(storyuiTextParamEntries == expectedStoryuiTextParams,
                """
                StoryUI 侧 textParams 条目集与期望不一致：
                  登记表有、期望没有：\(storyuiTextParamEntries.subtracting(expectedStoryuiTextParams).sorted())
                  期望有、登记表没有：\(expectedStoryuiTextParams.subtracting(storyuiTextParamEntries).sorted())
                —— 本条只核**登记表内容**；源码侧判据在 oh-my-story 的 `TextParamGuard`（#67）。
                """)

        var scanKeysByRegistryEntry: [String: [String]] = [:]
        for (scanKey, registryEntry) in result.covered {
            scanKeysByRegistryEntry[registryEntry, default: []].append(scanKey)
        }
        let allRegistryNames = Set(
            entries.filter { $0.repo == "ohmydesign" }
                .flatMap { entry in entry.textParams.map { "\(entry.component).\($0.name)" } }
        )
        let uncoveredRegistryNames = allRegistryNames.subtracting(scanKeysByRegistryEntry.keys).sorted()
        let multiHitRegistryNames = scanKeysByRegistryEntry.filter { $0.value.count > 1 }
        print("FR-4 covered 映射（登记条目 ← 扫描键）：")
        for (registryEntry, scanKeys) in scanKeysByRegistryEntry.sorted(by: { $0.key < $1.key }) {
            print("  \(registryEntry)  ←  \(scanKeys.sorted().joined(separator: " , "))")
        }
        print("FR-4 记账：登记条目 \(allRegistryNames.count) 条 = 产生 covered 键的 \(scanKeysByRegistryEntry.count) 条 + 零 covered 键的 \(uncoveredRegistryNames.count) 条")
        print("FR-4 零 covered 键的登记条目：\(uncoveredRegistryNames)")
        print("FR-4 双命中登记条目 \(multiHitRegistryNames.count) 条：\(multiHitRegistryNames.mapValues { $0.sorted() })")
        #expect(scanKeysByRegistryEntry.values.map(\.count).reduce(0, +) == result.covered.count)
        #expect(scanKeysByRegistryEntry.count + uncoveredRegistryNames.count == allRegistryNames.count,
                """
                记账不闭合：产生 covered 键的 \(scanKeysByRegistryEntry.count) 条 + 零 covered 键的 \
                \(uncoveredRegistryNames.count) 条 ≠ 登记条目 \(allRegistryNames.count) 条 —— \
                多半是某个 covered 值指向了一条并不存在于登记表的条目名
                """)

        print("FR-4 覆盖 \(result.covered.count) 条；LSK/LSR 由类型判定 \(result.localizedByType.count) 条；carrying \(result.carrying.count) 条")
        print("FR-4 已知违规 \(result.violations)（回 #38 补 notes）")
        print("FR-4 notes 授权豁免 \(result.exemptedByRegistryNotes)；弃用豁免 \(result.exemptedByExcludedKind)")
        print("FR-4 定义域外 \(result.unmappedOwners)；func 侧留痕 \(result.functionSideBareText)")
        print("FR-4 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条 / \(storyuiTextParamEntries.count) 个 textParams：本仓只核登记表内容（CI 只 checkout 本仓）；源码侧判据见 oh-my-story 的 TextParamGuard（#67）。")
    }

    @Test("FR-4 附条：owner 翻译表每一条都必须真的被用到（不许有过期条目）")
    func ownerAliasesAreLoadBearing() throws {
        let scan = try ComponentJudgeSources.scan()
        let owners = Set(scan.textParams.map(\.owner))
        let unused = Set(Self.ownerAliases.keys).subtracting(owners)
        #expect(unused.isEmpty,
                "ownerAliases 里这些宿主在源码里已经没有文本参数了，翻译条目已过期：\(unused.sorted())")
    }

    @Test("FR-4 附条：by-type 分类必须真的没有孪生裸串重载（公约 §4 的实际筛子）")
    func byTypeCategoryHasNoBareStringTwin() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()

        var bareNamesByComponent: [String: Set<String>] = [:]
        for hit in scan.textParams where hit.kind == .bareText {
            let component = Self.ownerAliases[hit.owner] ?? hit.owner
            bareNamesByComponent[component, default: []]
                .formUnion(textParamCandidateNames(owner: hit.owner, parameter: hit.parameter))
        }

        var byTypeCount = 0
        var localizedBCount = 0
        for entry in entries where entry.repo == "ohmydesign" {
            for textParam in entry.textParams {
                let hasBareTwin = bareNamesByComponent[entry.component]?.contains(textParam.name) ?? false
                if textParam.category == "by-type" {
                    byTypeCount += 1
                    #expect(!hasBareTwin,
                            """
                            \(entry.component).\(textParam.name) 登记为 by-type，但源码里存在裸串孪生重载 —— \
                            按公约 §4 应判 B 类，请退回 #38 重新分类
                            """)
                } else if !hasBareTwin {
                    localizedBCount += 1
                    #expect(Bool(false),
                            """
                            \(entry.component).\(textParam.name) 登记为 \(textParam.category)，但源码里只有 LSK/LSR 入口、\
                            没有裸串孪生重载 —— 按公约 §4「无孪生重载 ⇒ by-type」应重新分类，请退回 #38
                            """)
                }
            }
        }
        #expect(byTypeCount == 8,
                "by-type 条目实测 8 条（Descriptions.header / SpinningModifier.text + 四个图表的 title + Banner.title / Banner.message），实际 \(byTypeCount)")
        #expect(localizedBCount == 0)
        let bcCount = entries.filter { $0.repo == "ohmydesign" }
            .flatMap(\.textParams).count - byTypeCount
        print("FR-4 by-type 核对：\(byTypeCount) 条 by-type 均无裸串孪生重载；\(bcCount) 条 B/C 均有裸串入口")
    }
}
