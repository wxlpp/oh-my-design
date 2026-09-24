import SwiftUI

// MARK: - TimelineStackLayout

struct TimelineStackLayout: Layout {
    let layout: TimelineLayout
    let slots: [Slot]
    let partCount: Int

    nonisolated enum Role: Hashable, Sendable {
        case node
        case content
    }

    nonisolated enum Slot: Equatable, Sendable {
        case row(node: Int, content: Int)
        case free(Int)
    }

    nonisolated struct Segment: Equatable, Sendable {
        let from: Int
        let to: Int
        let free: [Int]
    }

    nonisolated struct AlternateRowMetrics: Equatable, Sendable {
        let slotWidth: CGFloat
        let nodeCenterX: CGFloat
        let rowWidth: CGFloat
    }

    nonisolated struct HorizontalAxis: Equatable, Sendable {
        let axisY: CGFloat
        let contentTop: CGFloat
    }

    nonisolated struct ConnectorPiece: Equatable, Sendable {
        let resting: CGFloat
        let nextStep: Int?
        let index: Int
        let count: Int

        func fraction(position: Double, target: Double?) -> CGFloat {
            guard let target, let nextStep = self.nextStep, position != target else { return self.resting }
            let segment = TimelineStackLayout.unit(position - Double(nextStep) + 1)
            return CGFloat(TimelineStackLayout.unit(segment * Double(self.count) - Double(self.index)))
        }
    }

    nonisolated struct DotMorph: Equatable, Sendable {
        let arrival: Double
        let completion: Double
    }

    nonisolated struct DotLayers: Equatable, Sendable {
        let hollow: Double
        let fill: Double
        let ring: Double
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        self.arrange(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = self.arrange(width: bounds.width, subviews: subviews)
        for placement in arrangement.placements {
            guard let subview = self.subview(placement.index, in: subviews) else { continue }
            subview.place(
                at: CGPoint(x: bounds.minX + placement.point.x, y: bounds.minY + placement.point.y),
                anchor: placement.anchor,
                proposal: placement.proposal
            )
        }
    }

    // MARK: - Arrangement

    private struct Placement {
        let index: Int
        let point: CGPoint
        let anchor: UnitPoint
        let proposal: ProposedViewSize
    }

    private struct Arrangement {
        var size: CGSize = .zero
        var placements: [Placement] = []

        mutating func place(_ index: Int, _ point: CGPoint, _ anchor: UnitPoint, _ proposal: ProposedViewSize) {
            self.placements.append(Placement(index: index, point: point, anchor: anchor, proposal: proposal))
        }
    }

    private static let nodeProposal = ProposedViewSize(
        width: Timeline.minimumNodeExtent, height: Timeline.minimumNodeExtent
    )

    private func arrange(width: CGFloat?, subviews: Subviews) -> Arrangement {
        guard !self.slots.isEmpty else { return Arrangement() }
        let boxes = self.slots.map { slot in
            guard case .row(let node, _) = slot, let subview = self.subview(node, in: subviews) else { return CGSize.zero }
            return Self.nodeBox(reported: subview.sizeThatFits(Self.nodeProposal))
        }
        let column = Self.nodeColumnWidth(boxWidths: self.rowIndices.map { boxes[$0].width })
        let connectors = Self.connectorIndices(slots: self.slots, layout: self.layout, partCount: self.partCount)
        switch self.layout {
        case .alternate:
            return self.arrangeAlternate(width: width, column: column, boxes: boxes, connectors: connectors, subviews: subviews)
        case .horizontal:
            return self.arrangeHorizontal(boxes: boxes, connectors: connectors, subviews: subviews)
        case .vertical, .grouped:
            return self.arrangeVertical(width: width, column: column, boxes: boxes, connectors: connectors, subviews: subviews)
        }
    }

    private func subview(_ index: Int, in subviews: Subviews) -> LayoutSubview? {
        let connectorCount = subviews.count - self.partCount
        let physical = index < self.partCount ? index + connectorCount : index - self.partCount
        return subviews.indices.contains(physical) ? subviews[physical] : nil
    }

    private var rowIndices: [Int] {
        self.slots.indices.filter { if case .row = self.slots[$0] { true } else { false } }
    }

    private static func contentIndex(_ slot: Slot) -> Int {
        switch slot {
        case .row(_, let content): content
        case .free(let index): index
        }
    }

    private func contentSizes(subviews: Subviews, proposal: (Int) -> ProposedViewSize) -> [CGSize] {
        self.slots.indices.map { slot in
            guard let subview = self.subview(Self.contentIndex(self.slots[slot]), in: subviews) else { return .zero }
            return subview.sizeThatFits(proposal(slot))
        }
    }

    private func arrangeVertical(
        width: CGFloat?, column: CGFloat, boxes: [CGSize], connectors: [[Int]], subviews: Subviews
    ) -> Arrangement {
        let contentX = column + CoreSpacing.md
        let finiteWidth = width.flatMap { $0.isFinite ? $0 : nil }
        let contentProposal = ProposedViewSize(width: finiteWidth.map { Swift.max(0, $0 - contentX) }, height: nil)
        let contents = self.contentSizes(subviews: subviews) { _ in contentProposal }
        let tops = Self.slotTops(boxes: boxes, contents: contents)

        var arrangement = Arrangement()
        for (slot, kind) in self.slots.enumerated() {
            if case .row(let node, _) = kind {
                arrangement.place(node, CGPoint(x: column / 2, y: tops[slot] + boxes[slot].height / 2), .center, Self.nodeProposal)
            }
            arrangement.place(Self.contentIndex(kind), CGPoint(x: contentX, y: tops[slot]), .topLeading, contentProposal)
        }
        for (segment, indices) in zip(Self.segments(slots: self.slots), connectors) {
            let start = tops[segment.from] + boxes[segment.from].height
            arrangement.placements += Self.verticalPieces(indices, axisX: column / 2, spans: [(start, tops[segment.to])])
        }
        let contentWidth = contents.map(\.width).max() ?? 0
        arrangement.size = CGSize(width: finiteWidth ?? contentX + contentWidth, height: tops.last ?? 0)
        return arrangement
    }

    private func arrangeAlternate(
        width: CGFloat?, column: CGFloat, boxes: [CGSize], connectors: [[Int]], subviews: Subviews
    ) -> Arrangement {
        let rowWidth: CGFloat
        if let width, width.isFinite {
            rowWidth = width
        } else {
            let ideal = self.rowIndices.map { slot in
                self.subview(Self.contentIndex(self.slots[slot]), in: subviews)?.sizeThatFits(.unspecified).width ?? 0
            }.max() ?? 0
            rowWidth = ideal * 2 + column + 2 * CoreSpacing.md
        }
        let metrics = Self.alternateRowMetrics(forRowWidth: rowWidth, nodeColumnWidth: column)
        let slotProposal = ProposedViewSize(width: metrics.slotWidth, height: nil)
        let freeProposal = ProposedViewSize(width: metrics.rowWidth, height: nil)
        let contents = self.contentSizes(subviews: subviews) { slot in
            if case .row = self.slots[slot] { slotProposal } else { freeProposal }
        }
        let tops = Self.slotTops(boxes: boxes, contents: contents)

        var arrangement = Arrangement()
        var rowOrdinal = 0
        for (slot, kind) in self.slots.enumerated() {
            switch kind {
            case .row(let node, let content):
                arrangement.place(
                    node, CGPoint(x: metrics.nodeCenterX, y: tops[slot] + boxes[slot].height / 2), .center, Self.nodeProposal
                )
                let contentX = rowOrdinal.isMultiple(of: 2)
                    ? metrics.slotWidth - contents[slot].width
                    : metrics.slotWidth + CoreSpacing.md + column + CoreSpacing.md
                arrangement.place(content, CGPoint(x: contentX, y: tops[slot]), .topLeading, slotProposal)
                rowOrdinal += 1
            case .free(let index):
                let x = (metrics.rowWidth - contents[slot].width) / 2
                arrangement.place(index, CGPoint(x: x, y: tops[slot]), .topLeading, freeProposal)
            }
        }
        for (segment, indices) in zip(Self.segments(slots: self.slots), connectors) {
            var spans: [(CGFloat, CGFloat)] = []
            var start = tops[segment.from] + boxes[segment.from].height
            for free in segment.free {
                spans.append((start, tops[free]))
                start = tops[free] + contents[free].height
            }
            spans.append((start, tops[segment.to]))
            arrangement.placements += Self.verticalPieces(indices, axisX: metrics.nodeCenterX, spans: spans)
        }
        arrangement.size = CGSize(width: metrics.rowWidth, height: tops.last ?? 0)
        return arrangement
    }

    private func arrangeHorizontal(boxes: [CGSize], connectors: [[Int]], subviews: Subviews) -> Arrangement {
        let axis = Self.horizontalAxis(boxHeights: self.rowIndices.map { boxes[$0].height })
        let contents = self.contentSizes(subviews: subviews) { _ in .unspecified }
        let columnWidths = self.slots.indices.map { Swift.max(boxes[$0].width, contents[$0].width) }

        var arrangement = Arrangement()
        var columnX: [CGFloat] = []
        var x: CGFloat = 0
        for (slot, kind) in self.slots.enumerated() {
            columnX.append(x)
            let centerX = x + columnWidths[slot] / 2
            if case .row(let node, _) = kind {
                arrangement.place(node, CGPoint(x: centerX, y: axis.axisY), .center, Self.nodeProposal)
            }
            arrangement.place(
                Self.contentIndex(kind), CGPoint(x: centerX - contents[slot].width / 2, y: axis.contentTop),
                .topLeading, .unspecified
            )
            x += columnWidths[slot] + CoreSpacing.lg
        }
        for (segment, indices) in zip(Self.segments(slots: self.slots), connectors) {
            guard let index = indices.first else { continue }
            let start = columnX[segment.from] + columnWidths[segment.from] / 2 + boxes[segment.from].width / 2
            let end = columnX[segment.to] + columnWidths[segment.to] / 2 - boxes[segment.to].width / 2
            arrangement.place(
                index, CGPoint(x: start, y: axis.axisY), .leading,
                ProposedViewSize(width: Self.connectorSpan(from: start, to: end), height: CoreBorderWidth.thin)
            )
        }
        let contentHeight = contents.map(\.height).max() ?? 0
        arrangement.size = CGSize(
            width: Swift.max(0, x - CoreSpacing.lg), height: axis.contentTop + contentHeight
        )
        return arrangement
    }

    private static func slotTops(boxes: [CGSize], contents: [CGSize]) -> [CGFloat] {
        var tops: [CGFloat] = [0]
        for slot in boxes.indices {
            let height = Self.verticalRowHeight(
                box: boxes[slot].height, content: contents[slot].height, isLast: slot == boxes.count - 1
            )
            tops.append(tops[slot] + height)
        }
        return tops
    }

    private static func verticalPieces(_ indices: [Int], axisX: CGFloat, spans: [(CGFloat, CGFloat)]) -> [Placement] {
        zip(indices, spans).map { index, span in
            Placement(
                index: index, point: CGPoint(x: axisX, y: span.0), anchor: .top,
                proposal: ProposedViewSize(width: CoreBorderWidth.thin, height: Self.connectorSpan(from: span.0, to: span.1))
            )
        }
    }
}

// MARK: - 纯函数 / Pure geometry

extension TimelineStackLayout {
    nonisolated static func pairParts(roles: [Role?]) -> [Slot] {
        var slots: [Slot] = []
        var index = 0
        while index < roles.count {
            if roles[index] == .node, index + 1 < roles.count, roles[index + 1] == .content {
                slots.append(.row(node: index, content: index + 1))
                index += 2
            } else {
                slots.append(.free(index))
                index += 1
            }
        }
        return slots
    }

    nonisolated static func readingPriorities(slots: [Slot], partCount: Int) -> [Double] {
        var priorities = [Double](repeating: 0, count: partCount)
        for (ordinal, slot) in slots.enumerated() {
            switch slot {
            case .row(let node, let content):
                if priorities.indices.contains(node) { priorities[node] = -Double(2 * ordinal) }
                if priorities.indices.contains(content) { priorities[content] = -Double(2 * ordinal + 1) }
            case .free(let index):
                if priorities.indices.contains(index) { priorities[index] = -Double(2 * ordinal) }
            }
        }
        return priorities
    }

    nonisolated static func segments(slots: [Slot]) -> [Segment] {
        var segments: [Segment] = []
        var previous: Int?
        var free: [Int] = []
        for (index, slot) in slots.enumerated() {
            switch slot {
            case .row:
                if let previous {
                    segments.append(Segment(from: previous, to: index, free: free))
                }
                previous = index
                free = []
            case .free:
                if previous != nil { free.append(index) }
            }
        }
        return segments
    }

    nonisolated static func connectorPieces(slots: [Slot], layout: TimelineLayout) -> [(segment: Segment, pieces: Int)] {
        guard layout != .grouped else { return [] }
        return Self.segments(slots: slots).map { segment in
            (segment, layout == .alternate ? segment.free.count + 1 : 1)
        }
    }

    nonisolated static func connectorIndices(slots: [Slot], layout: TimelineLayout, partCount: Int) -> [[Int]] {
        var next = partCount
        return Self.connectorPieces(slots: slots, layout: layout).map { entry in
            defer { next += entry.pieces }
            return Array(next..<(next + entry.pieces))
        }
    }

    nonisolated static func segmentFraction(progress: TimelineProgress?, nextStep: Int?) -> CGFloat {
        guard let progress, let nextStep else { return 0 }
        return progress.phase(forStep: nextStep) != .upcoming ? 1 : 0
    }

    nonisolated static func connectorFractions(
        slots: [Slot], steps: [Int?], progress: TimelineProgress?, layout: TimelineLayout
    ) -> [CGFloat] {
        Self.connectorMotionPieces(slots: slots, steps: steps, progress: progress, layout: layout).map(\.resting)
    }

    nonisolated static func connectorMotionPieces(
        slots: [Slot], steps: [Int?], progress: TimelineProgress?, layout: TimelineLayout
    ) -> [ConnectorPiece] {
        Self.connectorPieces(slots: slots, layout: layout).flatMap { entry in
            let nextStep = steps.indices.contains(entry.segment.to) ? steps[entry.segment.to] : nil
            let resting = Self.segmentFraction(progress: progress, nextStep: nextStep)
            return (0..<entry.pieces).map {
                ConnectorPiece(resting: resting, nextStep: nextStep, index: $0, count: entry.pieces)
            }
        }
    }

    nonisolated static func dotMorph(step: Int?, position: Double, target: Double?) -> DotMorph? {
        guard let step, let target, position != target else { return nil }
        let offset = position - Double(step)
        return DotMorph(arrival: Self.unit(offset + 1), completion: Self.unit(offset))
    }

    nonisolated static func dotLayers(phase: TimelinePhase?, morph: DotMorph?) -> DotLayers {
        if let morph {
            return DotLayers(
                hollow: morph.arrival < 1 ? 1 : 0, fill: morph.arrival,
                ring: Swift.min(morph.arrival, 1 - morph.completion)
            )
        }
        switch phase {
        case nil, .completed: return DotLayers(hollow: 0, fill: 1, ring: 0)
        case .inProgress: return DotLayers(hollow: 0, fill: 1, ring: 1)
        case .upcoming: return DotLayers(hollow: 1, fill: 0, ring: 0)
        }
    }

    nonisolated static func unit(_ value: Double) -> Double {
        value.isFinite ? Swift.min(1, Swift.max(0, value)) : (value > 0 ? 1 : 0)
    }

    nonisolated static func nodeBox(reported: CGSize) -> CGSize {
        CGSize(width: Self.extent(reported.width), height: Self.extent(reported.height))
    }

    nonisolated static func nodeColumnWidth(boxWidths: [CGFloat]) -> CGFloat {
        boxWidths.reduce(Timeline.minimumNodeExtent) { Swift.max($0, Self.extent($1)) }
    }

    nonisolated static func verticalRowHeight(box: CGFloat, content: CGFloat, isLast: Bool) -> CGFloat {
        let box = Self.length(box)
        let content = Self.length(content)
        if isLast { return Swift.max(box, content) }
        return Swift.max(box + CoreSpacing.sm, content + CoreSpacing.lg)
    }

    nonisolated static func alternateRowMetrics(
        forRowWidth rowWidth: CGFloat, nodeColumnWidth: CGFloat
    ) -> AlternateRowMetrics {
        let fixed = Self.extent(nodeColumnWidth) + 2 * CoreSpacing.md
        guard rowWidth.isFinite else {
            return AlternateRowMetrics(slotWidth: 0, nodeCenterX: fixed / 2, rowWidth: fixed)
        }
        let slot = Swift.max(0, (rowWidth - fixed) / 2)
        let width = Swift.max(rowWidth, fixed)
        return AlternateRowMetrics(slotWidth: slot, nodeCenterX: width / 2, rowWidth: width)
    }

    nonisolated static func horizontalAxis(boxHeights: [CGFloat]) -> HorizontalAxis {
        let height = Self.nodeColumnWidth(boxWidths: boxHeights)
        return HorizontalAxis(axisY: height / 2, contentTop: height + CoreSpacing.sm)
    }

    nonisolated static func connectorSpan(from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard start.isFinite, end.isFinite else { return 0 }
        return Swift.max(0, end - start)
    }

    private nonisolated static func extent(_ value: CGFloat) -> CGFloat {
        value.isFinite ? Swift.max(Timeline.minimumNodeExtent, value) : Timeline.minimumNodeExtent
    }

    private nonisolated static func length(_ value: CGFloat) -> CGFloat {
        value.isFinite ? Swift.max(0, value) : 0
    }
}

// MARK: - TimelineMotion

nonisolated struct TimelineMotion: Equatable, Sendable {
    let position: Double
    let progress: TimelineProgress

    init?(progress: TimelineProgress?, steps: [Int?]) {
        let known = steps.compactMap { $0 }
        guard let progress, let lowest = known.min(), let highest = known.max() else { return nil }
        self.progress = progress
        switch progress {
        case .notStarted: self.position = Double(lowest) - 1
        case .inProgress(let current):
            self.position = Swift.min(Double(highest) + 1, Swift.max(Double(lowest) - 1, Double(current)))
        case .completed: self.position = Double(highest) + 1
        }
    }
}
