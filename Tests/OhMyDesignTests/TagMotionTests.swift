import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 增删转场的取值 / Collection item transition values

@Suite("集合项增删转场：Reduce Motion 下只剩透明度")
struct CollectionItemTransitionTests {
    private static let phases: [TransitionPhase] = [.willAppear, .identity, .didDisappear]

    @Test("animated：进出两相缩到 enteringScale，identity 为 1")
    func animatedScalesOnBothEdges() {
        let scales = Self.phases.map { CollectionItemTransition.scale(for: .animated, phase: $0) }
        #expect(scales == [CollectionItemTransition.enteringScale, 1, CollectionItemTransition.enteringScale])
        #expect(CollectionItemTransition.enteringScale < 1, "缩放档位不小于 1，转场看不出缩放")
    }

    @Test("resting / hidden：每一相的缩放都是 1（框架不替调用方去掉缩放）")
    func restingNeverScales() {
        for presentation in [MotionPresentation.resting, .hidden] {
            let scales = Self.phases.map { CollectionItemTransition.scale(for: presentation, phase: $0) }
            #expect(scales == [1, 1, 1], "\(presentation)：转场仍带缩放 \(scales)")
        }
    }

    @Test("透明度只看相位，与呈现裁决无关：identity 为 1，进出两相为 0")
    func opacityFollowsPhaseOnly() {
        #expect(Self.phases.map { CollectionItemTransition.opacity(for: $0) } == [0, 1, 0])
    }

    @Test("hasMotion 显式声明为 true：animated 一侧确有几何运动（#292 花名册要求的运行时判据）")
    func propertiesDeclareMotion() {
        #expect(CollectionItemTransition.properties.hasMotion)
    }

    @Test("MotionPresentation.collectionItemTransition 原样带上自己的裁决")
    func presentationCarriesItsVerdict() {
        for presentation in [MotionPresentation.animated, .resting, .hidden] {
            #expect(presentation.collectionItemTransition.presentation == presentation)
        }
    }

    @Test("增删用的动画：animated 取 reveal 曲线，resting 为 nil（位移不补间）")
    func insertionAnimationIsNilWhenResting() {
        #expect(CoreMotionToken.reveal.transformAnimation(for: .resting) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .hidden) == nil)
        #expect(CoreMotionToken.reveal.transformAnimation(for: .animated) == CoreMotionToken.reveal.animation)
    }

    @Test("选中态用的动画：两种呈现都非 nil —— 纯色插值不含几何，不必关掉")
    func selectionAnimationSurvivesReduceMotion() {
        #expect(CoreMotionToken.selection.animation(for: .animated) != nil)
        #expect(CoreMotionToken.selection.animation(for: .resting) != nil)
    }
}

// MARK: - 静态外观 / Static appearance

@Suite("标签静息外观不随呈现裁决变化")
@MainActor
struct TagStaticAppearanceTests {
    private static let ladder: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]

    private static let presentations: [MotionPresentation] = [.animated, .resting, .hidden]

    private static let sampleItems = ["Swift", "Kotlin", "Rust"].map(StaticItem.init(id:))

    struct StaticItem: Identifiable, Hashable {
        let id: String
    }

    private func pixels(_ view: some View, scheme: ColorScheme, width: CGFloat? = nil) -> [UInt8]? {
        let sized = width.map { AnyView(view.frame(width: $0, alignment: .leading)) } ?? AnyView(view.fixedSize())
        let renderer = ImageRenderer(
            content: sized.dynamicTypeSize(.large).environment(\.colorScheme, scheme)
        )
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    /// ⚠️ 不能用 `expectBitmapsEqual`：本套判据在同一进程里连渲多张，而 macOS 离屏渲染的
    /// **前几张**与稳定输出之间有 1 个 LSB 的量化差（`#317`）。实测同一份输入
    /// （`mini` 档 TagInput，197120 B 帧）`render0` 与 `render2` / `render3` 差 4 / 19 字节、
    /// 逐通道偏差 1，而 `render3` 与另两种呈现裁决的图**逐字节相同** ⇒ 噪声来自渲染次序，
    /// 不是呈现裁决。上限取 0.2%（与 `TagGroupTests` 同款），是实测噪声 0.0096% 的 20 倍；
    /// 呈现裁决真改了静息外观时是 Δ ≫ 1 或大面积差异，仍会判红。
    private func expectSettledMatch(
        _ a: [UInt8]?, _ b: [UInt8]?, _ comment: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        expectBitmapsEquivalent(
            a, b, maxChannelDelta: 1, maxDifferingFraction: 0.002, comment, sourceLocation: sourceLocation
        )
    }

    private func group(selection: Set<String>, size: ControlSize) -> some View {
        TagGroup(Self.sampleItems, selection: .constant(selection), color: .red) { Text(verbatim: $0.id) }
            .coreAccent(.blue)
            .controlSize(size)
    }

    @Test("TagGroup：五档 controlSize × 选中与否 × light / dark，三种呈现裁决下静息位图在光栅化噪声内相同")
    func tagGroupIgnoresPresentationWhenSettled() {
        for size in Self.ladder {
            for selection in [Set<String>(), ["Kotlin"]] {
                for scheme in [ColorScheme.light, .dark] {
                    let reference = self.pixels(
                        self.group(selection: selection, size: size)
                            .environment(\.coreMotionPresentationOverride, MotionPresentation.animated),
                        scheme: scheme, width: 280
                    )
                    for presentation in Self.presentations.dropFirst() {
                        self.expectSettledMatch(
                            self.pixels(
                                self.group(selection: selection, size: size)
                                    .environment(\.coreMotionPresentationOverride, presentation),
                                scheme: scheme, width: 280
                            ),
                            reference,
                            "\(size) selection=\(selection.sorted()) \(scheme) \(presentation)：静息外观被呈现裁决改了"
                        )
                    }
                }
            }
        }
    }

    @Test("TagInput：五档 controlSize × light / dark，三种呈现裁决下静息位图在光栅化噪声内相同")
    func tagInputIgnoresPresentationWhenSettled() {
        for size in Self.ladder {
            for scheme in [ColorScheme.light, .dark] {
                let reference = self.pixels(
                    TagInput(tags: .constant(["design", "ios"]), tagColor: .red).controlSize(size)
                        .environment(\.coreMotionPresentationOverride, MotionPresentation.animated),
                    scheme: scheme, width: 280
                )
                for presentation in Self.presentations.dropFirst() {
                    self.expectSettledMatch(
                        self.pixels(
                            TagInput(tags: .constant(["design", "ios"]), tagColor: .red).controlSize(size)
                                .environment(\.coreMotionPresentationOverride, presentation),
                            scheme: scheme, width: 280
                        ),
                        reference,
                        "\(size) \(scheme) \(presentation)：静息外观被呈现裁决改了"
                    )
                }
            }
        }
    }

    @Test("判据有效性：选中与未选本身是不同的两张图")
    func selectionIsVisible() {
        for scheme in [ColorScheme.light, .dark] {
            expectBitmapsDiffer(
                self.pixels(self.group(selection: ["Kotlin"], size: .regular), scheme: scheme, width: 280),
                self.pixels(self.group(selection: [], size: .regular), scheme: scheme, width: 280),
                "\(scheme)：选中态与未选态同图 —— 上面两条相等判据无效"
            )
        }
    }
}

// MARK: - 动画进行中 / In-flight frames

// iOS 上 `layer.render(in:)` 取的是模型层，拍不到进行中的帧 ⇒ 只在 macOS 腿观测。
#if os(macOS)

@MainActor
private final class TagsBox: ObservableObject {
    @Published var tags: [String] = ["alpha", "bravo", "charlie"]
}

private struct TagInputHarness: View {
    @ObservedObject var box: TagsBox

    var body: some View {
        TagInput(tags: self.$box.tags, tagColor: .red)
            .frame(width: 320, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct GroupItem: Identifiable, Hashable {
    let id: String
}

@MainActor
private final class GroupBox: ObservableObject {
    @Published var items: [GroupItem] = ["alpha", "bravo", "charlie"].map(GroupItem.init(id:))
    @Published var selection: Set<String> = []
}

private struct TagGroupHarness: View {
    @ObservedObject var box: GroupBox

    var body: some View {
        TagGroup(self.box.items, selection: self.$box.selection, color: .red) { Text(verbatim: $0.id) }
            .coreAccent(.blue)
            .frame(width: 320, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

@Suite("标签增删 / 选中动画进行中的帧", .serialized)
@MainActor
struct TagMotionInFlightTests {
    static let size = CGSize(width: 320, height: 120)

    static let samplingWindows: [TimeInterval] = [0.4, 0.6, 0.9]

    static func differs(_ a: HostedPixels, _ b: HostedPixels, threshold: Int) -> Bool {
        guard let x = a.bytes, let y = b.bytes, x.count == y.count else { return false }
        for index in stride(from: 0, to: x.count, by: 4) {
            for channel in 0..<3 where abs(Int(x[index + channel]) - Int(y[index + channel])) > threshold {
                return true
            }
        }
        return false
    }

    /// 与起点、终点**都**不同的帧数：动画真的在补间时为正，`nil` 动画时为 0。
    static func transientFrames(_ frames: [HostedPixels], before: HostedPixels, after: HostedPixels, threshold: Int = 16) -> Int {
        frames.filter {
            Self.differs($0, before, threshold: threshold) && Self.differs($0, after, threshold: threshold)
        }
        .count
    }

    static func changedBounds(_ a: HostedPixels, _ b: HostedPixels, threshold: Int = 16) -> CGRect? {
        guard let x = a.bytes, let y = b.bytes, x.count == y.count, a.width > 0 else { return nil }
        var minX = a.width, maxX = -1, minY = a.height, maxY = -1
        for index in stride(from: 0, to: x.count, by: 4) {
            let changed = (0..<3).contains { abs(Int(x[index + $0]) - Int(y[index + $0])) > threshold }
            guard changed else { continue }
            let pixel = index / 4
            let px = pixel % a.width, py = pixel / a.width
            minX = min(minX, px); maxX = max(maxX, px)
            minY = min(minY, py); maxY = max(maxY, py)
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// 在托管窗口里改一次状态（动画由被测视图自己的 `.animation(_:value:)` 给出，不额外包 `withAnimation`）。
    static func sample<Root: View>(
        _ root: (MotionPresentation) -> Root,
        presentation: MotionPresentation,
        mutate: () -> Void,
        sampleFor duration: TimeInterval
    ) -> (before: HostedPixels, after: HostedPixels, frames: [HostedPixels]) {
        let window = HostedWindow(
            root(presentation).environment(\.coreMotionPresentationOverride, presentation),
            size: Self.size,
            scheme: .light
        )
        defer { window.close() }
        let before = window.pixels()
        mutate()
        var frames: [HostedPixels] = []
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.008))
            frames.append(window.pixels())
        }
        window.settle()
        return (before, window.pixels(), frames)
    }

    // RM 关的对照组：负载下可能一帧中间态都拍不到，逐次放宽窗口在新窗口里重试；
    // 始终拍不到时判「无法下结论」而不是放行（#407 同款约定）。
    static func observeTransient(_ name: String, measure: (TimeInterval) -> Int) {
        var counts: [Int] = []
        for window in Self.samplingWindows {
            let count = measure(window)
            counts.append(count)
            if count > 0 { return }
        }
        Issue.record("""
        \(name)：采样器在 \(Self.samplingWindows.count) 次尝试（窗口 \(Self.samplingWindows) s，每次新窗口）里 \
        都没拍到 RM 关时的中间帧（逐次 \(counts)）—— sampler could not observe motion，判据无法下结论（inconclusive），不是通过
        """)
    }

    @Test("TagInput 删中间 chip：RM 关有中间帧，RM 开每一帧都等于起点或终点")
    func tagInputRemovalHasNoTransientFrameWhenResting() {
        let box = TagsBox()
        let resting = Self.sample(
            { _ in TagInputHarness(box: box) },
            presentation: .resting,
            mutate: { box.tags = TagInput.removingTag(at: 1, from: box.tags) },
            sampleFor: 0.4
        )
        #expect(Self.differs(resting.before, resting.after, threshold: 16), "chip 没删掉，判据无效")
        #expect(
            Self.transientFrames(resting.frames, before: resting.before, after: resting.after) == 0,
            "RM 开时增删仍在补间：拍到 \(Self.transientFrames(resting.frames, before: resting.before, after: resting.after)) 个中间帧"
        )
        Self.observeTransient("TagInput 删中间 chip") { window in
            let animatedBox = TagsBox()
            let animated = Self.sample(
                { _ in TagInputHarness(box: animatedBox) },
                presentation: .animated,
                mutate: { animatedBox.tags = TagInput.removingTag(at: 1, from: animatedBox.tags) },
                sampleFor: window
            )
            guard Self.differs(animated.before, animated.after, threshold: 16) else { return 0 }
            return Self.transientFrames(animated.frames, before: animated.before, after: animated.after)
        }
    }

    @Test("TagGroup 增删：RM 关有中间帧，RM 开每一帧都等于起点或终点")
    func tagGroupInsertionHasNoTransientFrameWhenResting() {
        let box = GroupBox()
        let resting = Self.sample(
            { _ in TagGroupHarness(box: box) },
            presentation: .resting,
            mutate: { box.items.append(GroupItem(id: "delta")) },
            sampleFor: 0.4
        )
        #expect(Self.differs(resting.before, resting.after, threshold: 16), "标签没加上，判据无效")
        #expect(
            Self.transientFrames(resting.frames, before: resting.before, after: resting.after) == 0,
            "RM 开时增删仍在补间：拍到 \(Self.transientFrames(resting.frames, before: resting.before, after: resting.after)) 个中间帧"
        )
        Self.observeTransient("TagGroup 插入标签") { window in
            let animatedBox = GroupBox()
            let animated = Self.sample(
                { _ in TagGroupHarness(box: animatedBox) },
                presentation: .animated,
                mutate: { animatedBox.items.append(GroupItem(id: "delta")) },
                sampleFor: window
            )
            guard Self.differs(animated.before, animated.after, threshold: 16) else { return 0 }
            return Self.transientFrames(animated.frames, before: animated.before, after: animated.after)
        }
    }

    @Test("TagGroup 选中切换：两种呈现都在补间，且变化像素不越出最终变化区（无几何位移）")
    func tagGroupSelectionInterpolatesWithoutGeometryChange() throws {
        for presentation in [MotionPresentation.animated, .resting] {
            var transient = 0
            var offending: [CGRect] = []
            var finalBounds: CGRect?
            for window in Self.samplingWindows {
                let toggled = GroupBox()
                let run = Self.sample(
                    { _ in TagGroupHarness(box: toggled) },
                    presentation: presentation,
                    mutate: { toggled.selection = ["bravo"] },
                    sampleFor: window
                )
                #expect(Self.differs(run.before, run.after, threshold: 16), "\(presentation)：选中态没切过去，判据无效")
                let bounds = try #require(Self.changedBounds(run.after, run.before), "\(presentation)：最终没有任何像素变化")
                finalBounds = bounds
                let allowed = bounds.insetBy(dx: -2, dy: -2)
                for frame in run.frames {
                    guard Self.differs(frame, run.before, threshold: 16), Self.differs(frame, run.after, threshold: 16) else { continue }
                    transient += 1
                    if let frameBounds = Self.changedBounds(frame, run.before), !allowed.contains(frameBounds) {
                        offending.append(frameBounds)
                    }
                }
                if transient > 0 { break }
            }
            #expect(transient > 0, "\(presentation)：选中切换一帧中间态都没拍到（最终变化区 \(String(describing: finalBounds))）—— 色插值没生效或采样器失灵")
            #expect(offending.isEmpty, "\(presentation)：中间帧的变化像素越出了最终变化区 \(String(describing: finalBounds))：\(offending)")
        }
    }
}


// MARK: - 逐项重排轨迹 / Per-item reflow trajectory

// 每个标签的 label 是一块**唯一色相**的色卡（`Tag` 的 `foregroundStyle` 管不到 `Color` 视图），
// 于是逐帧能按色相把每一项单独定位——行带像素数与整体边界做不到这件事：退场项自己的缩放 / 淡出
// 也在改那些数。
fileprivate struct SwatchItem: Identifiable, Hashable {
    let id: String
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(.sRGB, red: self.red, green: self.green, blue: self.blue, opacity: 1) }
}

fileprivate let reflowSwatches: [SwatchItem] = [
    SwatchItem(id: "red", red: 1, green: 0, blue: 0),
    SwatchItem(id: "green", red: 0, green: 0.7, blue: 0),
    SwatchItem(id: "blue", red: 0, green: 0, blue: 1),
    SwatchItem(id: "yellow", red: 1, green: 0.85, blue: 0),
    SwatchItem(id: "magenta", red: 1, green: 0, blue: 1),
    SwatchItem(id: "cyan", red: 0, green: 0.8, blue: 0.8),
]

@MainActor
private final class SwatchBox: ObservableObject {
    @Published var items: [SwatchItem] = reflowSwatches
}

private struct SwatchHarness: View {
    @ObservedObject var box: SwatchBox

    var body: some View {
        TagGroup(self.box.items, selection: .constant([]), color: .contentSecondary) { item in
            item.color.frame(width: 26, height: 10)
        }
        .frame(width: 240, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

@Suite("标签增删：逐项重排轨迹", .serialized)
@MainActor
struct TagReflowTrajectoryTests {
    static let size = CGSize(width: 240, height: 140)

    static let removedIndex = 1

    static let samplingWindows: [TimeInterval] = [0.45, 0.7, 1.0]

    fileprivate static func origin(of item: SwatchItem, in pixels: HostedPixels) -> CGPoint? {
        guard let bytes = pixels.bytes, pixels.width > 0 else { return nil }
        let tr = Int(item.red * 255), tg = Int(item.green * 255), tb = Int(item.blue * 255)
        var minX = pixels.width, minY = pixels.height, count = 0
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let delta = abs(Int(bytes[index]) - tr) + abs(Int(bytes[index + 1]) - tg) + abs(Int(bytes[index + 2]) - tb)
            guard delta < 60 else { continue }
            count += 1
            let pixel = index / 4
            minX = min(minX, pixel % pixels.width)
            minY = min(minY, pixel / pixels.width)
        }
        return count < 40 ? nil : CGPoint(x: minX, y: minY)
    }

    // 退场项用「色相方向」而不是精确色值计数：它一边淡出一边缩放，精确色值在第一帧就落出容差，
    // 那样会把整段退场读成「一步到位」。
    static func exitingInk(_ pixels: HostedPixels) -> Int {
        guard let bytes = pixels.bytes else { return -1 }
        var count = 0
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let red = Int(bytes[index]), green = Int(bytes[index + 1]), blue = Int(bytes[index + 2])
            if green - max(red, blue) > 12 { count += 1 }
        }
        return count
    }

    struct Run {
        var origins: [String: [CGPoint?]] = [:]
        var exitingInk: [Int] = []
    }

    static func sample(presentation: MotionPresentation, sampleFor duration: TimeInterval) -> Run {
        let box = SwatchBox()
        let window = HostedWindow(
            SwatchHarness(box: box).environment(\.coreMotionPresentationOverride, presentation),
            size: Self.size, scheme: .light
        )
        defer { window.close() }
        var run = Run()
        func record(_ pixels: HostedPixels) {
            for item in reflowSwatches {
                run.origins[item.id, default: []].append(Self.origin(of: item, in: pixels))
            }
            run.exitingInk.append(Self.exitingInk(pixels))
        }
        record(window.pixels())
        box.items.remove(at: Self.removedIndex)
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            RunLoop.main.run(until: Date().addingTimeInterval(0.016))
            record(window.pixels())
        }
        window.settle()
        record(window.pixels())
        return run
    }

    static func intermediates(_ series: [CGPoint?]) -> Int {
        guard let first = series.first ?? nil, let last = series.last ?? nil else { return -1 }
        guard first != last else { return 0 }
        return Set(series.compactMap { point -> String? in
            guard let point, point != first, point != last else { return nil }
            return "\(Int(point.x)),\(Int(point.y))"
        })
        .count
    }

    @Test("完整动效：每个存活标签逐帧经过多个中间位置，跨行上移的那个 x 与 y 一起插值")
    func survivorsMoveThroughIntermediatePositions() throws {
        var lastRun: Run?
        for window in Self.samplingWindows {
            let run = Self.sample(presentation: .animated, sampleFor: window)
            lastRun = run
            let movers = reflowSwatches.filter { $0.id != reflowSwatches[Self.removedIndex].id }
                .filter { Self.intermediates(run.origins[$0.id] ?? []) > 0 }
            if movers.count >= 3 { break }
        }
        let run = try #require(lastRun)
        let survivors = reflowSwatches.filter { $0.id != reflowSwatches[Self.removedIndex].id }
        var movers: [String] = []
        for item in survivors {
            let series = try #require(run.origins[item.id], "\(item.id) 没被采到")
            let first = try #require(series.first ?? nil, "\(item.id) 起点没渲染出来，判据无效")
            let last = try #require(series.last ?? nil, "\(item.id) 终点没渲染出来，判据无效")
            guard hypot(last.x - first.x, last.y - first.y) >= 8 else { continue }
            movers.append(item.id)
            #expect(
                Self.intermediates(series) >= 2,
                """
                \(item.id) 从 \(first) 到 \(last) 只被拍到 \(Self.intermediates(series)) 个中间位置 \
                —— 它是跳过去的，不是移过去的（或采样器失灵）
                """
            )
        }
        #expect(movers.count >= 3, "只有 \(movers) 动过 —— 样本没有构造出重排，判据无效")

        let crossRow = try #require(run.origins["cyan"], "cyan 没被采到")
        let crossFirst = try #require(crossRow.first ?? nil)
        let crossLast = try #require(crossRow.last ?? nil)
        #expect(crossFirst.y > crossLast.y + 8, "cyan 没有跨行上移（\(crossFirst) → \(crossLast)），跨行那一格没被覆盖")
        #expect(crossFirst.x < crossLast.x - 8, "cyan 的 x 没有同时右移（\(crossFirst) → \(crossLast)）")
        let diagonal = Set(crossRow.compactMap { point -> String? in
            guard let point, point != crossFirst, point != crossLast,
                  point.x != crossFirst.x, point.y != crossFirst.y else { return nil }
            return "\(Int(point.x)),\(Int(point.y))"
        })
        #expect(diagonal.count >= 2, "cyan 的 x 与 y 没有同时插值，只拍到 \(diagonal) —— 跨行是跳过去的")

        let exiting = run.exitingInk
        let peak = try #require(exiting.first)
        #expect(peak > 100, "退场项起始墨迹只有 \(peak)，判据无效")
        #expect(exiting.last == 0, "退场项最后还剩 \(String(describing: exiting.last)) 墨迹 —— 没退完")
        #expect(
            exiting.contains { $0 > 0 && $0 < peak },
            "退场项的墨迹从 \(peak) 直接到 0，中间一档都没拍到 —— 退场是瞬间的，或采样器失灵（实测序列 \(exiting)）"
        )
    }

    @Test("Reduce Motion：第一帧起每个标签就在终位，退场墨迹直接归零（零中间位置）")
    func restingHasNoIntermediatePositions() throws {
        let run = Self.sample(presentation: .resting, sampleFor: 0.45)
        let survivors = reflowSwatches.filter { $0.id != reflowSwatches[Self.removedIndex].id }
        var moved = 0
        for item in survivors {
            let series = try #require(run.origins[item.id], "\(item.id) 没被采到")
            let first = try #require(series.first ?? nil, "\(item.id) 起点没渲染出来")
            let last = try #require(series.last ?? nil, "\(item.id) 终点没渲染出来")
            if hypot(last.x - first.x, last.y - first.y) >= 8 { moved += 1 }
            #expect(
                Self.intermediates(series) == 0,
                "\(item.id) 在 Reduce Motion 下仍经过中间位置（\(Self.intermediates(series)) 个）：\(series.compactMap { $0 })"
            )
        }
        #expect(moved >= 3, "只有 \(moved) 个标签换了位置 —— 样本没有构造出重排，判据无效")
        let exiting = run.exitingInk
        let peak = try #require(exiting.first)
        #expect(peak > 100, "退场项起始墨迹只有 \(peak)，判据无效")
        #expect(
            !exiting.dropFirst().contains { $0 > 0 && $0 < peak },
            "Reduce Motion 下退场项仍在淡出（实测序列 \(exiting)）"
        )
    }
}

#endif
