import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 选择归约 / Selection reducer

@Suite("TagGroup 选择归约")
@MainActor
struct TagGroupSelectionTests {
    private static let data: Set<String> = ["a", "b", "c"]

    private func toggled(
        _ id: String,
        in selection: Set<String>,
        disabled: Set<String> = [],
        mode: TagGroupSelectionMode
    ) -> Set<String> {
        TagGroupSelection.toggled(id, in: selection, dataIDs: Self.data, disabled: disabled, mode: mode)
    }

    @Test("multiple：点未选加入、点已选移出，其余不动")
    func multipleTogglesOnlyTheTappedID() {
        #expect(self.toggled("b", in: ["a"], mode: .multiple) == ["a", "b"])
        #expect(self.toggled("a", in: ["a", "b"], mode: .multiple) == ["b"])
    }

    @Test("single：点未选 = 把数据内已选集合替换为该项")
    func singleReplacesInDataSelection() {
        #expect(self.toggled("b", in: ["a"], mode: .single) == ["b"])
        #expect(self.toggled("a", in: [], mode: .single) == ["a"])
    }

    @Test("single：点已选 = 取消，允许空选")
    func singleTapOnSelectedClears() {
        #expect(self.toggled("a", in: ["a"], mode: .single) == [])
    }

    @Test("single：外部写入多个数据内 ID，下一次点选归一到 ≤ 1")
    func singleNormalisesExternalMultiSelectionOnNextTap() {
        #expect(self.toggled("c", in: ["a", "b"], mode: .single) == ["c"])
        #expect(self.toggled("a", in: ["a", "b"], mode: .single) == [])
    }

    @Test("未知 ID 在每条路径上原样保留、永不被增删")
    func unknownIDsArePreserved() {
        let unknown: Set<String> = ["zz", "yy"]
        for mode in TagGroupSelectionMode.allCases {
            #expect(self.toggled("b", in: unknown.union(["a"]), mode: mode).isSuperset(of: unknown),
                    "\(mode)：点未选项丢了未知 ID")
            #expect(self.toggled("a", in: unknown.union(["a"]), mode: mode).isSuperset(of: unknown),
                    "\(mode)：点已选项丢了未知 ID")
        }
        #expect(self.toggled("zz", in: unknown, mode: .multiple) == unknown, "点不在数据里的 ID 改写了绑定")
        #expect(self.toggled("new", in: unknown, mode: .single) == unknown, "不在数据里的 ID 被加入了绑定")
    }

    @Test("禁用项不可切换（无论已选与否），.none 模式任何点击都不改写")
    func disabledAndNoneNeverWrite() {
        for mode in TagGroupSelectionMode.allCases {
            #expect(self.toggled("a", in: ["a"], disabled: ["a"], mode: mode) == ["a"])
            #expect(self.toggled("a", in: ["b"], disabled: ["a"], mode: mode) == ["b"])
        }
        #expect(self.toggled("a", in: ["b"], mode: .none) == ["b"])
        #expect(self.toggled("b", in: ["b"], mode: .none) == ["b"])
    }

    @Test("基数只计数据内 ID：single 下未知 ID 不占名额")
    func cardinalityCountsOnlyDataIDs() {
        let result = self.toggled("a", in: ["zz"], mode: .single)
        #expect(result == ["a", "zz"])
        #expect(result.intersection(Self.data).count == 1)
    }

    @Test("重复 ID 检测：只报出现多于一次的 ID")
    func duplicateIDsAreDetected() {
        #expect(TagGroupSelection.duplicateIDs(["a", "b", "a", "c", "b"]) == ["a", "b"])
        #expect(TagGroupSelection.duplicateIDs(["a", "b", "c"]).isEmpty)
    }

    @Test("无障碍 trait：可选模式是按钮，已选带 .isSelected；.none 不是按钮")
    func accessibilityTraitsFollowModeAndSelection() {
        #expect(TagGroupSelection.traits(selected: true, mode: .single) == [.isButton, .isSelected])
        #expect(TagGroupSelection.traits(selected: false, mode: .multiple) == .isButton)
        #expect(TagGroupSelection.traits(selected: true, mode: .none) == .isSelected)
        #expect(TagGroupSelection.traits(selected: false, mode: .none) == [])
    }
}

// MARK: - 视图行为 / View behaviour

private struct Item: Identifiable, Hashable {
    let id: String
}

private let sampleItems = ["Swift", "Kotlin", "Rust"].map(Item.init(id:))

@Suite("TagGroup 视图")
@MainActor
struct TagGroupViewTests {
    private static let ladder: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]

    private func render(_ view: some View, scheme: ColorScheme = .light) -> CGImage? {
        let renderer = ImageRenderer(
            content: view.dynamicTypeSize(.large).environment(\.colorScheme, scheme)
        )
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pixels(_ view: some View, scheme: ColorScheme = .light) -> [UInt8]? {
        guard let image = self.render(view, scheme: scheme) else { return nil }
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? bytes : nil
    }

    /// 按钮树与参照 `Tag` 树是两棵不同的视图树：全量并行跑时实测抗锯齿边缘偶有 Δ=1 的量化差
    /// （≤ 9 / 13608 字节，约 0.07%），单跑不复现。容差只放这一档：Δ ≤ 1 且差异字节 ≤ 0.2%；
    /// 换色、换字重、漏描边都是 Δ ≫ 1 或大面积差异，仍会判红。
    private func expectMatchesReference(
        _ a: [UInt8]?, _ b: [UInt8]?, _ comment: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        expectBitmapsEquivalent(
            a, b, maxChannelDelta: 1, maxDifferingFraction: 0.002, comment, sourceLocation: sourceLocation
        )
    }

    private func group(
        selection: Set<String>,
        mode: TagGroupSelectionMode = .multiple,
        disabled: Set<String> = []
    ) -> some View {
        TagGroup(
            [Item(id: "Swift")],
            selection: .constant(selection),
            selectionMode: mode,
            disabled: disabled,
            color: .red
        ) { _ in
            Self.glyphFreeLabel
        }
        .fixedSize()
    }

    private static var glyphFreeLabel: some View {
        Color.clear.frame(width: 24, height: 12)
    }

    @Test("选中与未选渲染不同（明暗两档）")
    func selectedDiffersFromUnselected() {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsDiffer(
                self.pixels(self.group(selection: ["Swift"]), scheme: scheme),
                self.pixels(self.group(selection: []), scheme: scheme),
                "\(scheme)：选中态没有画出来"
            )
        }
    }

    @Test("选中底色与描边随自定义 coreAccent 变化（明暗两档）")
    func selectedChromeFollowsCoreAccent() {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsDiffer(
                self.pixels(self.group(selection: ["Swift"]).coreAccent(.red), scheme: scheme),
                self.pixels(self.group(selection: ["Swift"]).coreAccent(.green), scheme: scheme),
                "\(scheme)：选中态没跟随 coreAccent —— 仍在读静态 accent"
            )
        }
    }

    @Test("未选态不受 coreAccent 影响（明暗两档）")
    func unselectedIgnoresCoreAccent() {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsEquivalent(
                self.pixels(self.group(selection: []).coreAccent(.red), scheme: scheme),
                self.pixels(self.group(selection: []).coreAccent(.green), scheme: scheme),
                maxChannelDelta: 1,
                "\(scheme)：未选态读了 coreAccent"
            )
        }
    }

    @Test("选中态逐像素等于 Tag 叠上 accent 派生的底色与描边")
    func selectedChromeMatchesAccentDerivation() {
        let accent = Color.blue
        let reference = Tag(color: .red) { Self.glyphFreeLabel }
            .environment(
                \.tagSelectionChrome,
                TagSelectionChrome(
                    fill: .accentSubtleBackground(from: accent),
                    stroke: .accentSelectedBorder(from: accent)
                )
            )
            .fixedSize()
        for scheme in [ColorScheme.light, .dark] {
            self.expectMatchesReference(
                self.pixels(self.group(selection: ["Swift"]).coreAccent(accent), scheme: scheme),
                self.pixels(reference, scheme: scheme),
                "\(scheme)：选中态没有走 InteractionColors 的 accent 派生函数"
            )
        }
    }

    @Test("禁用项可显示为已选：禁用 + 已选 ≠ 禁用 + 未选")
    func disabledItemStillShowsSelection() {
        expectBitmapsDiffer(
            self.pixels(self.group(selection: ["Swift"], disabled: ["Swift"])),
            self.pixels(self.group(selection: [], disabled: ["Swift"])),
            "禁用项把选中态吞掉了"
        )
    }

    @Test(".none 模式照样渲染绑定里的选中态")
    func noneModeRendersSelection() {
        expectBitmapsDiffer(
            self.pixels(self.group(selection: ["Swift"], mode: .none)),
            self.pixels(self.group(selection: [], mode: .none)),
            ".none 模式没有画出选中态"
        )
    }

    @Test("五档 controlSize：TagGroup 高度严格递增")
    func followsControlSize() throws {
        var heights: [Int] = []
        for size in Self.ladder {
            let image = try #require(self.render(
                TagGroup([Item(id: "Swift")], selection: .constant(["Swift"]), color: .red) { Text($0.id) }
                    .fixedSize()
                    .controlSize(size)
            ))
            heights.append(image.height)
        }
        for (lower, upper) in zip(heights, heights.dropFirst()) {
            #expect(upper > lower, "高度未随档严格递增：\(heights)")
        }
    }

    @Test("真实文字：未选按钮与普通 Tag 逐像素一致（明暗两档）")
    func unselectedTextMatchesPlainTag() {
        for scheme in [ColorScheme.light, .dark] {
            self.expectMatchesReference(
                self.pixels(
                    TagGroup([Item(id: "Swift")], selection: .constant([]), color: .red) { Text($0.id) }.fixedSize(),
                    scheme: scheme
                ),
                self.pixels(Tag("Swift", color: .red).fixedSize(), scheme: scheme),
                "\(scheme)：未选按钮与普通 Tag 不一致"
            )
        }
    }

    @Test("真实文字：选中按钮与 Tag + accent 派生外观逐像素一致（明暗两档）")
    func selectedTextMatchesDerivedReference() {
        let accent = Color.blue
        let reference = Tag("Swift", color: .red)
            .environment(
                \.tagSelectionChrome,
                TagSelectionChrome(
                    fill: .accentSubtleBackground(from: accent),
                    stroke: .accentSelectedBorder(from: accent)
                )
            )
            .fixedSize()
        for scheme in [ColorScheme.light, .dark] {
            self.expectMatchesReference(
                self.pixels(
                    TagGroup([Item(id: "Swift")], selection: .constant(["Swift"]), color: .red) { Text($0.id) }
                        .fixedSize()
                        .coreAccent(accent),
                    scheme: scheme
                ),
                self.pixels(reference, scheme: scheme),
                "\(scheme)：选中按钮与派生参照不一致"
            )
        }
    }

    @Test("命中区外扩不撑高布局：TagGroup 与同宽 FlowLayout + Tag 等高")
    func hitAreaDoesNotInflateLayout() throws {
        for size in Self.ladder {
            let group = try #require(self.render(
                TagGroup(sampleItems, selection: .constant([]), color: .red) { Text($0.id) }
                    .frame(width: 160).controlSize(size)
            ))
            let plain = try #require(self.render(
                FlowLayout(spacing: CoreSpacing.xs) {
                    ForEach(sampleItems) { Tag($0.id, color: .red) }
                }
                .frame(width: 160).controlSize(size)
            ))
            #expect(group.height == plain.height, "\(size)：TagGroup 高 \(group.height) ≠ FlowLayout+Tag 高 \(plain.height)")
        }
    }
}

// MARK: - 命中区 / Hit area

@Suite("TagGroup 命中区")
@MainActor
struct TagGroupHitShapeTests {
    @Test("小于 44pt 的标签：命中形状两轴都外扩到 44pt，中心不变")
    func smallTagsExpandOnBothAxes() {
        for side in [CGFloat(18), 20, 24, 32] {
            let rect = CGRect(x: 0, y: 0, width: side, height: side + 2)
            let hit = TagGroupHitShape().path(in: rect).boundingRect
            #expect(hit.width >= 44 && hit.height >= 44, "\(rect.size) 标签命中框 \(hit.size)")
            #expect(hit.midX == rect.midX && hit.midY == rect.midY)
        }
        let wide = CGRect(x: 0, y: 0, width: 60, height: 20)
        let wideHit = TagGroupHitShape().path(in: wide).boundingRect
        #expect(wideHit.width == 60 && wideHit.height == 44)
    }

    @Test("已达 44pt 的标签：命中形状即自身")
    func largeTagsKeepTheirBounds() {
        let rect = CGRect(x: 0, y: 0, width: 60, height: 50)
        #expect(TagGroupHitShape().path(in: rect).boundingRect == rect)
    }

    @Test("窄短标签（单字符，mini / regular）：命中框 ≥ 44×44，布局尺寸与 Tag 相同")
    func narrowTagsGetFullTarget() throws {
        for size in [ControlSize.mini, .regular] {
            let tagRenderer = ImageRenderer(content: Tag("A", color: .red).fixedSize().controlSize(size))
            tagRenderer.scale = 1
            let tag = try #require(tagRenderer.cgImage)
            let groupRenderer = ImageRenderer(
                content: TagGroup([Item(id: "A")], selection: .constant([]), color: .red) { Text($0.id) }
                    .fixedSize().controlSize(size)
            )
            groupRenderer.scale = 1
            let group = try #require(groupRenderer.cgImage)
            #expect(tag.width < 44 && tag.height < 44, "\(size)：样本不够窄短，判据无效：\(tag.width)×\(tag.height)")
            #expect(group.width == tag.width && group.height == tag.height,
                    "\(size)：TagGroup 布局 \(group.width)×\(group.height) ≠ Tag \(tag.width)×\(tag.height)")
            let hit = TagGroupHitShape()
                .path(in: CGRect(x: 0, y: 0, width: tag.width, height: tag.height)).boundingRect
            #expect(hit.width >= 44 && hit.height >= 44, "\(size)：命中框 \(hit.size)")
        }
    }
}

// MARK: - 选中外观隔离 / Chrome isolation

@MainActor
private final class ChromeSink {
    var seen: [Bool] = []
}

private struct ChromeProbe: View {
    @Environment(\.tagSelectionChrome) private var chrome
    let sink: ChromeSink

    var body: some View {
        self.sink.seen.append(self.chrome != nil)
        return Color.clear.frame(width: 8, height: 8)
    }
}

@Suite("TagGroup 选中外观不漏进 label")
@MainActor
struct TagGroupChromeIsolationTests {
    @Test("选中标签的 label 子树读不到 tagSelectionChrome（嵌套的独立 Tag 保持自身外观）")
    func chromeStopsAtLabelBoundary() throws {
        let sink = ChromeSink()
        let renderer = ImageRenderer(
            content: TagGroup([Item(id: "Swift")], selection: .constant(["Swift"]), color: .red) { _ in
                ChromeProbe(sink: sink)
            }
            .fixedSize()
        )
        _ = try #require(renderer.cgImage)
        #expect(!sink.seen.isEmpty, "探针没有被求值，判据无效")
        #expect(!sink.seen.contains(true), "选中外观漏进了调用方 label：\(sink.seen)")
    }
}

// MARK: - 绑定写入 / Binding writes

@MainActor
private final class TagGroupHost<Root: View> {
    #if canImport(UIKit)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
    private let controller: UIHostingController<Root>
    #else
    private let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 390, height: 400),
        styleMask: [.titled], backing: .buffered, defer: false
    )
    private let host: NSHostingView<Root>
    #endif

    init(_ root: Root) {
        #if canImport(UIKit)
        self.controller = UIHostingController(rootView: root)
        self.window.rootViewController = self.controller
        self.window.makeKeyAndVisible()
        #else
        self.host = NSHostingView(rootView: root)
        self.host.frame = self.window.contentRect(forFrameRect: self.window.frame)
        self.window.contentView = self.host
        #endif
        self.pump()
    }

    func update(_ root: Root) {
        #if canImport(UIKit)
        self.controller.rootView = root
        #else
        self.host.rootView = root
        #endif
        self.pump()
    }

    private func pump() {
        for _ in 0..<5 {
            #if canImport(UIKit)
            self.controller.view.layoutIfNeeded()
            #else
            self.host.layoutSubtreeIfNeeded()
            #endif
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func tearDown() {
        #if canImport(UIKit)
        self.window.isHidden = true
        #else
        self.window.orderOut(nil)
        #endif
    }
}

@MainActor
private final class WriteLog {
    var writes: [Set<String>] = []
}

private struct ModeSwitchRoot: View {
    let mode: TagGroupSelectionMode
    let stored: Set<String>
    let log: WriteLog

    var body: some View {
        TagGroup(
            sampleItems,
            selection: Binding(get: { self.stored }, set: { self.log.writes.append($0) }),
            selectionMode: self.mode,
            color: .red
        ) { Text($0.id) }
    }
}

@Suite("TagGroup 绑定")
@MainActor
struct TagGroupBindingTests {
    @Test("切换 selectionMode 不改写绑定（含外部写入的多个数据内 ID 与未知 ID）")
    func switchingModeNeverWrites() {
        let log = WriteLog()
        let stored: Set<String> = ["Swift", "Rust", "unknown"]
        let host = TagGroupHost(ModeSwitchRoot(mode: .multiple, stored: stored, log: log))
        defer { host.tearDown() }
        for mode in [TagGroupSelectionMode.single, .none, .multiple, .single] {
            host.update(ModeSwitchRoot(mode: mode, stored: stored, log: log))
        }
        #expect(log.writes.isEmpty, "切换模式写了绑定：\(log.writes)")
    }
}
