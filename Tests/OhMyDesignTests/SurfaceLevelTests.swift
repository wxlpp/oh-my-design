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

    @Test("coreSheetPresentation() 把内容层级设为 raised，sheet 内 Card 为 elevated")
    func sheetContentIsRaised() {
        #expect(self.level { $0.coreSheetPresentation() } == .raised)
        #expect(self.level { probe in Card { probe }.coreSheetPresentation() } == .elevated)
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
}
#endif
