import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("TagInput")
struct TagInputTests {
    // MARK: - Construction

    @MainActor
    @Test("tag input constructs with default parameters")
    func tagInputConstructsWithDefaults() {
        let input = TagInput(tags: .constant(["bug"]))
        #expect(type(of: input) == TagInput.self)
    }

    @MainActor
    @Test("tag input constructs with all parameters")
    func tagInputConstructsWithAllParameters() {
        let input = TagInput(
            tags: .constant([]),
            placeholder: "Add label",
            tagColor: .blue,
            allowDuplicates: true,
            onCommit: { _ in }
        )
        #expect(type(of: input) == TagInput.self)
    }

    // MARK: - normalizedTag

    @Test("normalizedTag trims surrounding whitespace")
    func normalizedTagTrimsWhitespace() {
        #expect(TagInput.normalizedTag("  bug  ") == "bug")
    }

    @Test("normalizedTag trims surrounding newlines")
    func normalizedTagTrimsNewlines() {
        #expect(TagInput.normalizedTag("\nbug\n") == "bug")
    }

    @Test("normalizedTag returns nil for empty string")
    func normalizedTagReturnsNilForEmpty() {
        #expect(TagInput.normalizedTag("") == nil)
    }

    @Test("normalizedTag returns nil for whitespace-only string")
    func normalizedTagReturnsNilForWhitespaceOnly() {
        #expect(TagInput.normalizedTag("   ") == nil)
    }

    @Test("normalizedTag preserves internal whitespace")
    func normalizedTagPreservesInternalWhitespace() {
        #expect(TagInput.normalizedTag("  good first issue  ") == "good first issue")
    }

    @Test("normalizedTag is case sensitive (no normalization)")
    func normalizedTagIsCaseSensitive() {
        #expect(TagInput.normalizedTag("Bug") == "Bug")
        #expect(TagInput.normalizedTag("Bug") != TagInput.normalizedTag("bug"))
    }

    // MARK: - tagToCommit (dedupe policy)

    @Test("tagToCommit returns normalized tag when not a duplicate")
    func tagToCommitReturnsNormalizedTag() {
        let result = TagInput.tagToCommit("  enhancement  ", into: ["bug"], allowDuplicates: false)
        #expect(result == "enhancement")
    }

    @Test("tagToCommit returns nil for blank input regardless of dedupe policy")
    func tagToCommitReturnsNilForBlank() {
        #expect(TagInput.tagToCommit("   ", into: ["bug"], allowDuplicates: false) == nil)
        #expect(TagInput.tagToCommit("   ", into: ["bug"], allowDuplicates: true) == nil)
    }

    @Test("tagToCommit rejects duplicate when allowDuplicates is false")
    func tagToCommitRejectsDuplicateWhenDisallowed() {
        let result = TagInput.tagToCommit("bug", into: ["bug"], allowDuplicates: false)
        #expect(result == nil)
    }

    @Test("tagToCommit allows duplicate when allowDuplicates is true")
    func tagToCommitAllowsDuplicateWhenEnabled() {
        let result = TagInput.tagToCommit("bug", into: ["bug"], allowDuplicates: true)
        #expect(result == "bug")
    }

    @Test("tagToCommit dedupe check is case sensitive")
    func tagToCommitDedupeIsCaseSensitive() {
        let result = TagInput.tagToCommit("Bug", into: ["bug"], allowDuplicates: false)
        #expect(result == "Bug")
    }

    // MARK: - splitDraftOnSeparator (comma-delimited quick entry)

    @Test("splitDraftOnSeparator returns no segments when draft has no comma")
    func splitDraftOnSeparatorNoComma() {
        let result = TagInput.splitDraftOnSeparator("bug")
        #expect(result.segments.isEmpty)
        #expect(result.remainder == "bug")
    }

    @Test("splitDraftOnSeparator splits multiple comma-separated segments")
    func splitDraftOnSeparatorSplitsSegments() {
        let result = TagInput.splitDraftOnSeparator("bug, enhancement,")
        #expect(result.segments == ["bug", " enhancement"])
        #expect(result.remainder == "")
    }

    @Test("splitDraftOnSeparator keeps the trailing partial segment as remainder")
    func splitDraftOnSeparatorKeepsRemainder() {
        let result = TagInput.splitDraftOnSeparator("bug,enh")
        #expect(result.segments == ["bug"])
        #expect(result.remainder == "enh")
    }

    // MARK: - removingTag(at:from:) — 按下标定位删除，重复项安全

    @Test("removingTag deletes the correct element among duplicates by offset")
    func removingTagHandlesDuplicatesByOffset() {
        let result = TagInput.removingTag(at: 0, from: ["bug", "bug", "enhancement"])
        #expect(result == ["bug", "enhancement"])
    }

    @Test("removingTag at the second duplicate leaves the first untouched")
    func removingSecondDuplicateLeavesFirst() {
        let result = TagInput.removingTag(at: 1, from: ["bug", "bug", "enhancement"])
        #expect(result == ["bug", "enhancement"])
    }

    @Test("removingTag with an out-of-range index is a no-op")
    func removingTagOutOfRangeIsNoOp() {
        let result = TagInput.removingTag(at: 5, from: ["bug"])
        #expect(result == ["bug"])
    }

    @Test("removingTag with a negative index is a no-op")
    func removingTagNegativeIndexIsNoOp() {
        let result = TagInput.removingTag(at: -1, from: ["bug"])
        #expect(result == ["bug"])
    }

    // MARK: - chips(for:) — 值 + 出现序号的稳定身份

    @Test("chips：唯一标签逐项身份互异，index 与数组下标对齐")
    func chipsGiveDistinctIdentitiesForUniqueTags() {
        let chips = TagInput.chips(for: ["bug", "enhancement", "docs"])
        #expect(chips.map(\.value) == ["bug", "enhancement", "docs"])
        #expect(chips.map(\.index) == [0, 1, 2])
        #expect(chips.map(\.occurrence) == [0, 0, 0])
        #expect(Set(chips.map(\.id)).count == 3)
    }

    @Test("chips：重复标签按出现序号区分，身份仍逐项互异")
    func chipsDistinguishDuplicatesByOccurrence() {
        let chips = TagInput.chips(for: ["bug", "bug", "bug"])
        #expect(chips.map(\.occurrence) == [0, 1, 2])
        #expect(Set(chips.map(\.id)).count == 3, "重复标签的身份撞了：\(chips.map(\.id))")
    }

    @Test("chips：空数组给出空身份表")
    func chipsOnEmptyTags() {
        #expect(TagInput.chips(for: []).isEmpty)
    }

    @Test("删中间项：存活 chip 的身份逐项不变（下标身份会把其后每项重新绑定到另一个值）")
    func removingMiddleTagKeepsSurvivorIdentities() {
        let before = ["bug", "enhancement", "docs", "chore"]
        let after = TagInput.removingTag(at: 1, from: before)
        #expect(after == ["bug", "docs", "chore"])
        let survivorIDs = TagInput.chips(for: before).filter { $0.index != 1 }.map(\.id)
        #expect(TagInput.chips(for: after).map(\.id) == survivorIDs,
                "删中间项后存活项换了身份 —— 增删动画会画在错的 chip 上")
        #expect(TagInput.chips(for: after).map(\.index) == [0, 1, 2],
                "index 没有跟着重排 —— 删除会命中错的下标")
    }

    @Test("值唯一时：消失的身份正是被点的那一项，且没有任何存活身份被重新绑定到另一个值")
    func uniqueValuesLoseExactlyTheTappedIdentity() {
        let tags = ["bug", "enhancement", "docs", "chore"]
        let before = TagInput.chips(for: tags)
        let beforeByID = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0.value) })
        for index in tags.indices {
            let after = TagInput.chips(for: TagInput.removingTag(at: index, from: tags))
            let afterByID = Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0.value) })
            #expect(
                Set(beforeByID.keys).subtracting(afterByID.keys) == [before[index].id],
                "删下标 \(index)：消失的身份是 \(Set(beforeByID.keys).subtracting(afterByID.keys))，应正是被点的 \(before[index].id)"
            )
            #expect(
                Set(afterByID.keys).subtracting(beforeByID.keys).isEmpty,
                "删下标 \(index)：凭空多出身份 \(Set(afterByID.keys).subtracting(beforeByID.keys))"
            )
            let rebound = afterByID.filter { beforeByID[$0.key] != $0.value }
            #expect(
                rebound.isEmpty,
                """
                删下标 \(index)：这些身份被重新绑定到了另一个值 \(rebound) \
                —— 这正是下标身份的老毛病（chip 原地把 label 换成邻居的文案）
                """
            )
        }
    }

    @Test("删重复项：异值项身份不变，留下的同值项复用原身份，消失的是末次出现")
    func removingDuplicateReusesSameValueIdentities() {
        let tags = ["bug", "bug", "enhancement"]
        let before = TagInput.chips(for: tags)
        let after = TagInput.chips(for: TagInput.removingTag(at: 0, from: tags))
        #expect(after.map(\.value) == ["bug", "enhancement"])
        #expect(after[0].id == before[0].id,
                "留下的 bug 没有复用 (bug, 0) —— 它会被 ForEach 当成新插入的 chip")
        #expect(after[1].id == before[2].id, "异值项 enhancement 换了身份")
        #expect(Set(before.map(\.id)).subtracting(after.map(\.id)) == [before[1].id],
                "消失的身份不是末次出现 (bug, 1)")
    }

    @Test("删任一次重复出现：身份集合只少一个「值 + 最大序号」，没有任何新增（交错重复）")
    func duplicateRemovalReusesIdentitiesAndDropsTheLastOccurrence() throws {
        let tags = ["a", "b", "a", "c", "a"]
        let before = TagInput.chips(for: tags)
        let beforeIDs = Set(before.map(\.id))
        let lastOccurrence = try #require(before.last { $0.value == "a" })
        #expect(lastOccurrence.index == 4 && lastOccurrence.occurrence == 2, "样本不对，判据无效：\(lastOccurrence)")
        for index in [0, 2, 4] {
            let afterIDs = Set(TagInput.chips(for: TagInput.removingTag(at: index, from: tags)).map(\.id))
            #expect(
                afterIDs.subtracting(beforeIDs).isEmpty,
                "删下标 \(index)：凭空多出身份 \(afterIDs.subtracting(beforeIDs)) —— 不该有插入"
            )
            #expect(
                beforeIDs.subtracting(afterIDs) == [lastOccurrence.id],
                """
                删下标 \(index)：消失的身份是 \(beforeIDs.subtracting(afterIDs))，应恒为末次出现 \(lastOccurrence.id)
                —— 这正是「退场动画播在末次出现上、不一定是用户点的那一个」这条限制的来源
                """
            )
        }
    }

    @Test("按 chip.index 删除命中的是该 chip 自己的那次出现")
    func removingByChipIndexHitsThatOccurrence() {
        let tags = ["a", "b", "a", "b", "a"]
        let target = TagInput.chips(for: tags)[2]
        #expect(target.value == "a" && target.occurrence == 1)
        #expect(TagInput.removingTag(at: target.index, from: tags) == ["a", "b", "b", "a"])
    }
}

// MARK: - 身份纪律 / Identity discipline

/// `chips(for:)` 的真值表证明**函数**给出稳定身份；这条判据证明**视图真的在用它**
/// —— 把 `ForEach` 改回 `Array(tags.enumerated())` / `id: \.offset` 时判红。
@Suite("TagInput 身份纪律：不得用下标作 chip 身份")
struct TagInputIdentityGuard {
    static let path = "Components/TagInput/TagInput.swift"

    static let forbidden = ["enumerated()", "\\.offset"]

    static func violations(in code: String) -> [String] {
        let stripped = CoreMotionTokenDisciplineGuard.stripComments(code)
        return Self.forbidden.filter { stripped.contains($0) }.map {
            "\(Self.path) 出现 `\($0)` —— chip 身份必须走 TagInput.chips(for:)（值 + 出现序号），不得用下标"
        }
    }

    @Test("TagInput.swift 不含下标身份的两个成分")
    func productionSourceIsFree() throws {
        let url = GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)
            .appendingPathComponent(Self.path)
        let code = try String(contentsOf: url, encoding: .utf8)
        #expect(code.contains("TagInput.chips(for:)") || code.contains("Self.chips(for:"),
                "扫到的文件里根本没有 chips(for:) —— 路径不对，零违规不作数")
        let offenders = Self.violations(in: code)
        #expect(offenders.isEmpty, "\n\(offenders.joined(separator: "\n"))")
    }

    @Test("自证：合成输入逐条判红，注释里提到不算违规")
    func scannerCatchesSyntheticViolations() {
        #expect(!Self.violations(in: "ForEach(Array(self.tags.enumerated()), id: \\.offset) { }").isEmpty)
        #expect(!Self.violations(in: "ForEach(self.tags.enumerated().map(Chip.init)) { }").isEmpty)
        #expect(!Self.violations(in: "ForEach(pairs, id: \\.offset) { }").isEmpty)
        #expect(Self.violations(in: "// 历史写法：id: \\.offset 会错位\nForEach(Self.chips(for: t)) { }").isEmpty)
        #expect(Self.violations(in: "ForEach(Self.chips(for: self.tags)) { chip in }").isEmpty)
    }
}
