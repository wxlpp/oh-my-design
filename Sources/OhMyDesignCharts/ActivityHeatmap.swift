import Accessibility
import OhMyDesign
import SwiftUI

/// 贡献热力图（GitHub 那种按周排列的日格）。
public struct ActivityHeatmap<Day: HeatmapDay>: View {
    private let days: [Day]
    private let tint: Color
    private let title: LocalizedStringResource
    private let calendar: Calendar
    private let layout: ActivityHeatmapLayout

    /// - Parameter calendar: ⚠️ 显式接受而不是取 `.current`——一周从周日还是周一开始
    ///   **是 locale 决定的**，写死会让非美国用户看到错位的行。默认取 `.current`
    ///   是为了默认正确，但可注入才可测。
    public init(
        _ days: [Day],
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        calendar: Calendar = .current,
        layout: ActivityHeatmapLayout = .weeks
    ) {
        self.days = days
        self.title = title ?? .chart("Activity heatmap")
        self.tint = tint
        self.calendar = calendar
        self.layout = layout
    }

    public var body: some View {
        if self.days.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else {
            self.content
        }
    }

    // MARK: - Private

    private var content: some View {
        let plan = Self.renderInputs(self.days, calendar: self.calendar, layout: self.layout)
        return Group {
            switch plan.shape {
            case .weeks(let weeks):
                self.weeksGrid(weeks: weeks, buckets: plan.buckets)
            case .monthCalendar(let blocks):
                self.monthCalendarGrid(blocks: blocks, buckets: plan.buckets, byDate: plan.byDate)
            case .monthTracks(let tracks):
                self.monthTracksGrid(tracks: tracks, buckets: plan.buckets, byDate: plan.byDate)
            case .dailyColumns(let dates):
                self.dailyColumnsBars(dates: dates, buckets: plan.buckets, byDate: plan.byDate)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    private func weeksGrid(weeks: [[Day?]], buckets: [Int]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = week[weekday]
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(self.color(for: day, buckets: buckets))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func monthCalendarGrid(blocks: [MonthBlock], buckets: [Int], byDate: [Date: Day]) -> some View {
        // 用 `GeometryReader` 显式算出正方形边长，而不是靠 `.aspectRatio(1, .fit)` 在
        // 多块 × 6 行 × 7 列的嵌套 HStack/VStack 里隐式协商——与 `dailyColumnsBars` 同一套做法，
        // 边长同时受块宽（多块分摊总宽）与行高两个方向约束，取较小者更直接。
        // `blockGap` 用 `CoreSpacing.lg`（不是 `.sm`）——块间距要读得出月边界。
        let gap: CGFloat = 3
        let blockGap = CoreSpacing.lg
        return GeometryReader { proxy in
            let blockCount = max(blocks.count, 1)
            let totalBlockGaps = blockGap * CGFloat(max(blocks.count - 1, 0))
            let blockWidth = max((proxy.size.width - totalBlockGaps) / CGFloat(blockCount), 0)
            let cellWidth = max((blockWidth - gap * 6) / 7, 0)
            let cellHeight = max((proxy.size.height - gap * 5) / 6, 0)
            let cellSize = min(cellWidth, cellHeight)
            HStack(spacing: blockGap) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    VStack(spacing: gap) {
                        ForEach(0..<6, id: \.self) { row in
                            HStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { column in
                                    self.calendarCell(date: block.cells[row][column], buckets: buckets, byDate: byDate)
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
            }
            // 内容按实际尺寸收缩后由 `GeometryReader` 顶左锚定摆放——补 `.frame(max…, alignment: .center)`
            // 让它像 `.weeks` 一样居中，不留大块死区。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func monthTracksGrid(tracks: [[Date?]], buckets: [Int], byDate: [Date: Day]) -> some View {
        let gap: CGFloat = 3
        return GeometryReader { proxy in
            let rowCount = max(tracks.count, 1)
            let cellWidth = max((proxy.size.width - gap * 30) / 31, 0)
            let cellHeight = max((proxy.size.height - gap * CGFloat(max(tracks.count - 1, 0))) / CGFloat(rowCount), 0)
            let cellSize = min(cellWidth, cellHeight)
            VStack(spacing: gap) {
                ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                    HStack(spacing: gap) {
                        ForEach(Array(track.enumerated()), id: \.offset) { _, date in
                            self.calendarCell(date: date, buckets: buckets, byDate: byDate)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            // 同 `monthCalendarGrid`：补居中，理由同上。
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func calendarCell(date: Date?, buckets: [Int], byDate: [Date: Day]) -> some View {
        let fill: Color = date.map { self.color(for: byDate[$0], buckets: buckets) } ?? Color.clear
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(fill)
    }

    private func dailyColumnsBars(dates: [Date], buckets: [Int], byDate: [Date: Day]) -> some View {
        let peak = dates.compactMap { byDate[$0]?.count }.max() ?? 0
        return VStack(spacing: 3) {
            GeometryReader { proxy in
                let gap: CGFloat = 1
                let barWidth = dates.isEmpty
                    ? 0
                    : max((proxy.size.width - gap * CGFloat(max(dates.count - 1, 0))) / CGFloat(dates.count), 0)
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(dates, id: \.self) { date in
                        let day = byDate[date]
                        let height = peak > 0 ? proxy.size.height * CGFloat(day?.count ?? 0) / CGFloat(peak) : 0
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(day != nil ? self.color(for: day, buckets: buckets) : Color.clear)
                            .frame(width: barWidth, height: max(height, 0))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            Rectangle()
                .fill(Color.dividerDefault)
                .frame(height: CoreBorderWidth.hairline)
        }
    }

    static func renderInputs(_ days: [Day], calendar: Calendar, layout: ActivityHeatmapLayout = .weeks)
        -> HeatmapPlan {
        let shown = Self.effectiveDays(days, calendar: calendar)
        let buckets = Self.buckets(for: shown)
        var byDate = [Date: Day]()
        for d in shown { byDate[calendar.startOfDay(for: d.date)] = d }

        let shape: HeatmapShape
        switch layout {
        case .weeks:
            shape = .weeks(Self.weeks(ofEffective: shown, calendar: calendar))
        case .monthCalendar:
            shape = .monthCalendar(Self.monthBlocks(ofEffective: shown, calendar: calendar))
        case .monthTracks:
            shape = .monthTracks(Self.monthTracks(ofEffective: shown, calendar: calendar))
        case .dailyColumns:
            shape = .dailyColumns(Self.dailySeries(ofEffective: shown, calendar: calendar))
        }
        return HeatmapPlan(shown: shown, buckets: buckets, shape: shape, byDate: byDate)
    }

    static func label(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return date.formatted(style)
    }

    static func effectiveDays(_ days: [Day], calendar: Calendar) -> [Day] {
        let sorted = days.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return [] }
        var seen = Set<Date>()
        let deduped = sorted.reversed()
            .filter { seen.insert(calendar.startOfDay(for: $0.date)).inserted }
            .reversed()
        let end = calendar.startOfDay(for: last.date)
        guard let floorDate = calendar.date(byAdding: .day, value: -(Self.maximumDays - 1), to: end)
        else { return Array(deduped) }
        return deduped.filter { calendar.startOfDay(for: $0.date) >= floorDate }
    }

    static func weeks(for days: [Day], calendar: Calendar) -> [[Day?]] {
        Self.weeks(ofEffective: Self.effectiveDays(days, calendar: calendar), calendar: calendar)
    }

    static func weeks(ofEffective sorted: [Day], calendar: Calendar) -> [[Day?]] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [[Day?]] = []
        var column = [Day?](repeating: nil, count: 7)
        let end = calendar.startOfDay(for: last.date)
        var cursor = calendar.startOfDay(for: first.date)
        var byDate = [Date: Day]()
        for d in sorted { byDate[calendar.startOfDay(for: d.date)] = d }

        var guardCounter = 0
        while cursor <= end {
            guardCounter += 1
            if guardCounter > Self.maximumDays + 14 { break }

            let weekday = (calendar.component(.weekday, from: cursor)
                           - calendar.firstWeekday + 7) % 7
            column[weekday] = byDate[cursor]
            if weekday == 6 {
                result.append(column)
                column = [Day?](repeating: nil, count: 7)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        if column.contains(where: { $0 != nil }) { result.append(column) }
        return result
    }

    /// 单张热力图渲染的天数上限（≈ 5 年）；超出即静默截断最旧的一段，不提示调用方。
    public nonisolated static var maximumDays: Int { 1830 }

    static func buckets(for days: [Day]) -> [Int] {
        let peak = days.map(\.count).max() ?? 0
        guard peak > 0 else { return [] }
        return (1...4).map { peak / 4 * $0 + (peak % 4) * $0 / 4 }
    }

    private func color(for day: Day?, buckets: [Int]) -> Color {
        guard let day, day.count > 0, !buckets.isEmpty else {
            return Color.tertiaryFill
        }
        let level = buckets.firstIndex { day.count <= $0 } ?? buckets.count - 1
        return self.tint.opacity(0.25 + Double(level) * 0.25)
    }
}

extension ActivityHeatmap: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let shown = Self.effectiveDays(self.days, calendar: self.calendar)
        let peak = Double(shown.map(\.count).max() ?? 1)
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Count"), range: safeRange(0, peak), gridlinePositions: []
        ) { $0.formatted(.number.precision(.fractionLength(0))) }
        let dates = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Date"),
            categoryOrder: shown.map { Self.label(for: $0.date, calendar: self.calendar) }
        )
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: shown.map {
                AXDataPoint(
                    x: Self.label(for: $0.date, calendar: self.calendar),
                    y: Double($0.count)
                )
            }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: dates, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

#Preview("ActivityHeatmap") {
    nonisolated struct Day: HeatmapDay {
        let id = UUID()
        let date: Date
        let count: Int
    }
    let start = Calendar.current.date(byAdding: .day, value: -120, to: .now)!
    let days = (0..<120).map { offset in
        Day(
            date: Calendar.current.date(byAdding: .day, value: offset, to: start)!,
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    }
    return VStack(spacing: 24) {
        ActivityHeatmap(days).frame(height: 110)
        ActivityHeatmap(days.map { Day(date: $0.date, count: 0) }).frame(height: 110)
    }
    .padding()
}

// MARK: - 四个布局形态各一个 Preview（Issue #312）

private nonisolated struct ActivityHeatmapPreviewDay: HeatmapDay {
    let id = UUID()
    let date: Date
    let count: Int
}

private nonisolated enum ActivityHeatmapPreviewSample {
    static let days: [ActivityHeatmapPreviewDay] = {
        let start = Calendar.current.date(byAdding: .day, value: -120, to: .now)!
        return (0..<120).map { offset in
            ActivityHeatmapPreviewDay(
                date: Calendar.current.date(byAdding: .day, value: offset, to: start)!,
                count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
            )
        }
    }()
}

#Preview("ActivityHeatmap — .weeks") {
    ActivityHeatmap(ActivityHeatmapPreviewSample.days, title: ".weeks", layout: .weeks)
        .frame(height: 110)
        .padding()
}

#Preview("ActivityHeatmap — .monthCalendar") {
    ActivityHeatmap(ActivityHeatmapPreviewSample.days, title: ".monthCalendar", layout: .monthCalendar)
        .frame(height: 220)
        .padding()
}

#Preview("ActivityHeatmap — .monthTracks") {
    ActivityHeatmap(ActivityHeatmapPreviewSample.days, title: ".monthTracks", layout: .monthTracks)
        .frame(height: 160)
        .padding()
}

#Preview("ActivityHeatmap — .dailyColumns") {
    ActivityHeatmap(ActivityHeatmapPreviewSample.days, title: ".dailyColumns", layout: .dailyColumns)
        .frame(height: 110)
        .padding()
}

// MARK: - 布局形态（Issue #312 · 形态 D2）

/// `ActivityHeatmap` 的布局形态。
///
/// ⚠️ **本枚举是 `#312` 给 `ActivityHeatmap` 补的样式扩展点**（形态 D2 配置枚举）——
/// `#299` 步骤 2 枚举出的三个业界替代形态各对应一个 case，来源逐条记在各 case 的文档注释里。
///
/// ⚠️ **「配置枚举可演进」不是零代价**：本枚举**非 `@frozen`**，加 case 对下游任何
/// 穷举 `switch` 都是 source-breaking（下游要写 `@unknown default` 才免疫）。
/// 它仍比形态 B（public 协议）可撤，但加 case 要走一次 BREAKING-CHANGES 登记。
public nonisolated enum ActivityHeatmapLayout: Sendable, Equatable, CaseIterable {
    /// 默认：按周成列、按星期几成行（现状形态）。
    case weeks
    /// 日历月视图：每月一块、固定 6 行 × 7 列，格子按真实的日历位置摆放。
    /// 业界来源：Apple 自家 Activity / Fitness App 的 History 页。
    case monthCalendar
    /// 月轨图：每月一行，按当月日序成列。
    /// 业界来源：Obsidian 社区插件 Contribution Graph 的 "month track graphs"。
    case monthTracks
    /// 每日一柱：折线 / 柱状时间序列的柱状读法，保留四档强度色阶双重编码。
    /// 业界来源：GitLab Pajamas 的图表页（column / bar / line / sparkline 并列为可选形态）。
    ///
    /// ⚠️ **只做柱状，不做折线**：两者同槽同排布（网格 → 线性），差别属装饰档，
    /// 本轮不另开 case（详见 `docs/components/activity-heatmap.md`《布局形态扩展点》一节）。
    case dailyColumns
}

extension ActivityHeatmap {
    /// 一个日历月块：固定 6 行 × 7 列，格子按真实的日历位置摆放，月外的格为 `nil`。
    struct MonthBlock: Equatable, Sendable {
        let month: DateComponents
        let cells: [[Date?]]
    }

    /// 按当前 `layout` 选出的几何数据——四个形态各自的 case 互斥，不会一起算。
    enum HeatmapShape {
        case weeks([[Day?]])
        case monthCalendar([MonthBlock])
        case monthTracks([[Date?]])
        case dailyColumns([Date])
    }

    /// `renderInputs(_:calendar:layout:)` 的统一产出，`body` 只消费它——这就是 view 路径。
    struct HeatmapPlan {
        let shown: [Day]
        let buckets: [Int]
        let shape: HeatmapShape
        let byDate: [Date: Day]
    }

    /// `first…last` 所跨月份的整月边界：首月 1 日 … 末月最后一日（月内区间外的日子画空槽，与 `.weeks` 同约定）。
    private static func monthSpanBounds(first: Date, last: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let firstComps = calendar.dateComponents([.year, .month], from: first)
        let firstOfFirstMonth = calendar.date(
            from: DateComponents(year: firstComps.year, month: firstComps.month, day: 1)
        ) ?? first

        let lastComps = calendar.dateComponents([.year, .month], from: last)
        let daysInLastMonth = calendar.range(of: .day, in: .month, for: last)?.count ?? 28
        let lastOfLastMonth = calendar.date(
            from: DateComponents(year: lastComps.year, month: lastComps.month, day: daysInLastMonth)
        ) ?? last

        return (calendar.startOfDay(for: firstOfFirstMonth), calendar.startOfDay(for: lastOfLastMonth))
    }

    /// 日历月视图：`first…last` 跨越的每个日历月各一块，固定 6 行 × 7 列，月外的格 `nil`。
    ///
    /// ⚠️ **与 `weeks(ofEffective:calendar:)` 同法**：逐日推进（`calendar.startOfDay` +
    /// `date(byAdding: .day, value: 1)`），DST 安全——不按「月」步进，理由与 `weeks` 一致：
    /// 月份长度、跨年边界都交给日历本身，不在这里重算。游标覆盖整月，见 `monthSpanBounds`。
    static func monthBlocks(ofEffective sorted: [Day], calendar: Calendar) -> [MonthBlock] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [MonthBlock] = []
        var cells = [[Date?]](repeating: [Date?](repeating: nil, count: 7), count: 6)
        var currentMonth: DateComponents?
        var firstWeekdayColumn = 0

        func flush() {
            guard let month = currentMonth else { return }
            result.append(MonthBlock(month: month, cells: cells))
            cells = [[Date?]](repeating: [Date?](repeating: nil, count: 7), count: 6)
        }

        let (start, end) = Self.monthSpanBounds(first: first.date, last: last.date, calendar: calendar)
        var cursor = start
        var guardCounter = 0
        while cursor <= end {
            guardCounter += 1
            // 首末两月的区间外部分各 ≤ 30 天。
            if guardCounter > Self.maximumDays + 14 + 62 { break }

            let comps = calendar.dateComponents([.year, .month], from: cursor)
            if currentMonth == nil || currentMonth?.year != comps.year || currentMonth?.month != comps.month {
                flush()
                currentMonth = comps
                let firstOfMonth = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))
                    ?? cursor
                firstWeekdayColumn = (calendar.component(.weekday, from: firstOfMonth)
                                       - calendar.firstWeekday + 7) % 7
            }

            let dayNumber = calendar.component(.day, from: cursor)
            let index = firstWeekdayColumn + dayNumber - 1
            let row = index / 7
            let column = index % 7
            if row < 6 { cells[row][column] = cursor }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        flush()
        return result
    }

    /// 月轨图：`first…last` 跨越的每个日历月各一行、31 列，第 d 天在列 d−1，
    /// 超出该月天数的列 `nil`。逐日推进方式、DST 安全性同 `monthBlocks`；
    /// 游标同样覆盖整月，见 `monthSpanBounds`。
    static func monthTracks(ofEffective sorted: [Day], calendar: Calendar) -> [[Date?]] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [[Date?]] = []
        var row = [Date?](repeating: nil, count: 31)
        var currentMonth: DateComponents?

        func flush() {
            guard currentMonth != nil else { return }
            result.append(row)
            row = [Date?](repeating: nil, count: 31)
        }

        let (start, end) = Self.monthSpanBounds(first: first.date, last: last.date, calendar: calendar)
        var cursor = start
        var guardCounter = 0
        while cursor <= end {
            guardCounter += 1
            // 首末两月的区间外部分各 ≤ 30 天。
            if guardCounter > Self.maximumDays + 14 + 62 { break }

            let comps = calendar.dateComponents([.year, .month], from: cursor)
            if currentMonth == nil || currentMonth?.year != comps.year || currentMonth?.month != comps.month {
                flush()
                currentMonth = comps
            }

            let dayNumber = calendar.component(.day, from: cursor)
            if dayNumber >= 1 && dayNumber <= 31 { row[dayNumber - 1] = cursor }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        flush()
        return result
    }

    /// `first…last` 逐日稠密序列（含无数据的间隙日）。逐日推进方式、DST 安全性与守卫同 `weeks`。
    static func dailySeries(ofEffective sorted: [Day], calendar: Calendar) -> [Date] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var result: [Date] = []
        let end = calendar.startOfDay(for: last.date)
        var cursor = calendar.startOfDay(for: first.date)
        var guardCounter = 0
        while cursor <= end {
            guardCounter += 1
            if guardCounter > Self.maximumDays + 14 { break }
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        return result
    }
}
