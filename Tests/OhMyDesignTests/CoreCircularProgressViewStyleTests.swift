import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - `.coreCircular`（Issue #381 / FR-10）

private struct RenderedPixels {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    func count(where predicate: (Double, Double, Double, Double) -> Bool) -> Int {
        var total = 0
        for index in stride(from: 0, to: self.rgba.count, by: 4) {
            let r = Double(self.rgba[index])
            let g = Double(self.rgba[index + 1])
            let b = Double(self.rgba[index + 2])
            let a = Double(self.rgba[index + 3])
            if predicate(r, g, b, a) { total += 1 }
        }
        return total
    }
}

@MainActor
private func renderPixels(_ content: some View, size: CGSize) -> RenderedPixels? {
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height).background(Color.white))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return RenderedPixels(width: width, height: height, rgba: pixels)
}

private func isReddish(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Bool {
    a > 128 && r > 150 && r > g + 80 && r > b + 80
}

@Suite("CoreCircularProgressViewStyle")
@MainActor
struct CoreCircularProgressViewStyleTests {
    private let canvas = CGSize(width: 64, height: 64)

    @Test(".progressViewStyle(.coreCircular) 产出 CoreCircularProgressViewStyle")
    func staticMember() {
        let style: CoreCircularProgressViewStyle = .coreCircular
        _ = style
    }

    @Test("圆弧覆盖面随 fractionCompleted 增长")
    func arcGrowsWithFraction() throws {
        let quarter = try #require(renderPixels(
            ProgressView(value: 0.25).progressViewStyle(.coreCircular).tint(.red), size: self.canvas
        ))
        let threeQuarters = try #require(renderPixels(
            ProgressView(value: 0.75).progressViewStyle(.coreCircular).tint(.red), size: self.canvas
        ))
        let quarterRed = quarter.count(where: isReddish)
        let threeQuartersRed = threeQuarters.count(where: isReddish)
        #expect(quarterRed > 0, "0.25 下应画出 tint 色圆弧，实测红像素 \(quarterRed)")
        #expect(threeQuartersRed > quarterRed * 2, "0.75 的圆弧应明显长于 0.25，实测 \(threeQuartersRed) vs \(quarterRed)")
    }

    @Test("零进度不画圆弧，只剩轨道")
    func zeroFractionDrawsNoArc() throws {
        let zero = try #require(renderPixels(
            ProgressView(value: 0).progressViewStyle(.coreCircular).tint(.red), size: self.canvas
        ))
        #expect(zero.count(where: isReddish) == 0)
        #expect(zero.count(where: { r, g, b, _ in r < 250 || g < 250 || b < 250 }) > 0, "轨道应可见")
    }

    @Test("越界进度被钳到 0…1")
    func fractionIsClamped() {
        #expect(CoreCircularProgressViewStyle.clampedFraction(1.7) == 1)
        #expect(CoreCircularProgressViewStyle.clampedFraction(-0.3) == 0)
        #expect(CoreCircularProgressViewStyle.clampedFraction(0.4) == 0.4)
    }

    @Test("不确定态回退系统环形 spinner：与系统 .circular 同样渲染逐像素一致")
    func indeterminateFallsBackToSystem() throws {
        let system = try #require(renderPixels(
            ProgressView().progressViewStyle(.circular).tint(.red), size: self.canvas
        ))
        let systemDrawn = system.count(where: { r, g, b, _ in r < 250 || g < 250 || b < 250 })
        guard systemDrawn > 0 else {
            withKnownIssue("ImageRenderer 在本条腿上画不出系统 spinner，无法用像素证明回退——本条不作数") {
                Issue.record("系统 .circular spinner 渲染为空")
            }
            return
        }
        let fallback = try #require(renderPixels(
            ProgressView().progressViewStyle(.coreCircular).tint(.red), size: self.canvas
        ))
        let determinateZero = try #require(renderPixels(
            ProgressView(value: 0).progressViewStyle(.coreCircular).tint(.red), size: self.canvas
        ))
        expectBitmapsEquivalent(fallback.rgba, system.rgba, maxChannelDelta: 1, "nil 进度应画出系统 spinner 本身")
        expectBitmapsDiffer(fallback.rgba, determinateZero.rgba, "nil 进度不应画确定态的空轨道")
    }
}
