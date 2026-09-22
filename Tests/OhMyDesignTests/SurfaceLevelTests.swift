import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - surface 有效层级（Issue #382 / FR-12、FR-13）

@Suite("surface 有效层级规则")
struct SurfaceLevelRuleTests {
    private static let parents: [SurfaceLevel] = [.base, .raised, .elevated]

    @Test("canvas / canvasSubtle 在任何父层级下都重置为 base")
    func canvasKindsResetToBase() {
        for kind in [SurfaceKind.canvas, .canvasSubtle] {
            for parent in Self.parents {
                #expect(kind.level(inheriting: parent) == .base, "\(kind) 在父层级 \(parent) 下未重置为 base")
            }
        }
    }

    @Test("content / grouped / card 为父层级 + 1，封顶 elevated")
    func contentKindsStepUpAndCap() {
        for kind in [SurfaceKind.content, .grouped, .card] {
            #expect(kind.level(inheriting: .base) == .raised)
            #expect(kind.level(inheriting: .raised) == .elevated)
            #expect(kind.level(inheriting: .elevated) == .elevated)
        }
    }

    @Test("panel / sidebar / control / floating 不改层级")
    func passThroughKindsKeepParentLevel() {
        for kind in [SurfaceKind.panel, .sidebar, .control, .floating] {
            for parent in Self.parents {
                #expect(kind.level(inheriting: parent) == parent, "\(kind) 改动了父层级 \(parent)")
            }
        }
    }

    @Test("只有 content / grouped / card 的背景随层级变：raised → surfaceCard，elevated → surfaceElevated")
    func onlyContentKindsBackgroundFollowsLevel() {
        for kind in [SurfaceKind.content, .grouped, .card] {
            #expect(kind.background(at: .raised) == Color.surfaceCard, "\(kind) raised 背景不是 surfaceCard")
            #expect(kind.background(at: .elevated) == Color.surfaceElevated, "\(kind) elevated 背景不是 surfaceElevated")
        }
        let fixed: [(SurfaceKind, Color)] = [
            (.canvas, .surfaceCanvas), (.canvasSubtle, .surfaceCanvasSubtle),
            (.panel, .surfacePanel), (.sidebar, .surfaceSidebar),
            (.control, .surfaceInteractive), (.floating, .surfaceOverlay),
        ]
        for scheme in [ColorScheme.light, .dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            for (kind, token) in fixed {
                for parent in Self.parents {
                    let level = kind.level(inheriting: parent)
                    #expect(
                        kind.background(at: level).resolve(in: e) == token.resolve(in: e),
                        "\(scheme)：\(kind) 在父层级 \(parent) 下背景偏离了现值"
                    )
                }
            }
        }
    }

    @Test("描边与圆角仍只由角色决定：grouped 无描边")
    func borderStaysRoleDriven() {
        #expect(SurfaceKind.grouped.border == Color.clear)
        #expect(SurfaceKind.content.border == Color.borderMuted)
        #expect(SurfaceKind.card.border == Color.borderMuted)
    }
}

// MARK: - 环境传递（经 ImageRenderer 求值 body）

@Suite("surface 有效层级的环境传递")
@MainActor
struct SurfaceLevelPropagationTests {
    private final class Box {
        var level: SurfaceLevel?
    }

    private struct Probe: View {
        let box: Box
        @Environment(\.surfaceLevel) private var level

        var body: some View {
            self.box.level = self.level
            return Color.clear.frame(width: 4, height: 4)
        }
    }

    private func level(of build: (Probe) -> some View) -> SurfaceLevel? {
        let box = Box()
        let renderer = ImageRenderer(content: build(Probe(box: box)))
        renderer.scale = 1
        _ = renderer.cgImage
        return box.level
    }

    @Test("默认层级为 base")
    func defaultIsBase() {
        #expect(self.level { $0 } == .base)
    }

    @Test("单层 content → raised；双层 → elevated；三层封顶 elevated")
    func nestingStepsUp() {
        #expect(self.level { $0.surface(.content) } == .raised)
        #expect(self.level { $0.surface(.content).surface(.content) } == .elevated)
        #expect(self.level { $0.surface(.card).surface(.grouped).surface(.content) } == .elevated)
    }

    @Test("canvas 重置，panel / floating 透传")
    func resetAndPassThrough() {
        #expect(self.level { $0.surface(.canvas).surface(.content) } == .base)
        #expect(self.level { $0.surface(.content).surface(.canvas).surface(.content) } == .raised)
        #expect(self.level { $0.surface(.panel).surface(.content) } == .raised)
        #expect(self.level { $0.surface(.floating).surface(.content).surface(.content) } == .elevated)
    }

    @Test(".surface(.content) 内的 Card 处在 elevated")
    func cardInsideContentIsElevated() {
        #expect(self.level { probe in Card { probe }.surface(.content) } == .elevated)
        #expect(self.level { probe in Card(kind: .grouped) { probe } } == .raised)
    }

    @Test("coreSheetPresentation 两种背景都把内容层级设为 raised，且覆盖宿主层级")
    func sheetContentIsRaised() {
        for background in [CoreSheetBackground.system, .raised] {
            #expect(self.level { $0.coreSheetPresentation(background: background) } == .raised)
            #expect(self.level { probe in Card { probe }.coreSheetPresentation(background: background) } == .elevated)
            #expect(self.level { $0.coreSheetPresentation(background: background).surface(.content).surface(.content) } == .raised)
        }
    }

    @Test("兄弟隔离：一个子视图的 surface 不影响相邻兄弟")
    func siblingsAreIsolated() {
        #expect(self.level { probe in
            VStack {
                Color.clear.frame(width: 4, height: 4).surface(.content).surface(.content)
                probe
            }
        } == .base)
        #expect(self.level { probe in
            VStack {
                Color.clear.frame(width: 4, height: 4).surface(.content)
                probe
            }
            .surface(.content)
        } == .raised)
    }

    @Test("overlay / background 的作用域：挂在 surface 外侧的读父层级，挂在内侧的读本层")
    func overlayScope() {
        #expect(self.level { probe in Color.clear.frame(width: 4, height: 4).surface(.content).overlay(probe) } == .base)
        #expect(self.level { probe in Color.clear.frame(width: 4, height: 4).overlay(probe).surface(.content) } == .raised)
        #expect(self.level { probe in Color.clear.frame(width: 4, height: 4).surface(.content).background(probe) } == .base)
    }
}

// MARK: - Card 投影随层级收起

@Suite("Card 在 elevated 层级不出投影")
struct CardElevationByLevelTests {
    private static let requested: [CoreElevation.Level] = [.none, .small, .medium, .large]

    @Test("顶层（父层级 base）与 canvas 之下：按传入档位出投影")
    func topLevelKeepsRequestedElevation() {
        for kind in [CardKind.content, .grouped] {
            for level in Self.requested {
                #expect(Card<EmptyView>.resolvedElevation(level, kind: kind, parent: .base) == level)
            }
        }
    }

    @Test("父层级 raised / elevated（Card 自身为 elevated）：任何档位都收成 .none")
    func elevatedCardHasNoShadow() {
        for kind in [CardKind.content, .grouped] {
            for parent in [SurfaceLevel.raised, .elevated] {
                for level in Self.requested {
                    #expect(Card<EmptyView>.resolvedElevation(level, kind: kind, parent: parent) == CoreElevation.Level.none,
                            "\(kind) 在父层级 \(parent) 下仍出投影 \(level)")
                }
            }
        }
    }
}

#if os(iOS)
import UIKit

// MARK: - iOS 腿：嵌套取色可见

@Suite("surface 嵌套取色（iOS 腿）")
@MainActor
struct SurfaceLevelRenderTests {
    private func centerPixel(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let ok = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(
                x: -CGFloat(cg.width) / 2 + 0.5, y: -CGFloat(cg.height) / 2 + 0.5,
                width: CGFloat(cg.width), height: CGFloat(cg.height)
            ))
            return true
        }
        return ok ? pixel : nil
    }

    @Test("surfaceElevated 与 surfaceCard 两种外观下解析互异（嵌套可辨的前提）")
    func elevatedDiffersFromRaised() {
        for scheme in [ColorScheme.light, .dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            #expect(Color.surfaceElevated.resolve(in: e) != Color.surfaceCard.resolve(in: e), "\(scheme)")
        }
    }

    @Test("嵌套 Card 的中心像素取 surfaceElevated，且与外层 Card 不同")
    func nestedCardRendersElevated() {
        for scheme in [ColorScheme.light, .dark] {
            let inner = Card(padding: 0, elevation: .none) { Color.clear.frame(width: 40, height: 40) }
            let nested = Card(padding: 20, elevation: .none) { inner }
            let outer = Card(padding: 0, elevation: .none) { Color.clear.frame(width: 80, height: 80) }
            let elevated = Color.surfaceElevated.frame(width: 80, height: 80)

            let nestedPixel = self.centerPixel(nested, scheme: scheme)
            let elevatedPixel = self.centerPixel(elevated, scheme: scheme)
            let outerPixel = self.centerPixel(outer, scheme: scheme)
            expectBitmapsEqual(nestedPixel, elevatedPixel, "\(scheme)：嵌套 Card 未取 surfaceElevated")
            expectBitmapsDiffer(nestedPixel, outerPixel, "\(scheme)：嵌套 Card 与外层 Card 同色")
        }
    }

    private func pixel(_ view: some View, x: Int, y: Int, scheme: ColorScheme) -> [UInt8]? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage, x < cg.width, y < cg.height else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let ok = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(
                x: -CGFloat(x), y: -CGFloat(cg.height - 1 - y),
                width: CGFloat(cg.width), height: CGFloat(cg.height)
            ))
            return true
        }
        return ok ? pixel : nil
    }

    @Test("嵌套 Card 传 .large 也不出投影：内卡下缘外侧的像素与无内卡时相同")
    func nestedCardDrawsNoShadow() {
        for scheme in [ColorScheme.light, .dark] {
            let nested = Card(padding: 30, elevation: .none) {
                Card(padding: 0, elevation: .large) { Color.clear.frame(width: 40, height: 40) }
            }
            let bare = Card(padding: 30, elevation: .none) { Color.clear.frame(width: 40, height: 40) }
            expectBitmapsEqual(
                self.pixel(nested, x: 50, y: 76, scheme: scheme),
                self.pixel(bare, x: 50, y: 76, scheme: scheme),
                "\(scheme)：嵌套 Card 仍画出了投影"
            )
        }
    }

    @Test("对照：顶层 Card 传 .large 会画出投影（上一条判据有效的前提）")
    func topLevelCardDrawsShadow() {
        let shadowed = Card(padding: 0, elevation: .large) { Color.clear.frame(width: 40, height: 40) }
            .padding(30)
            .background(Color.surfaceCanvas)
        let flat = Card(padding: 0, elevation: .none) { Color.clear.frame(width: 40, height: 40) }
            .padding(30)
            .background(Color.surfaceCanvas)
        expectBitmapsDiffer(
            self.pixel(shadowed, x: 50, y: 76, scheme: .light),
            self.pixel(flat, x: 50, y: 76, scheme: .light),
            "light：顶层 Card 的 .large 投影在采样点不可见——采样点需调整"
        )
    }
}

// MARK: - iOS 腿：普通 .sheet 继承宿主层级（已知限制）

@Suite("普通 sheet 的层级继承（iOS 腿）", .serialized)
@MainActor
struct PresentedSheetLevelTests {
    private final class Box {
        var level: SurfaceLevel?
    }

    private struct Probe: View {
        let box: Box
        @Environment(\.surfaceLevel) private var level

        var body: some View {
            self.box.level = self.level
            return Color.clear.frame(width: 4, height: 4)
        }
    }

    private enum Presentation {
        case sheet
        case popover
    }

    private struct PresentingHost: View {
        let presentation: Presentation
        let content: () -> AnyView
        @State private var isPresented = false

        var body: some View {
            let anchor = Color.clear.frame(width: 100, height: 100)
                .onAppear { self.isPresented = true }
            switch self.presentation {
            case .sheet: anchor.sheet(isPresented: self.$isPresented) { self.content() }
            case .popover: anchor.popover(isPresented: self.$isPresented) { self.content() }
            }
        }
    }

    private func presentedLevel(
        _ presentation: Presentation = .sheet,
        _ decorate: @escaping (Probe) -> AnyView
    ) async -> SurfaceLevel? {
        let box = Box()
        for _ in 0..<6 where box.level == nil {
            let host = PresentingHost(presentation: presentation) { decorate(Probe(box: box)) }
                .surface(.content)
                .surface(.content)
            let window: UIWindow
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                window = UIWindow(windowScene: scene)
            } else {
                window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            }
            window.rootViewController = UIHostingController(rootView: host)
            window.makeKeyAndVisible()
            for _ in 0..<100 where box.level == nil {
                window.rootViewController?.presentedViewController?.view.layoutIfNeeded()
                try? await Task.sleep(for: .milliseconds(100))
            }
            window.rootViewController?.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
        return box.level
    }

    @Test("普通 .sheet 的内容继承宿主层级（elevated）")
    func plainSheetInheritsHostLevel() async {
        let plain = await self.presentedLevel { AnyView($0) }
        #expect(plain == .elevated, "普通 sheet 内容读到的层级：\(String(describing: plain))（nil = sheet 未呈现）")
    }

    @Test("coreSheetPresentation 把弹出的 sheet 内容重设为 raised")
    func presetSheetResetsToRaised() async {
        let preset = await self.presentedLevel { AnyView($0.coreSheetPresentation()) }
        #expect(preset == .raised, "coreSheetPresentation 内容读到的层级：\(String(describing: preset))（nil = sheet 未呈现）")
    }

    @Test("普通 .popover 的内容同样继承宿主层级（elevated）")
    func plainPopoverInheritsHostLevel() async {
        let popover = await self.presentedLevel(.popover) { AnyView($0) }
        #expect(popover == .elevated, "popover 内容读到的层级：\(String(describing: popover))（nil = popover 未呈现）")
    }
}
#endif
