import Foundation
@testable import OhMyDesign
import SwiftUI
import Testing

// MARK: - ⌥Space 的归约 / Option-Space reduction

@Suite("Tree 勾选的键盘通路：⌥Space 经归约带出目标行，不动选中 / 展开")
struct TreeCheckKeyboardReducerTests {
    private static func press(
        _ state: TreeInteractionState<String>,
        modifiers: EventModifiers = .option,
        checkColumn: TreeCheckColumn
    ) -> TreeInteractionOutcome<String> {
        TreeInteractionReducer.key(
            .space,
            modifiers: modifiers,
            state: state,
            rows: TreeJudgeFixture.rows(expanded: state.expanded),
            mode: .multiple,
            activation: .enabled,
            checkColumn: checkColumn,
            motion: .animated,
            treeIDs: { TreeJudgeFixture.treeIDs },
            ancestors: TreeJudgeFixture.ancestors(of:)
        )
    }

    private static func state(focus: String?, selection: Set<String> = []) -> TreeInteractionState<String> {
        TreeInteractionState(focus: focus, lastInteraction: .pointer, selection: selection, expanded: ["a"])
    }

    @Test("有勾选列：⌥Space 接住，带出焦点行，选中与展开不变，交互来源置为键盘")
    func optionSpaceCarriesTheFocusedRow() {
        let outcome = Self.press(Self.state(focus: "a1", selection: ["b"]), checkColumn: .present)
        #expect(outcome.result == .handled)
        #expect(outcome.checkToggled == "a1")
        #expect(outcome.state.selection == ["b"])
        #expect(outcome.state.expanded == ["a"])
        #expect(outcome.state.lastInteraction == .keyboard)
        #expect(outcome.activated == nil)
    }

    @Test("没有勾选列：⌥Space 交回系统，不带出目标")
    func optionSpaceWithoutCheckColumnIsIgnored() {
        let outcome = Self.press(Self.state(focus: "a1"), checkColumn: .absent)
        #expect(outcome.result == .ignored)
        #expect(outcome.checkToggled == nil)
    }

    @Test("首键到达时还没有焦点：按初始焦点规则解析后勾选那一行")
    func theFirstOptionSpaceResolvesTheInitialFocus() {
        let outcome = Self.press(Self.state(focus: nil, selection: ["b"]), checkColumn: .present)
        #expect(outcome.checkToggled == "b")
    }

    @Test("不带修饰键的 Space 仍只切换选中，不带出勾选目标")
    func plainSpaceStillSelects() {
        let outcome = Self.press(Self.state(focus: "a1"), modifiers: [], checkColumn: .present)
        #expect(outcome.checkToggled == nil)
        #expect(outcome.state.selection == ["a1"])
    }
}

// MARK: - 按行切换勾选 / Row check toggling

@Suite("TreeChecking.togglingRow：叶行切换自身；父行 off / mixed → 全勾，on → 全不勾；只作用于范围内的叶子")
struct TreeCheckRowToggleTests {
    private static func toggle(_ id: String, in checked: Set<String>, within included: Set<String>? = nil) -> Set<String> {
        TreeChecking.togglingRow(
            TreeJudgeFixture.node(id), id: \TreeJudgeNode.id, children: \TreeJudgeNode.children,
            within: included, in: checked
        )
    }

    @Test("叶行：未勾 → 勾上，已勾 → 取消；其它勾选不动")
    func leafTogglesItself() {
        #expect(Self.toggle("b", in: ["c1"]) == ["b", "c1"])
        #expect(Self.toggle("b", in: ["b", "c1"]) == ["c1"])
    }

    @Test("父行三态：off → 全勾、mixed → 全勾、on → 全不勾；树里其它叶子不动")
    func parentCascades() {
        #expect(Self.toggle("a", in: ["c1"]) == ["a1x", "a1y", "a2", "c1"])
        #expect(Self.toggle("a", in: ["a1x", "c1"]) == ["a1x", "a1y", "a2", "c1"])
        #expect(Self.toggle("a", in: ["a1x", "a1y", "a2", "c1"]) == ["c1"])
        #expect(!Self.toggle("a", in: []).contains("a"), "父节点 ID 进了 checked")
    }

    @Test("搜索期间只作用于保留的叶子：范围外的叶子勾选值不变")
    func searchScopeLimitsTheCascade() {
        let included: Set<String> = ["a", "a1", "a1x"]
        #expect(Self.toggle("a", in: ["a2"], within: included) == ["a1x", "a2"])
        #expect(Self.toggle("a", in: ["a1x", "a2"], within: included) == ["a2"])
    }
}

// MARK: - 勾选的无障碍动作 / Check accessibility action

@Suite("Tree 行上的「勾选 / 取消勾选」无障碍动作")
struct TreeCheckAccessibilityTests {
    @Test("范围内的叶子全勾时动作名是 Uncheck，否则是 Check")
    func actionNameFollowsTheScope() {
        #expect(TreeRowAccessibility.checkActionKey(scope: ["a1x", "a2"], in: ["a1x", "a2"]) == "Uncheck")
        #expect(TreeRowAccessibility.checkActionKey(scope: ["a1x", "a2"], in: ["a1x"]) == "Check")
        #expect(TreeRowAccessibility.checkActionKey(scope: ["a1x", "a2"], in: []) == "Check")
        #expect(TreeRowAccessibility.checkActionKey(scope: [String](), in: ["a1x"]) == "Check")
    }

    @Test("两个动作名 key 都在模块的 Localizable.strings 里")
    func actionKeysAreRegistered() throws {
        let url = GuardScanRoots.repoRoot.appendingPathComponent("Sources/OhMyDesign/Resources/en.lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        for key in [TreeRowAccessibility.checkActionKey, TreeRowAccessibility.uncheckActionKey] {
            #expect(text.contains("\"\(key)\" = "), "Localizable.strings 里缺 \(key)")
        }
    }
}
