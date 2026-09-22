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

    // MARK: - removingTag(at:from:) — offset-based identity, duplicate-safe

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

    @Test("删中间项：存活 chip 的身份逐项不变（下标身份会让其后每项换身份）")
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

    @Test("删重复项：只有同值的后续出现降序号，异值项身份不变")
    func removingDuplicateOnlyRenumbersSameValue() {
        let before = ["bug", "bug", "enhancement"]
        let beforeChips = TagInput.chips(for: before)
        let after = TagInput.removingTag(at: 0, from: before)
        #expect(after == ["bug", "enhancement"])
        let afterChips = TagInput.chips(for: after)
        #expect(afterChips[1].id == beforeChips[2].id, "异值项 enhancement 换了身份")
        #expect(afterChips[0].id != beforeChips[1].id,
                "同值的后续出现应降序号 —— 这是本方案已登记的限制，不是可以静默的等价")
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
