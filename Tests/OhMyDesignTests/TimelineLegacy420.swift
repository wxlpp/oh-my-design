import SwiftUI
@testable import OhMyDesign

// MARK: - Legacy420TimelineItem

struct Legacy420TimelineItem: Identifiable {
    let id: UUID
    let status: StatusLevel
    let node: AnyView?
    let content: AnyView

    init<Content: View>(
        id: UUID = UUID(),
        status: StatusLevel = .info,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.status = status
        self.node = nil
        self.content = AnyView(content())
    }

    init<Node: View, Content: View>(
        id: UUID = UUID(),
        status: StatusLevel = .info,
        @ViewBuilder node: () -> Node,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.status = status
        self.node = AnyView(node())
        self.content = AnyView(content())
    }
}

// MARK: - Legacy420Timeline

struct Legacy420Timeline: View {
    let items: [Legacy420TimelineItem]
    let layout: TimelineLayout

    init(items: [Legacy420TimelineItem], layout: TimelineLayout = .vertical) {
        self.items = items
        self.layout = layout
    }

    var body: some View {
        switch self.layout {
        case .vertical: self.verticalBody
        case .alternate: self.alternateBody
        case .horizontal: self.horizontalBody
        case .grouped: self.groupedBody
        }
    }

    private var verticalBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.none) {
            ForEach(self.items) { item in
                Legacy420TimelineRowView(item: item, isLast: Self.isLastItem(item, in: self.items))
            }
        }
    }

    private var alternateBody: some View {
        VStack(spacing: CoreSpacing.none) {
            ForEach(Array(self.items.enumerated()), id: \.element.id) { index, item in
                Legacy420TimelineAlternateRowView(
                    item: item,
                    isLast: Self.isLastItem(item, in: self.items),
                    contentSide: index.isMultiple(of: 2) ? .leading : .trailing
                )
            }
        }
    }

    struct AlternateRowMetrics: Equatable {
        let slotWidth: CGFloat
        let nodeCenterX: CGFloat
        let rowWidth: CGFloat
    }

    nonisolated static func alternateRowMetrics(forRowWidth rowWidth: CGFloat) -> AlternateRowMetrics {
        let fixed = 24 + 2 * CoreSpacing.md
        guard rowWidth.isFinite else {
            return AlternateRowMetrics(slotWidth: 0, nodeCenterX: fixed / 2, rowWidth: fixed)
        }
        let slot = Swift.max(0, (rowWidth - fixed) / 2)
        let width = Swift.max(rowWidth, fixed)
        return AlternateRowMetrics(slotWidth: slot, nodeCenterX: width / 2, rowWidth: width)
    }

    nonisolated static func alternateSlotWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        Self.alternateRowMetrics(forRowWidth: rowWidth).slotWidth
    }

    private var horizontalBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CoreSpacing.lg) {
                ForEach(self.items) { item in
                    VStack(alignment: .center, spacing: CoreSpacing.sm) {
                        Legacy420TimelineNodeView(item: item)
                        item.content
                    }
                }
            }
        }
    }

    private var groupedBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            ForEach(self.items) { item in
                Legacy420GroupedRow(item: item)
            }
        }
    }

    static func groupedStatusKey(for item: Legacy420TimelineItem) -> String? {
        item.node == nil ? Self.accessibilityLabelKey(for: item.status) : nil
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    @MainActor
    static func nodeColor(for status: StatusLevel, in colorScheme: ColorScheme) -> Color {
        switch status {
        case .info: .statusAccentEmphasis
        case .success: .statusSuccessEmphasis
        case .warning: colorScheme == .light ? .statusAttentionForeground : .statusAttentionEmphasis
        case .danger: .statusDangerEmphasis
        case .neutral: .contentSecondary
        }
    }

    static func accessibilityLabelKey(for status: StatusLevel) -> String {
        switch status {
        case .info: "Info"
        case .success: "Success"
        case .warning: "Warning"
        case .danger: "Error"
        case .neutral: "Neutral"
        }
    }

    static func isLastItem(_ item: Legacy420TimelineItem, in items: [Legacy420TimelineItem]) -> Bool {
        item.id == items.last?.id
    }
}

// MARK: - Legacy420TimelineNodeView

struct Legacy420TimelineNodeView: View {
    let item: Legacy420TimelineItem

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        self.nodeContent
            .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let node = self.item.node {
            node
        } else {
            Circle()
                .fill(Legacy420Timeline.nodeColor(for: self.item.status, in: self.colorScheme))
                .frame(width: 10, height: 10)
                .accessibilityLabel(
                    Text(LocalizedStringKey(Legacy420Timeline.accessibilityLabelKey(for: self.item.status)), bundle: .module)
                )
        }
    }
}

struct Legacy420TimelineRowView: View {
    let item: Legacy420TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.md) {
            Legacy420TimelineNodeView(item: self.item)

            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !self.isLast {
                Legacy420TimelineConnector()
                    .padding(.leading, (24 - CoreBorderWidth.thin) / 2)
            }
        }
    }
}

struct Legacy420TimelineAlternateRowView: View {
    let item: Legacy420TimelineItem
    let isLast: Bool
    let contentSide: HorizontalEdge

    var body: some View {
        Legacy420TimelineAlternateRowLayout {
            self.slot(.leading)
            Legacy420TimelineNodeView(item: self.item)
            self.slot(.trailing)
        }
        .background(alignment: .top) {
            if !self.isLast {
                Legacy420TimelineConnector()
            }
        }
    }

    @ViewBuilder
    private func slot(_ side: HorizontalEdge) -> some View {
        if side == self.contentSide {
            self.item.content
                .padding(.bottom, self.isLast ? CoreSpacing.none : CoreSpacing.lg)
                .frame(maxWidth: .infinity, alignment: side == .leading ? .trailing : .leading)
        } else {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
        }
    }
}

struct Legacy420TimelineAlternateRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = Self.metrics(for: proposal, subviews: subviews)
        let heights = Self.subviewHeights(subviews, slotWidth: metrics.slotWidth)
        return CGSize(width: metrics.rowWidth, height: heights.max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        guard subviews.count == 3 else { return }
        let metrics = Legacy420Timeline.alternateRowMetrics(forRowWidth: bounds.width)
        let slot = metrics.slotWidth
        let node: CGFloat = 24
        let gap = CoreSpacing.md

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
            proposal: ProposedViewSize(width: slot, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + metrics.nodeCenterX, y: bounds.minY), anchor: .top,
            proposal: ProposedViewSize(width: node, height: node)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + slot + gap + node + gap, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: slot, height: nil)
        )
    }

    private static func metrics(
        for proposal: ProposedViewSize, subviews: Subviews
    ) -> Legacy420Timeline.AlternateRowMetrics {
        if let width = proposal.width, width.isFinite {
            return Legacy420Timeline.alternateRowMetrics(forRowWidth: width)
        }
        guard subviews.count == 3 else { return Legacy420Timeline.alternateRowMetrics(forRowWidth: 0) }
        let idealSlot = Swift.max(
            subviews[0].sizeThatFits(.unspecified).width,
            subviews[2].sizeThatFits(.unspecified).width
        )
        let rowWidth = idealSlot * 2 + 24 + 2 * CoreSpacing.md
        return Legacy420Timeline.alternateRowMetrics(forRowWidth: rowWidth)
    }

    private static func subviewHeights(_ subviews: Subviews, slotWidth: CGFloat) -> [CGFloat] {
        guard subviews.count == 3 else { return [] }
        return [
            subviews[0].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
            24,
            subviews[2].sizeThatFits(ProposedViewSize(width: slotWidth, height: nil)).height,
        ]
    }
}

struct Legacy420GroupedRow: View {
    let item: Legacy420TimelineItem

    var body: some View {
        let base = self.item.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        if let key = Legacy420Timeline.groupedStatusKey(for: self.item) {
            base.accessibilityValue(Text(LocalizedStringKey(key), bundle: .module))
        } else {
            base
        }
    }
}

struct Legacy420TimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerDefault)
            .frame(width: CoreBorderWidth.thin)
            .frame(maxHeight: .infinity)
            .padding(.top, 24)
    }
}

