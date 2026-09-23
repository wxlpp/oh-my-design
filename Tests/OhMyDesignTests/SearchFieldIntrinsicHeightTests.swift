import SwiftUI
import Testing
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
private typealias NativeField = UISearchTextField
#else
import AppKit
private typealias NativeField = NSSearchField
#endif

@MainActor
private final class HeightBox {
    var value: CGFloat = -1
}

private extension View {
    func measuringHeight(into box: HeightBox) -> some View {
        self.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { box.value = $0 }
    }
}

@MainActor
private struct SearchFieldLayoutProbe {
    let height: CGFloat
    let nativeFrame: CGRect?
    let pixels: HostedPixels

    init(_ field: some View, scheme: ColorScheme) {
        let box = HeightBox()
        let window = HostedWindow(
            VStack(spacing: 0) { field.measuringHeight(into: box) }.padding(8),
            size: CGSize(width: 360, height: 300),
            scheme: scheme
        )
        defer { window.close() }
        self.height = box.value
        self.nativeFrame = window.first(NativeField.self).map { window.frame(of: $0) }
        self.pixels = window.pixels()
    }
}

@Suite("SearchField 在不限高容器里取固有高度（托管窗口真实渲染，两端都跑）")
@MainActor
struct SearchFieldIntrinsicHeightTests {
    @Test("300pt 高的容器里视图高度等于 44pt 下限，不被纵向拉伸（light / dark）", arguments: [ColorScheme.light, .dark])
    func keepsIntrinsicHeight(_ scheme: ColorScheme) {
        let probe = SearchFieldLayoutProbe(SearchField(text: .constant("release")), scheme: scheme)
        #expect(probe.height == CoreControlMetrics.height(for: .regular), "\(scheme)：实测高度 \(probe.height)pt")
    }

    @Test(
        "不限高容器里与改动前实现外加 fixedSize(vertical) 的原生框位置与位图逐像素相同（light / dark）",
        arguments: [ColorScheme.light, .dark]
    )
    func matchesPreFixWithCallerFixedSize(_ scheme: ColorScheme) {
        let now = SearchFieldLayoutProbe(SearchField(text: .constant("release")), scheme: scheme)
        let old = SearchFieldLayoutProbe(
            PreFixSearchField(text: .constant("release")).fixedSize(horizontal: false, vertical: true),
            scheme: scheme
        )
        #expect(now.nativeFrame != nil && now.nativeFrame == old.nativeFrame, "\(scheme)：\(String(describing: now.nativeFrame)) vs \(String(describing: old.nativeFrame))")
        #expect(now.height == old.height)
        expectBitmapsEquivalent(now.pixels.bytes, old.pixels.bytes, maxChannelDelta: 1, "\(scheme)")
    }

    @Test("调用方显式给高度（frame(height: 60)）时：原生框保持固有高度、居中于 60pt 的框内，不再被撑到 60pt（light）")
    func explicitHeightKeepsNativeIntrinsic() throws {
        let now = SearchFieldLayoutProbe(SearchField(text: .constant("release")).frame(height: 60), scheme: .light)
        let old = SearchFieldLayoutProbe(PreFixSearchField(text: .constant("release")).frame(height: 60), scheme: .light)
        let reference = SearchFieldLayoutProbe(SearchField(text: .constant("release")), scheme: .light)
        let nowFrame = try #require(now.nativeFrame), oldFrame = try #require(old.nativeFrame)
        let intrinsic = try #require(reference.nativeFrame).height
        #expect(now.height == 60 && old.height == 60, "外层框高度应由调用方决定：现 \(now.height) / 旧 \(old.height)")
        #expect(nowFrame.height == intrinsic, "原生框高度 \(nowFrame.height)，固有高度 \(intrinsic)")
        #expect(abs(nowFrame.midY - oldFrame.midY) <= 0.5, "原生框没有居中于调用方的框：\(nowFrame) vs \(oldFrame)")
        #if os(iOS)
        #expect(oldFrame.height == 60, "改动前原生框应被撑到 60pt，实测 \(oldFrame.height)")
        #else
        #expect(oldFrame.height == intrinsic, "macOS 改动前原生框本就不拉伸，实测 \(oldFrame.height)")
        #endif
    }

    #if os(iOS)
    @Test("改动前实现在同一容器里确实被拉伸（本套判据在 iOS 上的前提）")
    func preFixStretches() {
        let old = SearchFieldLayoutProbe(PreFixSearchField(text: .constant("release")), scheme: .light)
        #expect(old.height > CoreControlMetrics.height(for: .regular) * 2, "改动前实测高度 \(old.height)pt")
    }
    #else
    @Test("macOS：改动前实现已取固有高度（NSSearchField 纵向不随提议拉伸），本改动在这一端不改变布局")
    func preFixAlreadyIntrinsicOnMac() {
        let old = SearchFieldLayoutProbe(PreFixSearchField(text: .constant("release")), scheme: .light)
        #expect(old.height == CoreControlMetrics.height(for: .regular), "改动前实测高度 \(old.height)pt")
    }
    #endif
}
