import Foundation
import Testing
@testable import OhMyDesignCharts

// MARK: - 布局形态扩展点（Issue #312 · 形态 D2）

@Suite("ActivityHeatmap 的布局形态（#312）")
struct ActivityHeatmapLayoutFormTests {
    private nonisolated struct Day: HeatmapDay {
        let id = UUID()
        let date: Date
        let count: Int
    }

    private func calendar(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    /// 从 `origin` 起第 `offset` 天（UTC 日历，正午避免 DST 边界问题）。
    private func day(_ offset: Int, from origin: Date, count: Int, _ cal: Calendar) -> Day {
        Day(date: cal.date(byAdding: .day, value: offset, to: origin)!, count: count)
    }

    private static let utcNoonOrigin: Date = {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour) = (2026, 1, 1, 12)
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    // MARK: - monthBlocks

    @Test("monthBlocks：每个有效日恰出现一次，每块恰 6×7，非 nil 格都属于该块月份")
    func monthBlocksCoverEveryEffectiveDayExactlyOnce() {
        let cal = self.calendar("UTC")
        // 2025-12-20 … 2026-01-10：跨年，跨两个日历月
        var startComps = DateComponents()
        (startComps.year, startComps.month, startComps.day, startComps.hour) = (2025, 12, 20, 12)
        let start = cal.date(from: startComps)!
        let days = (0...21).map { self.day($0, from: start, count: 1, cal) }
        let effective = ActivityHeatmap<Day>.effectiveDays(days, calendar: cal)
        let blocks = ActivityHeatmap<Day>.monthBlocks(ofEffective: effective, calendar: cal)

        for block in blocks {
            #expect(block.cells.count == 6, "块的行数是 \(block.cells.count)，期望 6")
            for row in block.cells { #expect(row.count == 7, "某行列数是 \(row.count)，期望 7") }
        }

        var seen = [Date: Int]()
        for block in blocks {
            for row in block.cells {
                for cell in row {
                    guard let date = cell else { continue }
                    seen[date, default: 0] += 1
                    let comps = cal.dateComponents([.year, .month], from: date)
                    #expect(comps.year == block.month.year && comps.month == block.month.month,
                            "非 nil 格 \(date) 不属于所在块的月份 \(String(describing: block.month))")
                }
            }
        }
        for effectiveDay in effective {
            let start = cal.startOfDay(for: effectiveDay.date)
            #expect(seen[start] == 1, "有效日 \(start) 出现了 \(seen[start] ?? 0) 次，期望恰 1 次")
        }
    }

    @Test("monthBlocks：块数 = 首尾跨越的月数（跨年样例）")
    func monthBlocksCountMatchesSpannedMonths() {
        let cal = self.calendar("UTC")
        // 2025-11-15 … 2026-02-10：跨 11、12、1、2 共 4 个日历月
        var startComps = DateComponents()
        (startComps.year, startComps.month, startComps.day, startComps.hour) = (2025, 11, 15, 12)
        var endComps = DateComponents()
        (endComps.year, endComps.month, endComps.day, endComps.hour) = (2026, 2, 10, 12)
        let start = cal.date(from: startComps)!
        let end = cal.date(from: endComps)!
        let dayCount = cal.dateComponents([.day], from: start, to: end).day!
        let days = (0...dayCount).map { self.day($0, from: start, count: 1, cal) }

        let blocks = ActivityHeatmap<Day>.monthBlocks(ofEffective: days, calendar: cal)
        #expect(blocks.count == 4, "块数是 \(blocks.count)，期望 4（11/12/1/2 月）")
        let months = Set(blocks.map { "\($0.month.year ?? -1)-\($0.month.month ?? -1)" })
        #expect(months == ["2025-11", "2025-12", "2026-1", "2026-2"],
                "块覆盖的月份是 \(months.sorted())")
    }

    @Test("monthBlocks：非 nil 格所在列 = 该日按 firstWeekday 归一化后的星期几")
    func monthBlocksColumnsMatchWeekday() {
        let cal = self.calendar("UTC")
        let days = (0...44).map { self.day($0, from: Self.utcNoonOrigin, count: 1, cal) }
        let blocks = ActivityHeatmap<Day>.monthBlocks(ofEffective: days, calendar: cal)
        #expect(!blocks.isEmpty)
        for block in blocks {
            for (row, cells) in block.cells.enumerated() {
                for (col, cell) in cells.enumerated() {
                    guard let date = cell else { continue }
                    let expectedCol = (cal.component(.weekday, from: date) - cal.firstWeekday + 7) % 7
                    #expect(col == expectedCol, "\(date) 落在第 \(col) 列，按星期几应为第 \(expectedCol) 列")
                    _ = row
                }
            }
        }
    }

    // MARK: - monthTracks

    @Test("monthTracks：行数 = 月数，每行 31 格")
    func monthTracksRowCountMatchesMonths() {
        let cal = self.calendar("UTC")
        var startComps = DateComponents()
        (startComps.year, startComps.month, startComps.day, startComps.hour) = (2025, 11, 15, 12)
        let start = cal.date(from: startComps)!
        let days = (0...86).map { self.day($0, from: start, count: 1, cal) } // 跨 11/12/1/2

        let tracks = ActivityHeatmap<Day>.monthTracks(ofEffective: days, calendar: cal)
        #expect(tracks.count == 4, "行数是 \(tracks.count)，期望 4")
        for row in tracks { #expect(row.count == 31, "某行列数是 \(row.count)，期望 31") }
    }

    @Test("monthTracks：非闰年 2 月第 29–31 列为 nil，闰年 2 月第 30–31 列为 nil，某月第 d 天落在列 d−1")
    func monthTracksHandlesShortMonths() {
        let cal = self.calendar("UTC")

        var nonLeap = DateComponents()
        (nonLeap.year, nonLeap.month, nonLeap.day, nonLeap.hour) = (2026, 2, 1, 12)
        var nonLeapEnd = DateComponents()
        (nonLeapEnd.year, nonLeapEnd.month, nonLeapEnd.day, nonLeapEnd.hour) = (2026, 2, 28, 12)
        let nonLeapStart = cal.date(from: nonLeap)!
        let nonLeapDays = (0...27).map { self.day($0, from: nonLeapStart, count: 1, cal) }
        let nonLeapTrack = ActivityHeatmap<Day>.monthTracks(ofEffective: nonLeapDays, calendar: cal)[0]
        #expect(nonLeapTrack[27] != nil, "2026 年 2 月第 28 天应存在（非闰年恰 28 天）")
        for index in 28..<31 { #expect(nonLeapTrack[index] == nil, "非闰年 2 月第 \(index + 1) 列应为 nil") }

        var leap = DateComponents()
        (leap.year, leap.month, leap.day, leap.hour) = (2024, 2, 1, 12)
        let leapStart = cal.date(from: leap)!
        let leapDays = (0...28).map { self.day($0, from: leapStart, count: 1, cal) }
        let leapTrack = ActivityHeatmap<Day>.monthTracks(ofEffective: leapDays, calendar: cal)[0]
        #expect(leapTrack[28] != nil, "2024 年 2 月第 29 天应存在（闰年）")
        for index in 29..<31 { #expect(leapTrack[index] == nil, "闰年 2 月第 \(index + 1) 列应为 nil") }

        // 某月第 d 天落在列 d−1（用非闰年那批数据核对第 10 天）
        let comps10 = cal.dateComponents([.day], from: nonLeapTrack[9]!)
        #expect(comps10.day == 10, "第 10 列应放该月第 10 天，实为第 \(comps10.day ?? -1) 天")
    }

    // MARK: - monthBlocks / monthTracks 覆盖首末整月（评审 I-1）

    /// `first` 不是月初 1 日（2026-01-20）、`last` 不是月末最后一日（2026-02-05）：
    /// 首月 1 日…`first` 前一日、`last` 后一日…末月最后一日这些格应为非 `nil` 的 `Date`
    /// （落在该月、取色走 `byDate`，缺数据 ⇒ `tertiaryFill`），且不属于有效日集合；
    /// 有效日仍应恰出现一次。此前游标从 `first` 起，这些格被误留 `nil` ⇒ `Color.clear`，
    /// 与 `.weeks`「画空槽而不是跳过」的约定矛盾（`docs/components/activity-heatmap.md`
    /// 《AD-F 退化输入契约》）。
    private func fullMonthCoverageIsNonNilAndExcludesEffectiveDays(calendar cal: Calendar) {
        var startComps = DateComponents()
        (startComps.year, startComps.month, startComps.day, startComps.hour) = (2026, 1, 20, 12)
        var endComps = DateComponents()
        (endComps.year, endComps.month, endComps.day, endComps.hour) = (2026, 2, 5, 12)
        let start = cal.date(from: startComps)!
        let end = cal.date(from: endComps)!
        let dayCount = cal.dateComponents([.day], from: start, to: end).day!
        let days = (0...dayCount).map { self.day($0, from: start, count: 1, cal) }
        let effectiveDates = Set(days.map { cal.startOfDay(for: $0.date) })

        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var c = DateComponents()
            (c.year, c.month, c.day, c.hour) = (y, m, d, 12)
            return cal.startOfDay(for: cal.date(from: c)!)
        }
        // 首月 1…19 日（20 日起才是有效日）+ 末月 6…28 日（5 日止是有效日）。
        let expectedExtras: [Date] = (1...19).map { date(2026, 1, $0) } + (6...28).map { date(2026, 2, $0) }
        for extra in expectedExtras {
            #expect(!effectiveDates.contains(extra), "测试夹具有误：\(extra) 不应落在有效日区间 2026-01-20…02-05 内")
        }

        let blocks = ActivityHeatmap<Day>.monthBlocks(ofEffective: days, calendar: cal)
        var blockCounts = [Date: Int]()
        for block in blocks {
            for row in block.cells {
                for cell in row {
                    guard let c = cell else { continue }
                    blockCounts[cal.startOfDay(for: c), default: 0] += 1
                }
            }
        }
        for extra in expectedExtras {
            #expect(blockCounts[extra] == 1,
                    "monthBlocks 里月内非有效日 \(extra) 应恰出现一次非 nil 格，实为 \(blockCounts[extra] ?? 0)")
        }
        for effectiveDay in effectiveDates {
            #expect(blockCounts[effectiveDay] == 1,
                    "monthBlocks 里有效日 \(effectiveDay) 应恰出现一次，实为 \(blockCounts[effectiveDay] ?? 0)")
        }

        let tracks = ActivityHeatmap<Day>.monthTracks(ofEffective: days, calendar: cal)
        var trackCounts = [Date: Int]()
        for track in tracks {
            for cell in track {
                guard let c = cell else { continue }
                trackCounts[cal.startOfDay(for: c), default: 0] += 1
            }
        }
        for extra in expectedExtras {
            #expect(trackCounts[extra] == 1,
                    "monthTracks 里月内非有效日 \(extra) 应恰出现一次非 nil 格，实为 \(trackCounts[extra] ?? 0)")
        }
        for effectiveDay in effectiveDates {
            #expect(trackCounts[effectiveDay] == 1,
                    "monthTracks 里有效日 \(effectiveDay) 应恰出现一次，实为 \(trackCounts[effectiveDay] ?? 0)")
        }
    }

    @Test("monthBlocks / monthTracks：覆盖首末整月，月内非有效日非 nil（UTC）")
    func monthBlocksAndTracksCoverFullMonthsUTC() {
        self.fullMonthCoverageIsNonNilAndExcludesEffectiveDays(calendar: self.calendar("UTC"))
    }

    @Test("monthBlocks / monthTracks：覆盖首末整月，月内非有效日非 nil（America/Santiago）")
    func monthBlocksAndTracksCoverFullMonthsSantiago() {
        self.fullMonthCoverageIsNonNilAndExcludesEffectiveDays(calendar: self.calendar("America/Santiago"))
    }

    // MARK: - dailySeries

    @Test("dailySeries：跨 DST（America/Santiago）不丢不重，长度 = 首尾天数 + 1")
    func dailySeriesDoesNotDropOrDuplicateAcrossDST() {
        let cal = self.calendar("America/Santiago")
        var comps = DateComponents()
        (comps.year, comps.month, comps.day, comps.hour) = (2026, 9, 1, 12)
        let start = cal.date(from: comps)!
        let days = (0...13).map { self.day($0, from: start, count: 1, cal) } // 2026-09-01…09-14
        let series = ActivityHeatmap<Day>.dailySeries(ofEffective: days, calendar: cal)

        // ⚠️ **不用 `calendar.dateComponents([.day], from:to:)` 判「相邻相差一天」**：
        // 实测在 2026-09-06 那次春季跳时上，Sept 6 → Sept 7 的 `startOfDay` 之间只隔 23
        // 小时，`dateComponents([.day], …)` 按**流逝时间**算出 `day == 0`（Foundation 行为，
        // 不是本函数的 bug）——用「不重复 + 严格递增 + 总数不丢」代替逐日相减更可靠。
        #expect(series.count == 14, "序列长度是 \(series.count)，期望 14")
        #expect(Set(series).count == 14, "序列里有重复的日期：\(series)")
        for i in 1..<series.count {
            #expect(series[i] > series[i - 1], "序列在索引 \(i) 处没有严格递增：\(series[i - 1]) → \(series[i])")
        }
    }

    @Test("dailySeries：UTC 对照组同样不丢不重（证明上面那条测的是 DST 不是别的）")
    func dailySeriesUTCControlGroup() {
        let cal = self.calendar("UTC")
        var comps = DateComponents()
        (comps.year, comps.month, comps.day, comps.hour) = (2026, 9, 1, 12)
        let start = cal.date(from: comps)!
        let days = (0...13).map { self.day($0, from: start, count: 1, cal) }

        let series = ActivityHeatmap<Day>.dailySeries(ofEffective: days, calendar: cal)
        #expect(series.count == 14)
        #expect(Set(series).count == 14)
        for i in 1..<series.count {
            #expect(cal.dateComponents([.day], from: series[i - 1], to: series[i]).day == 1)
        }
    }

    // MARK: - view 实际走的那条路（renderInputs(_:calendar:layout:)）

    @Test("#312：renderInputs 在四个 layout 下 shown 相同（截断与去重与形态无关）、plan 互异")
    func renderInputsSharesShownAcrossLayoutsButShapesDiffer() {
        let cal = self.calendar("UTC")
        // 含重复日期，走 effectiveDays 的去重路径
        let days = (0...59).map { self.day($0, from: Self.utcNoonOrigin, count: $0 % 5 + 1, cal) }
            + [self.day(0, from: Self.utcNoonOrigin, count: 99, cal)] // 重复第一天

        var shownSets: [Set<Date>] = []
        for layout in ActivityHeatmapLayout.allCases {
            let plan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal, layout: layout)
            shownSets.append(Set(plan.shown.map { cal.startOfDay(for: $0.date) }))
        }
        for other in shownSets.dropFirst() {
            #expect(other == shownSets[0], "不同 layout 下 shown 的日期集合不同：\(shownSets[0]) vs \(other)")
        }

        let weeksPlan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal, layout: .weeks)
        let monthCalendarPlan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal, layout: .monthCalendar)
        let monthTracksPlan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal, layout: .monthTracks)
        let dailyColumnsPlan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal, layout: .dailyColumns)

        guard case .weeks(let weeks) = weeksPlan.shape else { Issue.record("weeksPlan.shape 不是 .weeks"); return }
        guard case .monthCalendar(let blocks) = monthCalendarPlan.shape
        else { Issue.record("monthCalendarPlan.shape 不是 .monthCalendar"); return }
        guard case .monthTracks(let tracks) = monthTracksPlan.shape
        else { Issue.record("monthTracksPlan.shape 不是 .monthTracks"); return }
        guard case .dailyColumns(let series) = dailyColumnsPlan.shape
        else { Issue.record("dailyColumnsPlan.shape 不是 .dailyColumns"); return }

        #expect(!weeks.isEmpty && !blocks.isEmpty && !tracks.isEmpty && !series.isEmpty,
                "非空输入下四个 layout 的几何都应非空")
        #expect(weeksPlan.buckets == monthCalendarPlan.buckets, "buckets 与形态无关，应恒相同")
        #expect(weeksPlan.buckets == dailyColumnsPlan.buckets)
    }

    @Test("#312：空数组时四个 layout 都给出零列 / 零块 / 零柱")
    func renderInputsIsEmptyForEveryLayoutOnEmptyInput() {
        let cal = self.calendar("UTC")
        for layout in ActivityHeatmapLayout.allCases {
            let plan = ActivityHeatmap<Day>.renderInputs([Day](), calendar: cal, layout: layout)
            #expect(plan.shown.isEmpty)
            #expect(plan.buckets.isEmpty)
            switch plan.shape {
            case .weeks(let weeks):
                #expect(weeks.isEmpty, "\(layout)：空输入下 weeks 非空")
            case .monthCalendar(let blocks):
                #expect(blocks.isEmpty, "\(layout)：空输入下 monthCalendar 块非空")
            case .monthTracks(let tracks):
                #expect(tracks.isEmpty, "\(layout)：空输入下 monthTracks 行非空")
            case .dailyColumns(let series):
                #expect(series.isEmpty, "\(layout)：空输入下 dailyColumns 序列非空")
            }
        }
    }

    @Test("#312：renderInputs 的 buckets 与既有 buckets(for:) 同源，默认 layout 仍是 .weeks")
    func renderInputsBucketsMatchExistingBucketsFunction() {
        let cal = self.calendar("UTC")
        let days = (0...9).map { self.day($0, from: Self.utcNoonOrigin, count: $0, cal) }
        let effective = ActivityHeatmap<Day>.effectiveDays(days, calendar: cal)
        let expectedBuckets = ActivityHeatmap<Day>.buckets(for: effective)

        // 不传 layout：默认应为 .weeks（保 DegenerateInputTests 既有调用点不变）
        let defaultPlan = ActivityHeatmap<Day>.renderInputs(days, calendar: cal)
        #expect(defaultPlan.buckets == expectedBuckets)
        guard case .weeks = defaultPlan.shape else {
            Issue.record("不传 layout 时默认形态不是 .weeks")
            return
        }
    }
}
