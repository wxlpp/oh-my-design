import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 阶段真值表 / Phase truth table（#420 PR 3，双腿）

@Suite("Timeline 阶段真值表")
struct TimelinePhaseTruthTableTests {
    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let steps: [Int?]
        let progress: TimelineProgress?
        let phases: String
        let segments: String
        let position: CGFloat?

        var testDescription: String { "steps \(self.steps) × \(String(describing: self.progress))" }
    }

    private static func code(_ phase: TimelinePhase?) -> Character {
        switch phase {
        case nil: "-"
        case .completed: "C"
        case .inProgress: "I"
        case .upcoming: "U"
        }
    }

    nonisolated static let cases: [Case] = [
        Case(steps: [0, 1, 2, 3, 4], progress: nil, phases: "-----", segments: "0000", position: nil),
        Case(steps: [0, 1, 2, 3, 4], progress: .notStarted, phases: "UUUUU", segments: "0000", position: -1),
        Case(steps: [0, 1, 2, 3, 4], progress: .inProgress(at: -1), phases: "UUUUU", segments: "0000", position: -1),
        Case(steps: [0, 1, 2, 3, 4], progress: .inProgress(at: 0), phases: "IUUUU", segments: "0000", position: 0),
        Case(steps: [0, 1, 2, 3, 4], progress: .inProgress(at: 2), phases: "CCIUU", segments: "1100", position: 2),
        Case(steps: [0, 1, 2, 3, 4], progress: .inProgress(at: 4), phases: "CCCCI", segments: "1111", position: 4),
        Case(steps: [0, 1, 2, 3, 4], progress: .inProgress(at: 5), phases: "CCCCC", segments: "1111", position: 5),
        Case(steps: [0, 1, 2, 3, 4], progress: .completed, phases: "CCCCC", segments: "1111", position: 5),
        Case(steps: [0, 2, 4, 6], progress: .notStarted, phases: "UUUU", segments: "000", position: -1),
        Case(steps: [0, 2, 4, 6], progress: .inProgress(at: 2), phases: "CIUU", segments: "100", position: 2),
        Case(steps: [0, 2, 4, 6], progress: .inProgress(at: 3), phases: "CCUU", segments: "100", position: 3),
        Case(steps: [0, 2, 4, 6], progress: .completed, phases: "CCCC", segments: "111", position: 7),
        Case(steps: [0, 1, 1, 2], progress: .inProgress(at: 1), phases: "CIIU", segments: "110", position: 1),
        Case(steps: [2, 0, 1], progress: .notStarted, phases: "UUU", segments: "00", position: -1),
        Case(steps: [2, 0, 1], progress: .inProgress(at: 1), phases: "UCI", segments: "11", position: 1),
        Case(steps: [2, 0, 1], progress: .completed, phases: "CCC", segments: "11", position: 3),
        Case(steps: [0, nil, 2, nil], progress: .notStarted, phases: "U-U-", segments: "000", position: -1),
        Case(steps: [0, nil, 2, nil], progress: .inProgress(at: 2), phases: "C-I-", segments: "010", position: 2),
        Case(steps: [0, nil, 2, nil], progress: .completed, phases: "C-C-", segments: "010", position: 3),
        Case(steps: [nil, nil], progress: .completed, phases: "--", segments: "0", position: nil),
    ]

    private static func rowSlots(_ count: Int) -> [TimelineStackLayout.Slot] {
        (0..<count).map { .row(node: 2 * $0, content: 2 * $0 + 1) }
    }

    @Test("逐行：每行阶段、每段着色系数（看后一行：已完成 / 进行中 ⇒ 1）、推进位置", arguments: Self.cases)
    func truthTable(_ row: Case) {
        let phases = String(row.steps.map { step in
            Self.code(step.flatMap { step in row.progress?.phase(forStep: step) })
        })
        #expect(phases == row.phases, "\(row)：阶段 \(phases)，应为 \(row.phases)")
        let fractions = TimelineStackLayout.connectorFractions(
            slots: Self.rowSlots(row.steps.count), steps: row.steps, progress: row.progress, layout: .vertical
        )
        let segments = fractions.map { $0 == 1 ? "1" : ($0 == 0 ? "0" : "?") }.joined()
        #expect(segments == row.segments, "\(row)：段系数 \(fractions)，应为 \(row.segments)")
        #expect(TimelineStackLayout.progressPosition(steps: row.steps, progress: row.progress) == row.position,
                "\(row)：推进位置应为 \(String(describing: row.position))")
    }

    @Test(".inProgress(at: 末 step + 1) 与 .completed 画法相同，作为值不相等")
    func pastTheEndEqualsCompletedInRenderingOnly() {
        #expect(TimelineProgress.inProgress(at: 5) != .completed)
        for step in -2...6 {
            #expect(TimelineProgress.inProgress(at: 7).phase(forStep: step) == TimelineProgress.completed.phase(forStep: step))
        }
    }

    @Test("段系数：后一行 step 为 nil ⇒ 0（不随推进位置变化）；前一行为 nil 时按后一行算；落在 [0, 1]；极值不溢出")
    func segmentFractionNilNeighbours() {
        for position in [CGFloat(-100), -1, 0, 0.5, 3, 100] {
            #expect(TimelineStackLayout.segmentFraction(position: position, nextStep: nil) == 0)
        }
        #expect(TimelineStackLayout.segmentFraction(position: nil, nextStep: 0) == 0)
        #expect(TimelineStackLayout.segmentFraction(position: 1.5, nextStep: 1) == 1)
        #expect(TimelineStackLayout.segmentFraction(position: 0.25, nextStep: 1) == 0.25)
        #expect(TimelineStackLayout.segmentFraction(position: -3, nextStep: 1) == 0)
        #expect(TimelineStackLayout.segmentFraction(position: CGFloat(Int.max), nextStep: Int.min) == 1)
        #expect(TimelineStackLayout.segmentFraction(position: CGFloat(Int.min), nextStep: Int.max) == 0)
        #expect(TimelineStackLayout.progressPosition(steps: [Int.max], progress: .completed) == CGFloat(Int.max) + 1)
        #expect(TimelineProgress.inProgress(at: Int.min).phase(forStep: Int.min) == .inProgress)
    }

    @Test("连线系数的条数与容器发射的连线条数一致：隔着非行子视图仍一段（.alternate 按截断拆成多截、同一系数），.grouped 无连线")
    func connectorFractionsFollowConnectorCount() {
        let slots = TimelineStackLayout.pairParts(roles: [.node, .content, nil, .node, .content, .node, .content])
        let steps: [Int?] = [0, nil, 1, 2]
        for layout in [TimelineLayout.vertical, .alternate, .horizontal, .grouped] {
            let fractions = TimelineStackLayout.connectorFractions(
                slots: slots, steps: steps, progress: .inProgress(at: 1), layout: layout
            )
            #expect(fractions.count == TimelineStackLayout.connectorCount(slots: slots, layout: layout), "\(layout)")
        }
        #expect(TimelineStackLayout.connectorFractions(slots: slots, steps: steps, progress: .inProgress(at: 1), layout: .alternate)
                == [1, 1, 0])
        #expect(TimelineStackLayout.connectorFractions(slots: slots, steps: steps, progress: .inProgress(at: 1), layout: .vertical)
                == [1, 0])
    }
}

// MARK: - 无障碍取值 / Accessibility value（纯函数 + 源码双腿，运行期 iOS）

@Suite("Timeline 阶段无障碍取值")
@MainActor
struct TimelineAccessibilityValueTests {
    @Test("阶段键：Completed / In Progress / Upcoming，在 bundle 里有对应条目")
    func phaseKeysAreLocalized() {
        #expect(TimelinePhase.allCases.map { Timeline.accessibilityLabelKey(for: $0) } == ["Completed", "In Progress", "Upcoming"])
        for phase in TimelinePhase.allCases {
            let key = Timeline.accessibilityLabelKey(for: phase)
            let resolved = Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved == key, "Localizable.strings 缺少 \(key)（取到 \(resolved)）")
        }
    }

    @Test("值键序列：状态键在前、阶段键在后；挂载点只看有无标题；自定义节点不传 status 时只带阶段键；无阶段与 PR 2 相同")
    func valueKeysAppendPhase() {
        for phase in TimelinePhase.allCases {
            let key = Timeline.accessibilityLabelKey(for: phase)
            #expect(Timeline.accessibility(status: .danger, hasCustomNode: false, hasTitle: true, phase: phase)
                    == TimelineRowAccessibility(valueKeys: ["Error", key], mount: .title, combinesContent: false))
            #expect(Timeline.accessibility(status: nil, hasCustomNode: false, hasTitle: false, phase: phase)
                    == TimelineRowAccessibility(valueKeys: ["Info", key], mount: .content, combinesContent: true))
            #expect(Timeline.accessibility(status: nil, hasCustomNode: true, hasTitle: false, phase: phase)
                    == TimelineRowAccessibility(valueKeys: [key], mount: .content, combinesContent: true))
            #expect(Timeline.accessibility(status: nil, hasCustomNode: true, hasTitle: true, phase: phase)
                    == TimelineRowAccessibility(valueKeys: [key], mount: .title, combinesContent: false))
            #expect(Timeline.accessibility(status: .success, hasCustomNode: true, hasTitle: false, phase: phase)
                    == TimelineRowAccessibility(valueKeys: ["Success", key], mount: .content, combinesContent: true))
        }
        #expect(Timeline.accessibility(status: nil, hasCustomNode: true, hasTitle: false, phase: nil)
                == TimelineRowAccessibility(valueKeys: [], mount: .none, combinesContent: false))
        #expect(TimelineRowAccessibility(valueKeys: ["Error", "In Progress"], mount: .title, combinesContent: false).valueText
                == "Error, In Progress")
    }

    private static func source() throws -> String {
        let url = GuardScanRoots.repoRoot.appendingPathComponent("Sources/OhMyDesign/Components/Timeline/Timeline.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("接线（源码）：容器在解析前下发 progress；行把阶段施给节点与内容两槽、并传进挂载点函数；连线按系数取 .tint")
    func phaseWiringInSource() throws {
        let source = try Self.source()
        for call in [
            ".environment(\\.timelineProgressContext, self.progress)\n        ) { subviews in",
            "TimelineNodeView(status: self.status ?? .info, phase: phase, node: self.node)\n            .environment(\\.timelinePhase, phase)",
            "self.contentSlot\n            .environment(\\.timelinePhase, phase)",
            "hasTitle: self.title != nil, phase: self.phase",
            "return progress.phase(forStep: step)",
            "TimelineConnector(fraction: fractions[index]",
            ".fill(.tint)",
        ] {
            #expect(source.contains(call), "Timeline.swift 缺少 \(call)")
        }
    }

    #if os(iOS)
    @Test("接线（iOS 无障碍树）：状态与阶段以「, 」并入标题 / 合并内容元素的值；自定义节点不传 status 只带阶段；无 step 的行不带阶段")
    func phaseValuesInAccessibilityTree() {
        let tree = TimelineCompositionTests.accessibilityTree(Timeline(progress: .inProgress(at: 1)) {
            TimelineItem("Alpha", step: 0, status: .danger)
            TimelineItem(step: 1, status: .success) { Text(verbatim: "Beta") }
            TimelineItem(step: 2) { Text(verbatim: "N") } content: { Text(verbatim: "Delta") }
            TimelineItem { Text(verbatim: "M") } content: { Text(verbatim: "Eps") }
        })
        let flat = tree.map { "\($0.label ?? "nil")|\($0.value ?? "nil")" }
        #expect(flat == ["Alpha|Error, Completed", "Beta|Success, In Progress", "N|nil", "Delta|Upcoming", "M|nil", "Eps|nil"],
                "无障碍树 \(flat)")
    }
    #endif
}

// MARK: - 与 Steps 不共用类型 / Isolation from Steps（源码，双腿）

@Suite("Timeline 与 Steps 不共用阶段类型")
struct TimelineStepsIsolationGuard {
    private static func sources(in directory: String) throws -> String {
        let root = GuardScanRoots.repoRoot.appendingPathComponent(directory)
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "\(directory) 下没有 Swift 文件，判据无从下结论")
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    @Test("Timeline 目录不引用 StepsProgress / StepItem；Steps 目录不引用 TimelineProgress / TimelinePhase")
    func noSharedPhaseTypes() throws {
        let timeline = try Self.sources(in: "Sources/OhMyDesign/Components/Timeline")
        let steps = try Self.sources(in: "Sources/OhMyDesign/Components/Steps")
        #expect(timeline.contains("enum TimelineProgress") && steps.contains("enum StepsProgress"), "两边的阶段类型没找到，判据失效")
        for name in ["StepsProgress", "StepItem"] {
            #expect(!timeline.contains(name), "Timeline 引用了 \(name)")
        }
        for name in ["TimelineProgress", "TimelinePhase"] {
            #expect(!steps.contains(name), "Steps 引用了 \(name)")
        }
    }
}

// MARK: - 位图（macOS，不走 asset catalog 的颜色）

#if os(macOS)
@Suite("Timeline 阶段位图")
@MainActor
struct TimelinePhaseRenderTests {
    private struct Canvas {
        let pixels: HostedPixels

        func at(_ x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
            let px = Int(x * self.pixels.scale), py = Int(y * self.pixels.scale)
            guard let bytes = self.pixels.bytes, px >= 0, py >= 0, px < self.pixels.width, py < self.pixels.height else {
                return (-1, -1, -1)
            }
            let offset = (py * self.pixels.width + px) * 4
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
        }

        func delta(_ x: CGFloat, _ y: CGFloat) -> Int {
            let p = self.at(x, y)
            return p.r < 0 ? -1 : Swift.max(255 - p.r, 255 - p.g, 255 - p.b)
        }

        func inkExtent(row y: CGFloat, x: ClosedRange<CGFloat>) -> CGFloat {
            let scale = self.pixels.scale
            let marked = stride(from: x.lowerBound, through: x.upperBound, by: 1 / scale).filter { self.delta($0, y) > 12 }
            guard let first = marked.first, let last = marked.last else { return 0 }
            return last - first + 1 / scale
        }
    }

    private static func render(_ view: some View, size: CGSize = CGSize(width: 300, height: 300)) -> Canvas {
        Canvas(pixels: renderTimelineFixture(
            view
                .environment(\.coreMotionPresentationOverride, .resting)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white),
            size: size, scheme: .light
        ))
    }

    private static func block() -> some View {
        Color(red: 0, green: 0, blue: 1).frame(width: 60, height: 40)
    }

    private static func fiveRows(progress: TimelineProgress?, tint: Color = .black) -> some View {
        Group {
            if let progress {
                Timeline(progress: progress) {
                    ForEach(0..<5, id: \.self) { step in TimelineItem(step: step, status: .neutral) { Self.block() } }
                }
            } else {
                Timeline {
                    ForEach(0..<5, id: \.self) { step in TimelineItem(step: step, status: .neutral) { Self.block() } }
                }
            }
        }
        .tint(tint)
    }

    private static func segmentMidY(_ segment: Int) -> CGFloat {
        CGFloat(segment) * 56 + 40
    }

    private static func isDark(_ p: (r: Int, g: Int, b: Int)) -> Bool {
        p.r >= 0 && p.r < 40 && p.g < 40 && p.b < 40
    }

    @Test("着色接线：.tint(.black)、.inProgress(at: 2) ⇒ 通向已完成 / 进行中行的前两段黑、后两段底线色；.completed 四段全黑；不传 progress 四段全是底线色")
    func connectorColoring() {
        let expectations: [(TimelineProgress?, [Bool])] = [
            (.inProgress(at: 2), [true, true, false, false]),
            (.completed, [true, true, true, true]),
            (.notStarted, [false, false, false, false]),
            (nil, [false, false, false, false]),
        ]
        for (progress, dark) in expectations {
            let canvas = Self.render(Self.fiveRows(progress: progress))
            for (segment, isDark) in dark.enumerated() {
                let pixel = canvas.at(12, Self.segmentMidY(segment))
                let line = canvas.delta(12, Self.segmentMidY(segment))
                #expect(Self.isDark(pixel) == isDark && line >= 6,
                        "\(String(describing: progress)) 第 \(segment) 段中部 \(pixel)，应为\(isDark ? "黑（.tint）" : "底线色（非黑、与背景差 ≥ 6）")")
            }
        }
    }

    @Test("着色走 .tint：调用方 .tint(红) ⇒ 已到达段为红")
    func connectorFollowsTint() {
        let canvas = Self.render(Self.fiveRows(progress: .completed, tint: Color(red: 1, green: 0, blue: 0)))
        let pixel = canvas.at(12, Self.segmentMidY(1))
        #expect(pixel.r > 200 && pixel.g < 60 && pixel.b < 60, "已到达段 \(pixel)，应随 .tint 为红")
    }

    @Test(".horizontal 同一着色规则：.inProgress(at: 1) ⇒ 第 0 段黑、其余底线色")
    func horizontalConnectorColoring() {
        let canvas = Self.render(Timeline(layout: .horizontal, progress: .inProgress(at: 1)) {
            ForEach(0..<4, id: \.self) { step in TimelineItem(step: step, status: .neutral) { Self.block() } }
        }.tint(.black), size: CGSize(width: 400, height: 120))
        let pitch = 60 + CoreSpacing.lg
        for (segment, isDark) in [true, false, false].enumerated() {
            let x = CGFloat(segment) * pitch + 60 + CoreSpacing.lg / 2
            let pixel = canvas.at(x, 12)
            #expect(Self.isDark(pixel) == isDark && canvas.delta(x, 12) >= 6,
                    "第 \(segment) 段中部 (\(x), 12) \(pixel)，应为\(isDark ? "黑" : "底线色")")
        }
    }

    private static func singleRow(_ progress: TimelineProgress?) -> Canvas {
        let row = TimelineItem(step: 0, status: .neutral) { Color.clear.frame(width: 10, height: 10) }
        return Self.render(Group {
            if let progress {
                Timeline(progress: progress) { row }
            } else {
                Timeline { row }
            }
        }, size: CGSize(width: 60, height: 40))
    }

    @Test("默认圆点形态：已完成 / 活动流实心 Ø10；未开始空心 Ø10（中心为底色）；进行中实心 Ø10 + Ø18 外环（环与圆点之间留空）")
    func defaultDotShapes() {
        for progress in [nil, TimelineProgress.completed] {
            let canvas = Self.singleRow(progress)
            #expect(abs(canvas.inkExtent(row: 12, x: 0...24) - 10) <= 1 && canvas.delta(12, 12) > 12,
                    "\(String(describing: progress))：宽 \(canvas.inkExtent(row: 12, x: 0...24))、中心差 \(canvas.delta(12, 12))，应为实心 Ø10")
        }
        let upcoming = Self.singleRow(.notStarted)
        #expect(abs(upcoming.inkExtent(row: 12, x: 0...24) - 10) <= 1 && upcoming.delta(12, 12) <= 2 && upcoming.delta(8, 12) > 12,
                "未开始：宽 \(upcoming.inkExtent(row: 12, x: 0...24))、中心差 \(upcoming.delta(12, 12))、环上差 \(upcoming.delta(8, 12))，应为空心 Ø10")
        let inProgress = Self.singleRow(.inProgress(at: 0))
        #expect(abs(inProgress.inkExtent(row: 12, x: 0...24) - 18) <= 1 && inProgress.delta(12, 12) > 12
                && inProgress.delta(18, 12) <= 2 && inProgress.delta(20, 12) > 12,
                "进行中：宽 \(inProgress.inkExtent(row: 12, x: 0...24))、中心差 \(inProgress.delta(12, 12))、间隙差 \(inProgress.delta(18, 12))、外环差 \(inProgress.delta(20, 12))")
    }

    @Test("形态接线：三阶段两两应不同；已完成与活动流应相同")
    func phaseShapesDiffer() {
        let completed = Self.singleRow(.completed).pixels
        let activity = Self.singleRow(nil).pixels
        expectBitmapsEquivalent(completed.bytes, activity.bytes, maxChannelDelta: 2, "已完成与活动流不同")
        let shapes = [
            ("已完成", completed), ("进行中", Self.singleRow(.inProgress(at: 0)).pixels), ("未开始", Self.singleRow(.notStarted).pixels),
        ]
        let hollowArea = Int(Double.pi * 9 * completed.scale * completed.scale)
        for i in shapes.indices {
            for j in shapes.indices where j > i {
                let metrics = bitmapDifferenceMetrics(shapes[i].1.bytes, shapes[j].1.bytes)
                let differing = (metrics?.differingCount ?? 0) / 3
                #expect((metrics?.maxChannelDelta ?? 0) > 8 && differing >= hollowArea / 2,
                        "\(shapes[i].0) 与 \(shapes[j].0) 几乎相同（maxΔ=\(metrics?.maxChannelDelta ?? -1)，差异像素≈\(differing)，预期 ≥ \(hollowArea / 2)）")
            }
        }
    }
}
#endif
