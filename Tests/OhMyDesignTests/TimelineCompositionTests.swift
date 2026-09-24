import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 组合式 API / Composition（#420 PR 2）

@Suite("Timeline 组合式 API")
@MainActor
struct TimelineCompositionTests {
    // MARK: - 状态值挂载点（纯函数，双腿）

    @Test("挂载点：默认圆点无标题 ⇒ 合并内容元素 + 状态值；有标题 ⇒ 标题元素，内容不合并")
    func defaultNodeRowsMountStatus() {
        for status in [StatusLevel.info, .success, .warning, .danger, .neutral] {
            let key = Timeline.accessibilityLabelKey(for: status)
            #expect(Timeline.accessibility(status: status, hasCustomNode: false, hasTitle: false, phase: nil)
                    == TimelineRowAccessibility(valueKeys: [key], mount: .content, combinesContent: true))
            #expect(Timeline.accessibility(status: status, hasCustomNode: false, hasTitle: true, phase: nil)
                    == TimelineRowAccessibility(valueKeys: [key], mount: .title, combinesContent: false))
        }
        #expect(Timeline.accessibility(status: nil, hasCustomNode: false, hasTitle: false, phase: nil).valueKeys == ["Info"],
                "默认圆点行恒带状态键")
    }

    @Test("挂载点：自定义节点不传 status ⇒ 无状态键、不改写内容；传了 ⇒ 与默认圆点同一挂载规则")
    func customNodeRowsMountOnlyPassedStatus() {
        for hasTitle in [false, true] {
            #expect(Timeline.accessibility(status: nil, hasCustomNode: true, hasTitle: hasTitle, phase: nil)
                    == TimelineRowAccessibility(valueKeys: [], mount: .none, combinesContent: false))
        }
        #expect(Timeline.accessibility(status: .danger, hasCustomNode: true, hasTitle: false, phase: nil)
                == TimelineRowAccessibility(valueKeys: ["Error"], mount: .content, combinesContent: true))
        #expect(Timeline.accessibility(status: .success, hasCustomNode: true, hasTitle: true, phase: nil)
                == TimelineRowAccessibility(valueKeys: ["Success"], mount: .title, combinesContent: false))
    }

    @Test("挂载点：值文本按 bundle 取、以「, 」连接；无键时为 nil")
    func valueTextJoinsKeys() {
        #expect(TimelineRowAccessibility(valueKeys: [], mount: .none, combinesContent: false).valueText == nil)
        #expect(TimelineRowAccessibility(valueKeys: ["Error"], mount: .title, combinesContent: false).valueText == "Error")
        #expect(TimelineRowAccessibility(valueKeys: ["Error", "Info"], mount: .title, combinesContent: false).valueText
                == "Error, Info")
    }

    // MARK: - 横向读序（纯函数，双腿）

    @Test(".horizontal 读序优先级：按槽序递减，行内节点先于内容，非行子视图占一个槽")
    func horizontalReadingPriorities() {
        let slots = TimelineStackLayout.pairParts(roles: [nil, .node, .content, .node, .content, .content])
        #expect(TimelineStackLayout.readingPriorities(slots: slots, partCount: 6) == [0, -2, -3, -4, -5, -6])
        #expect(TimelineStackLayout.readingPriorities(slots: [], partCount: 0) == [])
    }

    // MARK: - 无障碍接线（源码，双腿）

    private static func sourceBody(of signature: String) throws -> String {
        let url = GuardScanRoots.repoRoot.appendingPathComponent("Sources/OhMyDesign/Components/Timeline/Timeline.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let start = text.range(of: signature) else { return "" }
        var depth = 0
        var body = ""
        for character in text[start.lowerBound...] {
            body.append(character)
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return body
    }

    @Test("接线（源码）：内容槽各分支挂合并 / 状态值 / .contain，横向容器挂读序优先级与 .contain，三个辅助修饰落到系统修饰")
    func accessibilityWiringInSource() throws {
        let slot = try Self.sourceBody(of: "private var contentSlot: some View {")
        for call in [
            ".timelineAccessibilityValue(accessibility.mount == .title ? accessibility.valueText : nil)",
            ".timelineContained(self.layoutContext == .horizontal)",
            ".timelineCombined(accessibility.combinesContent)",
            ".timelineContained(!accessibility.combinesContent && self.layoutContext == .horizontal)",
            ".timelineAccessibilityValue(accessibility.mount == .content ? accessibility.valueText : nil)",
        ] {
            #expect(slot.contains(call), "contentSlot 缺少 \(call)")
        }
        let stack = try Self.sourceBody(of: "private func stack(")
        for call in [
            "TimelineStackLayout.readingPriorities(slots: slots, partCount: subviews.count)",
            ".timelineSortPriority(priorities?[index])",
            ".timelineContained(priorities != nil)",
        ] {
            #expect(stack.contains(call), "stack 缺少 \(call)")
        }
        for (helper, system) in [
            ("func timelineContained(", "self.accessibilityElement(children: .contain)"),
            ("func timelineCombined(", "self.accessibilityElement(children: .combine)"),
            ("func timelineAccessibilityValue(", "self.accessibilityValue(Text(verbatim: value))"),
            ("func timelineSortPriority(", "self.accessibilitySortPriority(priority)"),
        ] {
            #expect(try Self.sourceBody(of: helper).contains(system), "\(helper) 没有落到 \(system)")
        }
    }

    // MARK: - 无障碍接线（iOS 进程内无障碍树）

    #if os(iOS)
    struct Element: Equatable {
        let label: String?
        let value: String?
        let isHeader: Bool
        let children: [Element]
    }

    // SwiftUI 只在系统「应用无障碍」开关打开时才生成 accessibilityElements；干净的模拟器（CI）上它是关的，读到的树恒为空。
    // 没有公开 API 能打开它，只能经 libAccessibility 的私有符号——不得删，删了这两条判据在 CI 上恒红。
    static func enableApplicationAccessibility() -> Bool {
        guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let setter = dlsym(handle, "_AXSApplicationAccessibilitySetEnabled"),
              let getter = dlsym(handle, "_AXSApplicationAccessibilityEnabled") else { return false }
        unsafeBitCast(setter, to: (@convention(c) (Bool) -> Void).self)(true)
        return unsafeBitCast(getter, to: (@convention(c) () -> Bool).self)()
    }

    static func accessibilityTree(_ view: some View) -> [Element] {
        #expect(Self.enableApplicationAccessibility(), "没能打开应用无障碍开关，读到的树不可信")
        let host = HostedWindow(view, size: CGSize(width: 390, height: 300), scheme: .light)
        defer { host.close() }
        func collect(_ object: Any) -> [Element] {
            guard let node = object as? NSObject else { return [] }
            let children = (node.accessibilityElements ?? []).flatMap { child -> [Element] in
                guard let child = child as? NSObject else { return [] }
                return [Element(
                    label: child.accessibilityLabel, value: child.accessibilityValue,
                    isHeader: child.accessibilityTraits.contains(.header), children: collect(child)
                )]
            }
            return children
        }
        return collect(host.root)
    }

    @Test("接线（iOS 无障碍树）：标题元素带值与 .isHeader；无标题默认圆点行合并成一个带值元素；自定义节点不传 status 不合并、无值；默认圆点不进树")
    func accessibilityWiringVertical() {
        let tree = Self.accessibilityTree(Timeline {
            TimelineItem("Alpha", time: Text(verbatim: "t1"), status: .danger)
            TimelineItem(status: .success) {
                Text(verbatim: "Beta")
                Text(verbatim: "Gamma")
            }
            TimelineItem { Text(verbatim: "N") } content: {
                Text(verbatim: "Delta")
                Text(verbatim: "Eps")
            }
        })
        let flat = tree.map { "\($0.label ?? "nil")|\($0.value ?? "nil")|\($0.isHeader)|\($0.children.count)" }
        #expect(flat.count == 6, "元素 \(flat)，应为 Alpha / t1 / Beta+Gamma / N / Delta / Eps")
        guard flat.count == 6 else { return }
        #expect(flat[0] == "Alpha|Error|true|0", "标题元素 \(flat[0])")
        #expect(flat[1] == "t1|nil|false|0", "时间元素 \(flat[1])")
        #expect(tree[2].value == "Success" && tree[2].label?.contains("Beta") == true && tree[2].label?.contains("Gamma") == true,
                "合并后的内容元素 \(flat[2])")
        #expect(Array(flat[3...]) == ["N|nil|false|0", "Delta|nil|false|0", "Eps|nil|false|0"], "自定义节点行 \(Array(flat[3...]))")
    }

    @Test("接线（iOS 无障碍树）：横向语境下有标题行与未合并的无标题行的内容各成一个 .contain 容器，合并行不包容器")
    func accessibilityWiringHorizontalContent() {
        let tree = Self.accessibilityTree(VStack {
            TimelineItem("Alpha", time: Text(verbatim: "t1"), status: .danger)
            TimelineItem { Text(verbatim: "N") } content: {
                Text(verbatim: "Delta")
                Text(verbatim: "Eps")
            }
            TimelineItem(status: .info) { Text(verbatim: "Zeta") }
        }
        .environment(\.timelineLayoutContext, .horizontal))
        let shape = tree.map { element in
            element.children.isEmpty
                ? "\(element.label ?? "nil")|\(element.value ?? "nil")"
                : "[" + element.children.map { "\($0.label ?? "nil")|\($0.value ?? "nil")" }.joined(separator: ", ") + "]"
        }
        #expect(shape == ["[Alpha|Error, t1|nil]", "N|nil", "[Delta|nil, Eps|nil]", "Zeta|Info"], "横向语境的树 \(shape)")
    }
    #endif

    // MARK: - 位图（macOS）

    #if os(macOS)
    private struct Canvas {
        let pixels: HostedPixels

        func device(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            guard let bytes = self.pixels.bytes, x >= 0, y >= 0, x < self.pixels.width, y < self.pixels.height else {
                return (-1, -1, -1)
            }
            let offset = (y * self.pixels.width + x) * 4
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
        }

        func at(_ x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
            self.device(Int(x * self.pixels.scale), Int(y * self.pixels.scale))
        }

        func isBlack(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r >= 0 && p.r < 40 && p.g < 40 && p.b < 40
        }

        func isBlue(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.b > 200 && p.r < 60 && p.g < 60
        }

        func isRed(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r > 200 && p.g < 60 && p.b < 60
        }

        func isGreen(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.g > 100 && p.r < 60 && p.b < 60
        }

        func isInk(_ x: Int, _ y: Int) -> Bool {
            let p = self.device(x, y)
            return p.r >= 0 && Swift.max(255 - p.r, 255 - p.g, 255 - p.b) > 40
        }

        func bounds(x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, _ match: (Int, Int) -> Bool) -> CGRect? {
            let scale = self.pixels.scale
            var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
            for py in Int(y.lowerBound * scale)..<Swift.min(Int(y.upperBound * scale), self.pixels.height) {
                for px in Int(x.lowerBound * scale)..<Swift.min(Int(x.upperBound * scale), self.pixels.width) where match(px, py) {
                    minX = Swift.min(minX, px); maxX = Swift.max(maxX, px)
                    minY = Swift.min(minY, py); maxY = Swift.max(maxY, py)
                }
            }
            guard maxX >= minX else { return nil }
            return CGRect(
                x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                width: CGFloat(maxX + 1 - minX) / scale, height: CGFloat(maxY + 1 - minY) / scale
            )
        }
    }

    private static func render(_ view: some View, size: CGSize = CGSize(width: 300, height: 360)) -> Canvas {
        Canvas(pixels: renderTimelineFixture(
            view
                .environment(\.coreMotionPresentationOverride, .resting)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white),
            size: size, scheme: .light
        ))
    }

    private static func node() -> some View {
        Color.black.frame(width: 10, height: 10)
    }

    private static func block(_ width: CGFloat, _ height: CGFloat = 20, red: Bool = false) -> some View {
        Color(red: red ? 1 : 0, green: 0, blue: red ? 0 : 1).frame(width: width, height: height)
    }

    private static let isShown = false
    private static let isAlsoShown = true

    @ViewBuilder
    private static func pairingRows() -> some View {
        Color(red: 0, green: 0.6, blue: 0).frame(width: 80, height: 10)
        ForEach(0..<2, id: \.self) { _ in
            TimelineItem { Self.node() } content: { Self.block(60) }
        }
        if Self.isAlsoShown {
            TimelineItem { Self.node() } content: { Self.block(50) }
        }
        if Self.isShown {
            TimelineItem { Self.node() } content: { Self.block(70) }
        }
        TimelineItem {
            Color.black.frame(width: 16, height: 4)
            Color.black.frame(width: 4, height: 16)
        } content: { Self.block(40) }
        TimelineItem { Self.node() } content: {
            Self.block(60)
            Self.block(40, red: true)
        }
        TimelineItem { Self.node() } content: {}
        TimelineItem { Self.node() } content: {
            if Self.isShown { Self.block(60) }
        }
        TimelineItem { Self.node() } content: { Self.block(30) }
    }

    @Test("配对与行序：非行 / ForEach / if / 多视图节点 / 多视图内容 / 空内容 / if false 内容逐行落位，容器中部无漏放的子视图")
    func pairingKeepsRowOrder() {
        let canvas = Self.render(Timeline { Self.pairingRows() })
        let header = canvas.bounds(x: 0...300, y: 0...10, canvas.isGreen)
        #expect(header.map { abs($0.minX - 36) <= 1 && abs($0.minY) <= 1 && abs($0.width - 80) <= 1 } == true,
                "非行子视图 \(String(describing: header))，应在内容列 x=36、y=0")
        for (top, width) in [(CGFloat(26), CGFloat(60)), (62, 60), (98, 50), (134, 40), (170, 60), (290, 30)] {
            let blue = canvas.bounds(x: 0...300, y: top...(top + 20), canvas.isBlue)
            #expect(blue.map { abs($0.minX - 36) <= 1 && abs($0.minY - top) <= 1 && abs($0.width - width) <= 1 } == true,
                    "y=\(top) 的内容 \(String(describing: blue))，应左缘 36、宽 \(width)")
        }
        let second = canvas.bounds(x: 0...300, y: 170...210, canvas.isRed)
        #expect(second.map { abs($0.minX - 36) <= 1 && abs($0.minY - 190) <= 1 } == true,
                "多视图内容的第二个视图 \(String(describing: second))，应紧贴第一个下方（36, 190）")
        for top in [CGFloat(26), 62, 98, 170, 226, 258, 290] {
            let node = canvas.bounds(x: 0...30, y: top...(top + 24), canvas.isBlack)
            #expect(node.map { abs($0.midX - 12) <= 1 && abs($0.midY - (top + 12)) <= 1 } == true,
                    "y=\(top) 的节点 \(String(describing: node))，应以 (12, \(top + 12)) 为中心")
        }
        let cross = canvas.bounds(x: 0...30, y: 134...158, canvas.isBlack)
        #expect(cross.map { abs($0.width - 16) <= 1 && abs($0.height - 16) <= 1 && abs($0.midY - 146) <= 1 } == true,
                "多视图节点 \(String(describing: cross))，应是一个盒里的 16×16 十字")
        let stray = canvas.bounds(x: 120...300, y: 0...360, canvas.isInk)
        #expect(stray == nil, "容器右半出现像素 \(String(describing: stray))——有子视图没被放置、落到了容器中心")
        let tail = canvas.bounds(x: 0...300, y: 316...360, canvas.isInk)
        #expect(tail == nil, "末行以下出现像素 \(String(describing: tail))，行数或行高不对")
    }

    @Test("孤立 / 重复部件（节点后不跟内容、内容前没有节点）按非行摆进内容列，不落到容器中心、不吞掉后续行")
    func orphanPartsAreNotDropped() {
        let canvas = Self.render(Timeline {
            Self.node().containerValue(\.timelinePart, TimelinePart(role: .node, step: nil, status: nil))
            TimelineItem { Self.node() } content: { Self.block(60) }
            Self.block(40, red: true).containerValue(\.timelinePart, TimelinePart(role: .content, step: nil, status: nil))
            TimelineItem { Self.node() } content: { Self.block(30) }
        })
        let orphanNode = canvas.bounds(x: 30...300, y: 0...20, canvas.isBlack)
        #expect(orphanNode.map { abs($0.minX - 36) <= 1 && abs($0.minY) <= 1 } == true,
                "孤立节点 \(String(describing: orphanNode))，应作为非行摆在内容列 (36, 0)")
        let rowA = canvas.bounds(x: 0...300, y: 26...46, canvas.isBlue)
        #expect(rowA.map { abs($0.minX - 36) <= 1 && abs($0.minY - 26) <= 1 } == true, "第一行内容 \(String(describing: rowA))")
        let orphanContent = canvas.bounds(x: 0...300, y: 62...82, canvas.isRed)
        #expect(orphanContent.map { abs($0.minX - 36) <= 1 && abs($0.minY - 62) <= 1 } == true,
                "孤立内容 \(String(describing: orphanContent))，应作为非行摆在 (36, 62)")
        let rowB = canvas.bounds(x: 0...300, y: 98...118, canvas.isBlue)
        #expect(rowB.map { abs($0.minX - 36) <= 1 && abs($0.minY - 98) <= 1 } == true, "第二行内容 \(String(describing: rowB))")
        let stray = canvas.bounds(x: 120...300, y: 0...360, canvas.isInk)
        #expect(stray == nil, "容器右半出现像素 \(String(describing: stray))——有子视图没被放置")
    }

    private static func delta(_ p: (r: Int, g: Int, b: Int), from q: (r: Int, g: Int, b: Int)) -> Int {
        Swift.max(abs(p.r - q.r), abs(p.g - q.g), abs(p.b - q.b))
    }

    @Test(".vertical 连线按行号取：隔着非行子视图的两行之间仍是一段贯穿线，终点在后一行节点盒上沿")
    func verticalConnectorSpansNonRowChild() {
        let canvas = Self.render(Timeline {
            TimelineItem { Self.node() } content: { Self.block(60, 40) }
            Self.block(40, 30, red: true)
            TimelineItem { Self.node() } content: { Self.block(60) }
            TimelineItem { Self.node() } content: { Self.block(60) }
        })
        let background = canvas.at(299, 359)
        let reference = Self.delta(canvas.at(12, 40), from: background)
        #expect(reference >= 6, "第 0 段中部与背景只差 \(reference)，无法下结论")
        for y in stride(from: CGFloat(26), through: 101, by: 5) {
            let delta = Self.delta(canvas.at(12, y), from: background)
            #expect(delta >= reference / 2 && delta <= reference * 2, "y=\(y)：第 0 段应从盒下沿 24 贯穿到下一行盒上沿 102，与背景差 \(delta)（线 \(reference)）")
        }
        let belowSecondBox = Self.delta(canvas.at(12, 130), from: background)
        #expect(belowSecondBox >= reference / 2, "第 1 段（第 1 行 → 第 2 行）缺失，与背景差 \(belowSecondBox)")
        let blue = canvas.bounds(x: 0...300, y: 102...122, canvas.isBlue)
        #expect(blue.map { abs($0.minY - 102) <= 1 } == true, "第 1 行内容 \(String(describing: blue))，应顶在 102")
    }

    @Test("z 序：连线画在节点之下——节点溢出盒外、压在中轴上的部分与盒内同色，未被连线色混过")
    func connectorsDrawUnderNodes() {
        let red = Color(red: 1, green: 0, blue: 0)
        let canvas = Self.render(Timeline {
            TimelineItem {
                red.frame(width: 24, height: 24).overlay { red.frame(width: 6, height: 40) }
            } content: { Self.block(60, 40) }
            TimelineItem { Self.node() } content: { Self.block(60) }
        })
        let background = canvas.at(299, 359)
        let line = Self.delta(canvas.at(12, 45), from: background)
        #expect(line >= 6, "盒外溢出段以下应有连线（与背景差 \(line)），否则本判据无从下结论")
        let inside = canvas.at(12, 12)
        #expect(inside.r > 200 && inside.g < 60 && inside.b < 60, "节点盒内 \(inside) 不是红色")
        for px in 23...24 {
            for py in 49...63 {
                let overflow = canvas.device(px, py)
                #expect(Self.delta(overflow, from: inside) <= 2,
                        "(\(px), \(py)) 设备像素：节点溢出段 \(overflow) 与盒内 \(inside) 不同——连线画在了节点之上")
            }
        }
    }

    @Test(".alternate：非行子视图跨满整行、压在中轴上时连线在它上沿截断、下沿续接（不从它底下穿过）")
    func alternateConnectorBreaksAtNonRowChild() {
        let canvas = Self.render(Timeline(layout: .alternate) {
            TimelineItem { Self.node() } content: { Self.block(60) }
            HStack(spacing: 0) {
                Self.block(140, red: true)
                Color.clear.frame(width: 20, height: 20)
                Self.block(140, red: true)
            }
            TimelineItem { Self.node() } content: { Self.block(60) }
        })
        let background = canvas.at(299, 359)
        let above = Self.delta(canvas.at(150, 30), from: background)
        #expect(above >= 6, "非行子视图上方应有连线（盒下沿 24 → 36），与背景差 \(above)")
        #expect(canvas.at(100, 46).r > 150, "非行子视图没画出来：\(canvas.at(100, 46))")
        for y in stride(from: CGFloat(37), through: 55, by: 2) {
            let onAxis = canvas.at(150, y)
            #expect(Self.delta(onAxis, from: background) <= 2,
                    "y=\(y)：连线从非行子视图（中轴处透明）底下穿过去了（\(onAxis)，背景 \(background)）")
        }
        let below = Self.delta(canvas.at(150, 64), from: background)
        #expect(below >= 6, "非行子视图下方应续接连线（56 → 72），与背景差 \(below)")
        let node = canvas.bounds(x: 140...160, y: 72...96, canvas.isBlack)
        #expect(node.map { abs($0.midY - 84) <= 1 } == true, "第 1 行节点 \(String(describing: node))，应以 y=84 为中心")
    }

    @Test("行上修饰作用于节点：.opacity(0.5) 施在行上，节点与内容都半透")
    func rowModifierReachesNode() {
        let canvas = Self.render(Timeline {
            TimelineItem { Color.black.frame(width: 20, height: 20) } content: { Self.block(60) }
                .opacity(0.5)
        })
        let node = canvas.at(12, 12)
        #expect((100...160).contains(node.r) && (100...160).contains(node.g), "节点中心 \(node)，应为半透的黑（≈128）")
        let content = canvas.at(60, 10)
        #expect((100...160).contains(content.r) && content.b > 200, "内容中心 \(content)，应为半透的蓝")
    }

    @Test("行被包进 VStack：降级为非行子视图，节点与内容都仍出现")
    func wrappedRowKeepsNodeAndContent() {
        let canvas = Self.render(Timeline {
            VStack(alignment: .leading, spacing: 0) {
                TimelineItem { Self.node() } content: { Self.block(60) }
            }
        })
        #expect(canvas.bounds(x: 0...300, y: 0...100, canvas.isBlack) != nil, "被包裹行的节点消失了")
        #expect(canvas.bounds(x: 0...300, y: 0...100, canvas.isBlue) != nil, "被包裹行的内容消失了")
    }

    @Test(".grouped 不摆节点：只有内容，没有节点像素")
    func groupedPlacesNoNodes() {
        let canvas = Self.render(Timeline(layout: .grouped) {
            TimelineItem { Self.node() } content: { Self.block(60) }
            TimelineItem { Self.node() } content: { Self.block(60) }
        })
        #expect(canvas.bounds(x: 0...300, y: 0...360, canvas.isBlack) == nil, ".grouped 出现了节点像素")
        let blue = canvas.bounds(x: 0...300, y: 0...360, canvas.isBlue)
        #expect(blue.map { abs($0.minX) <= 1 && abs($0.height - 52) <= 1 } == true,
                "内容 \(String(describing: blue))，应左缘 0、两行 20 + md + 20")
    }

    private struct LayoutProbe: View {
        let red: Bool
        @Environment(\.timelineLayoutContext) private var context

        var body: some View {
            let width: CGFloat = switch self.context {
            case nil: 8
            case .vertical: 16
            default: 4
            }
            Color(red: self.red ? 1 : 0, green: 0, blue: self.red ? 0 : 1).frame(width: width, height: 10)
        }
    }

    @Test("解析前通路：直接子视图自身的 body、节点槽、内容槽都读到传给 Timeline 的 layout，Timeline 外读到默认值")
    func layoutContextReachesBothSlots() {
        let canvas = Self.render(VStack(alignment: .leading, spacing: 0) {
            Timeline {
                TimelineItem { LayoutProbe(red: true) } content: { LayoutProbe(red: false) }
                LayoutProbe(red: true)
            }
            LayoutProbe(red: false)
        })
        let direct = canvas.bounds(x: 30...300, y: 30...50, canvas.isRed)
        #expect(direct.map { abs($0.width - 16) <= 1 } == true,
                "直接子视图（非行，自身 body 读环境）读数 \(String(describing: direct?.width))，应为 .vertical ⇒ 16——行的 body 靠的就是这条通路")
        let node = canvas.bounds(x: 0...30, y: 0...24, canvas.isRed)
        #expect(node.map { abs($0.width - 16) <= 1 } == true, "节点槽读数 \(String(describing: node?.width))，应为 .vertical ⇒ 16")
        let content = canvas.bounds(x: 30...300, y: 0...24, canvas.isBlue)
        #expect(content.map { abs($0.width - 16) <= 1 } == true, "内容槽读数 \(String(describing: content?.width))，应为 .vertical ⇒ 16")
        let outside = canvas.bounds(x: 0...300, y: 40...60, canvas.isBlue)
        #expect(outside.map { abs($0.width - 8) <= 1 } == true, "Timeline 外读数 \(String(describing: outside?.width))，应为默认 ⇒ 8")
    }

    private struct PhaseProbe: View {
        let red: Bool
        @Environment(\.timelinePhase) private var phase

        var body: some View {
            Color(red: self.red ? 1 : 0, green: 0, blue: self.red ? 0 : 1)
                .frame(width: TimelineCompositionTests.probeWidth(self.phase), height: 10)
        }
    }

    private static func probeWidth(_ phase: TimelinePhase?) -> CGFloat {
        switch phase {
        case nil: 4
        case .completed: 8
        case .inProgress: 12
        case .upcoming: 16
        }
    }

    @Test("timelinePhase：Timeline(progress:) 内带 step 的行，节点槽与内容槽都读到本行阶段；无 step 的行、非行子视图、不传 progress 的 Timeline 与 Timeline 外恒为 nil")
    func phaseReachesBothSlots() {
        let canvas = Self.render(VStack(alignment: .leading, spacing: 0) {
            Timeline(progress: .inProgress(at: 1)) {
                TimelineItem(step: 0) { PhaseProbe(red: true) } content: { PhaseProbe(red: false) }
                TimelineItem(step: 1) { PhaseProbe(red: true) } content: { PhaseProbe(red: false) }
                TimelineItem(step: 2) { PhaseProbe(red: true) } content: { PhaseProbe(red: false) }
                TimelineItem { PhaseProbe(red: true) } content: { PhaseProbe(red: false) }
                PhaseProbe(red: true)
            }
            Timeline {
                TimelineItem(step: 0) { PhaseProbe(red: true) } content: { PhaseProbe(red: false) }
            }
            PhaseProbe(red: false)
        })
        let rows: [(CGFloat, TimelinePhase?, String)] = [
            (0, .completed, "step 0"), (32, .inProgress, "step 1"), (64, .upcoming, "step 2"), (96, nil, "无 step"),
        ]
        for (top, phase, name) in rows {
            let expected = Self.probeWidth(phase)
            let node = canvas.bounds(x: 0...30, y: top...(top + 24), canvas.isRed)
            #expect(node.map { abs($0.width - expected) <= 1 } == true,
                    "\(name) 节点槽读数 \(String(describing: node?.width))，应为 \(String(describing: phase)) ⇒ \(expected)")
            let content = canvas.bounds(x: 30...300, y: top...(top + 10), canvas.isBlue)
            #expect(content.map { abs($0.width - expected) <= 1 } == true,
                    "\(name) 内容槽读数 \(String(describing: content?.width))，应为 \(String(describing: phase)) ⇒ \(expected)")
        }
        let free = canvas.bounds(x: 30...300, y: 128...138, canvas.isRed)
        #expect(free.map { abs($0.width - 4) <= 1 } == true, "非行子视图读数 \(String(describing: free?.width))，应为 nil ⇒ 4")
        let plainNode = canvas.bounds(x: 0...30, y: 138...162, canvas.isRed)
        let plainContent = canvas.bounds(x: 30...300, y: 138...148, canvas.isBlue)
        #expect(plainNode.map { abs($0.width - 4) <= 1 } == true && plainContent.map { abs($0.width - 4) <= 1 } == true,
                "不传 progress 的行读数 \(String(describing: plainNode?.width)) / \(String(describing: plainContent?.width))，应为 nil ⇒ 4")
        let outside = canvas.bounds(x: 0...300, y: 162...172, canvas.isBlue)
        #expect(outside.map { abs($0.width - 4) <= 1 } == true, "Timeline 外读数 \(String(describing: outside?.width))，应为 nil ⇒ 4")
    }

    @Test("嵌套：外层行内容里的 Timeline，其非行子视图读不到外层行的阶段（恒为 nil）；内层带阶段的行读自己的阶段")
    func nestedTimelineResetsPhase() {
        let canvas = Self.render(Timeline(progress: .completed) {
            TimelineItem(step: 0) { Color.clear.frame(width: 10, height: 10) } content: {
                Timeline { PhaseProbe(red: false) }
                Timeline(progress: .notStarted) {
                    PhaseProbe(red: true)
                    TimelineItem(step: 0) { Color.clear.frame(width: 10, height: 10) } content: { PhaseProbe(red: false) }
                }
            }
        })
        let plain = canvas.bounds(x: 0...300, y: 0...8, canvas.isBlue)
        #expect(plain.map { abs($0.width - 4) <= 1 } == true,
                "不传 progress 的内层 Timeline 的非行子视图读数 \(String(describing: plain?.width))，应为 nil ⇒ 4（外层行是 .completed ⇒ 8）")
        let free = canvas.bounds(x: 0...300, y: 0...120, canvas.isRed)
        #expect(free.map { abs($0.width - 4) <= 1 } == true,
                "带 progress 的内层 Timeline 的非行子视图读数 \(String(describing: free?.width))，应为 nil ⇒ 4")
        let row = canvas.bounds(x: 0...300, y: 12...120, canvas.isBlue)
        #expect(row.map { abs($0.width - 16) <= 1 } == true, "内层行读数 \(String(describing: row?.width))，应为 .upcoming ⇒ 16")
    }
    #endif
}
