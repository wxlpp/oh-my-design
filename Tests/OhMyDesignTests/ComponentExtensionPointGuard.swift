import Foundation
import Testing

// MARK: - 共享扫描入口 / Shared scan entry

enum ComponentJudgeSources {
    private static var cached: ComponentJudgeScanResult?

    static func scan() throws -> ComponentJudgeScanResult {
        if let cached = Self.cached { return cached }
        let result = try scanComponentJudgeInputs(roots: ComponentRegistryGuard.componentScanRoots)
        if !result.isEmpty { Self.cached = result }
        return result
    }
}

// MARK: - J-2

@Suite("J-2 样式扩展点")
struct ComponentExtensionPointGuard {
    @Test("J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）")
    func semanticComponentsHaveExtensionPoint() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeExtensionPoints(entries: entries, scan: scan)

        #expect(result.inspected.count == 16,
                "J-2 定义域实测 16 条（ActivityHeatmap/AvatarGroup/Banner/BeforeAfterSlider/NetworkGraph/OrbitingLogos/ProgressIndicator/RadarChart/Rating/RatingDisplay/RingChart/SegmentedControl/SpinningModifier/Steps/Timeline/Toast），实际 \(result.inspected.count) 条：\(result.inspected)")
        #expect(!result.satisfied.isEmpty,
                "没有任何语义组件被判为『扩展点存在』—— 扫描器失效时也会长这样，这不是零违规")
        #expect(result.satisfied["ProgressIndicator"]?.contains("ProgressViewStyle") == true,
                "nativeProtocol 通路未走通：\(result.satisfied["ProgressIndicator"] ?? "(缺)")")
        #expect(result.satisfied["Banner"]?.contains("BannerStyle") == true,
                "customStyleProtocol 通路未走通：\(result.satisfied["Banner"] ?? "(缺)")")
        #expect(result.satisfied["SegmentedControl"]?.contains("SegmentedControlStyle") == true,
                "customStyleProtocol 通路（第二例）未走通：\(result.satisfied["SegmentedControl"] ?? "(缺)")")
        #expect(result.satisfied["RatingDisplay"]?.contains("RatingStyle") == true,
                "customStyleProtocol 通路（#41 新增的第三例，与 Rating 复用同一个协议）未走通：\(result.satisfied["RatingDisplay"] ?? "(缺)")")
        #expect(result.satisfied["RadarChart"]?.contains("RadarChartLayout") == true,
                "styleEnum 通路（#312 形态 D2）未走通：\(result.satisfied["RadarChart"] ?? "(缺)")")
        #expect(result.satisfied["RingChart"]?.contains("RingChartLayout") == true,
                "styleEnum 通路（#312 形态 D2）未走通：\(result.satisfied["RingChart"] ?? "(缺)")")
        #expect(result.satisfied["ActivityHeatmap"]?.contains("ActivityHeatmapLayout") == true,
                "styleEnum 通路（#312 形态 D2）未走通：\(result.satisfied["ActivityHeatmap"] ?? "(缺)")")
        #expect(result.satisfied["BeforeAfterSlider"]?.contains("BeforeAfterSliderLayout") == true,
                "styleEnum 通路（#312 形态 D2）未走通：\(result.satisfied["BeforeAfterSlider"] ?? "(缺)")")
        #expect(result.satisfied["OrbitingLogos"]?.contains("OrbitingLogosLayout") == true,
                "styleEnum 通路（#312 形态 D2，裁定翻至出口 1 后进定义域）未走通：\(result.satisfied["OrbitingLogos"] ?? "(缺)")")

        #expect(result.missing.isEmpty,
                """
                J-2 出现缺口 \(result.missing.count) 条：\(result.missing.sorted())。
                \(result.diagnostics.joined(separator: "\n"))
                已知缺口集合已于 `#312` 收成空集并删除（五条扩展点全部以形态 D2 落地）。\
                新缺口 ⇒ 要么补扩展点，要么在公约 §2 走一次判定\
                （允许得出形态 C「承认差异存在、本轮不开扩展点」，须在 notes 写明理由）；\
                确需暂缓时，挂一个**尚未关闭**的承接 issue，再照公约 §4 重建 \
                knownMissingExtensionPoints + withKnownIssue（只包住本句）
                """)

        let bothProtocolFields = entries.filter {
            $0.repo == "ohmydesign" && $0.nativeProtocol != nil && $0.customStyleProtocol != nil
        }
        #expect(bothProtocolFields.isEmpty,
                """
                这些条目 nativeProtocol 与 customStyleProtocol 同时非空：\(bothProtocolFields.map(\.component))。\
                judgeExtensionPoints 会按 customStyleProtocol 优先裁决、静默略过 native 侧 —— \
                请回 #38 确认两字段是否应互斥，或把判据改成两侧都核对（并同步删掉本断言）
                """)

        #expect(result.skippedRepos == ["storyui": 25],
                "跨仓跳过计数变了：实际 \(result.skippedRepos)。CI 只 checkout 本仓，StoryUI 侧无源码可核对（移交 #43）；这个固定计数是唯一挡『静默删条目 / 改 repo』的机器判据")
        #expect(entries.filter { $0.repo == "storyui" && $0.kind == "semantic" }.isEmpty,
                "StoryUI 侧出现了 semantic 条目 —— J-2 在本仓无源码可核对，必须移交 #43 落地跨仓判据，不得靠裁决 (a) 的跳过静默放过")

        print("J-2 定义域 \(result.inspected.count) 条：\(result.inspected)")
        for (component, reason) in result.satisfied.sorted(by: { $0.key < $1.key }) {
            print("J-2 ✓ \(component)：\(reason)")
        }
        print("J-2 缺口 \(result.missing)"
              + (result.missing.isEmpty ? "（**空集** —— 扩展点缺口已全部收口）" : "（见上方失败消息）"))
        print("⚠️ J-2 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }
}
