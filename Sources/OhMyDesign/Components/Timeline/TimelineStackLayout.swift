import SwiftUI

// MARK: - TimelineStackLayout

struct TimelineStackLayout: Layout {
    let layout: TimelineLayout

    nonisolated enum Part: Hashable, Sendable {
        case node(Int)
        case content(Int)
        case connector(Int)
    }

    nonisolated struct PartKey: LayoutValueKey {
        static let defaultValue: Part? = nil
    }

    nonisolated struct Row: Equatable, Sendable {
        let node: Int?
        let content: Int?
    }

    nonisolated struct Rows: Equatable, Sendable {
        var rows: [Row] = []
        var connectors: [Int: Int] = [:]
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        self.arrange(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = self.arrange(width: bounds.width, subviews: subviews)
        for placement in arrangement.placements {
            subviews[placement.index].place(
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

        mutating func place(_ index: Int?, _ point: CGPoint, _ anchor: UnitPoint, _ proposal: ProposedViewSize) {
            guard let index else { return }
            self.placements.append(Placement(index: index, point: point, anchor: anchor, proposal: proposal))
        }
    }

    private static let nodeProposal = ProposedViewSize(
        width: Timeline.minimumNodeExtent, height: Timeline.minimumNodeExtent
    )

    private func arrange(width: CGFloat?, subviews: Subviews) -> Arrangement {
        let rows = Self.pairRows(parts: subviews.map { $0[PartKey.self] })
        guard !rows.rows.isEmpty else { return Arrangement() }
        let boxes = rows.rows.map { row in
            Self.nodeBox(reported: row.node.map { subviews[$0].sizeThatFits(Self.nodeProposal) } ?? .zero)
        }
        switch self.layout {
        case .alternate:
            return Self.arrangeAlternate(width: width, rows: rows, boxes: boxes, subviews: subviews)
        case .horizontal:
            return Self.arrangeHorizontal(rows: rows, boxes: boxes, subviews: subviews)
        case .vertical, .grouped:
            return Self.arrangeVertical(width: width, rows: rows, boxes: boxes, subviews: subviews)
        }
    }

    private static func arrangeVertical(
        width: CGFloat?, rows: Rows, boxes: [CGSize], subviews: Subviews
    ) -> Arrangement {
        let column = Self.nodeColumnWidth(boxWidths: boxes.map(\.width))
        let contentX = column + CoreSpacing.md
        let finiteWidth = width.flatMap { $0.isFinite ? $0 : nil }
        let contentProposal = ProposedViewSize(width: finiteWidth.map { Swift.max(0, $0 - contentX) }, height: nil)
        let contentSizes = Self.contentSizes(rows: rows, subviews: subviews, proposal: contentProposal)
        let tops = Self.rowTops(boxes: boxes, contents: contentSizes)

        var arrangement = Arrangement()
        for (row, parts) in rows.rows.enumerated() {
            arrangement.place(parts.node, CGPoint(x: column / 2, y: tops[row] + boxes[row].height / 2), .center, Self.nodeProposal)
            arrangement.place(parts.content, CGPoint(x: contentX, y: tops[row]), .topLeading, contentProposal)
        }
        arrangement.placements += Self.verticalConnectors(
            rows: rows, boxes: boxes, tops: tops, axisX: column / 2
        )
        let contentWidth = contentSizes.map(\.width).max() ?? 0
        arrangement.size = CGSize(width: finiteWidth ?? contentX + contentWidth, height: tops.last ?? 0)
        return arrangement
    }

    private static func arrangeAlternate(
        width: CGFloat?, rows: Rows, boxes: [CGSize], subviews: Subviews
    ) -> Arrangement {
        let column = Self.nodeColumnWidth(boxWidths: boxes.map(\.width))
        let rowWidth: CGFloat
        if let width, width.isFinite {
            rowWidth = width
        } else {
            let ideal = Self.contentSizes(rows: rows, subviews: subviews, proposal: .unspecified).map(\.width).max() ?? 0
            rowWidth = ideal * 2 + column + 2 * CoreSpacing.md
        }
        let metrics = Self.alternateRowMetrics(forRowWidth: rowWidth, nodeColumnWidth: column)
        let slot = metrics.slotWidth
        let contentProposal = ProposedViewSize(width: slot, height: nil)
        let contentSizes = Self.contentSizes(rows: rows, subviews: subviews, proposal: contentProposal)
        let tops = Self.rowTops(boxes: boxes, contents: contentSizes)

        var arrangement = Arrangement()
        for (row, parts) in rows.rows.enumerated() {
            arrangement.place(
                parts.node, CGPoint(x: metrics.nodeCenterX, y: tops[row] + boxes[row].height / 2), .center, Self.nodeProposal
            )
            let contentX = row.isMultiple(of: 2)
                ? slot - contentSizes[row].width
                : slot + CoreSpacing.md + column + CoreSpacing.md
            arrangement.place(parts.content, CGPoint(x: contentX, y: tops[row]), .topLeading, contentProposal)
        }
        arrangement.placements += Self.verticalConnectors(
            rows: rows, boxes: boxes, tops: tops, axisX: metrics.nodeCenterX
        )
        arrangement.size = CGSize(width: metrics.rowWidth, height: tops.last ?? 0)
        return arrangement
    }

    private static func arrangeHorizontal(rows: Rows, boxes: [CGSize], subviews: Subviews) -> Arrangement {
        let axis = Self.horizontalAxis(boxHeights: boxes.map(\.height))
        let contentSizes = Self.contentSizes(rows: rows, subviews: subviews, proposal: .unspecified)
        let columnWidths = rows.rows.indices.map { Swift.max(boxes[$0].width, contentSizes[$0].width) }

        var arrangement = Arrangement()
        var columnX: [CGFloat] = []
        var x: CGFloat = 0
        for (row, parts) in rows.rows.enumerated() {
            columnX.append(x)
            let centerX = x + columnWidths[row] / 2
            arrangement.place(parts.node, CGPoint(x: centerX, y: axis.axisY), .center, Self.nodeProposal)
            arrangement.place(
                parts.content, CGPoint(x: centerX - contentSizes[row].width / 2, y: axis.contentTop), .topLeading, .unspecified
            )
            x += columnWidths[row] + CoreSpacing.lg
        }
        for row in rows.rows.indices.dropLast() {
            guard let connector = rows.connectors[row] else { continue }
            let start = columnX[row] + columnWidths[row] / 2 + boxes[row].width / 2
            let end = columnX[row + 1] + columnWidths[row + 1] / 2 - boxes[row + 1].width / 2
            arrangement.placements.append(Placement(
                index: connector, point: CGPoint(x: start, y: axis.axisY), anchor: .leading,
                proposal: ProposedViewSize(width: Self.connectorSpan(from: start, to: end), height: CoreBorderWidth.thin)
            ))
        }
        let contentHeight = contentSizes.map(\.height).max() ?? 0
        arrangement.size = CGSize(
            width: Swift.max(0, x - CoreSpacing.lg), height: axis.contentTop + contentHeight
        )
        return arrangement
    }

    private static func contentSizes(rows: Rows, subviews: Subviews, proposal: ProposedViewSize) -> [CGSize] {
        rows.rows.map { row in row.content.map { subviews[$0].sizeThatFits(proposal) } ?? .zero }
    }

    private static func rowTops(boxes: [CGSize], contents: [CGSize]) -> [CGFloat] {
        var tops: [CGFloat] = [0]
        for row in boxes.indices {
            let height = Self.verticalRowHeight(
                box: boxes[row].height, content: contents[row].height, isLast: row == boxes.count - 1
            )
            tops.append(tops[row] + height)
        }
        return tops
    }

    private static func verticalConnectors(
        rows: Rows, boxes: [CGSize], tops: [CGFloat], axisX: CGFloat
    ) -> [Placement] {
        rows.rows.indices.dropLast().compactMap { row in
            guard let connector = rows.connectors[row] else { return nil }
            let start = tops[row] + boxes[row].height
            return Placement(
                index: connector, point: CGPoint(x: axisX, y: start), anchor: .top,
                proposal: ProposedViewSize(
                    width: CoreBorderWidth.thin, height: Self.connectorSpan(from: start, to: tops[row + 1])
                )
            )
        }
    }
}

// MARK: - 纯函数 / Pure geometry

extension TimelineStackLayout {
    nonisolated static func pairRows(parts: [Part?]) -> Rows {
        var nodes: [Int: Int] = [:]
        var contents: [Int: Int] = [:]
        var result = Rows()
        for (index, part) in parts.enumerated() {
            switch part {
            case .node(let row): nodes[row] = nodes[row] ?? index
            case .content(let row): contents[row] = contents[row] ?? index
            case .connector(let segment): result.connectors[segment] = result.connectors[segment] ?? index
            case nil: break
            }
        }
        result.rows = Set(nodes.keys).union(contents.keys).sorted().map { row in
            Row(node: nodes[row], content: contents[row])
        }
        return result
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
