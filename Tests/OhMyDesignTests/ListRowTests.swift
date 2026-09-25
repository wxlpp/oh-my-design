import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("ListRow")
struct ListRowTests {
    @MainActor
    @Test("list row constructs with label only")
    func listRowConstructsWithLabelOnly() {
        let row = ListRow(label: { Text("Item") })
        #expect(type(of: row) == ListRow<EmptyView, EmptyView, Text>.self)
    }

    @MainActor
    @Test("list row constructs with leading and trailing")
    func listRowConstructsWithLeadingAndTrailing() {
        let row = ListRow(
            leading: { Image(systemName: "doc") },
            label: { Text("Item") },
            trailing: { Circle() }
        )
        #expect(type(of: row) == ListRow<Image, Circle, Text>.self)
    }

    // 回归钉：阈值 4 沿用 Tree `.navigator` 的 minimumHoverDelta；#435 实测修后最小差 6（macOS 暗）、修前 0。
    @MainActor
    @Test("悬停底色与未悬停逐通道差 > 4（light / dark，两条腿）", arguments: [ColorScheme.light, .dark])
    func hoverIsVisible(_ scheme: ColorScheme) {
        func sample(_ isHovered: Bool) -> (Int, Int, Int)? {
            let pixels = TreePixels.render(
                Text("Row").frame(maxWidth: .infinity, minHeight: 44).modifier(ListRowSurface(isHovered: isHovered)),
                scheme: scheme
            )
            return pixels.rgb(x: 8, y: pixels.height / 2)
        }
        guard let idle = sample(false), let hovered = sample(true) else {
            Issue.record("\(scheme)：没渲染出来")
            return
        }
        let delta = max(abs(idle.0 - hovered.0), abs(idle.1 - hovered.1), abs(idle.2 - hovered.2))
        #expect(delta > 4, "\(scheme)：悬停 \(hovered) 与未悬停 \(idle) 逐通道最大差 \(delta) ≤ 4，悬停看不见")
    }

    @Test("ListRow.body 经 ListRowSurface 接上悬停态：源码逐字含该调用且只出现一次")
    func bodyWiresHoverThroughListRowSurface() throws {
        let url = GuardScanRoots.repoRoot.appendingPathComponent("Sources/OhMyDesign/Components/ListRow/ListRow.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let call = ".modifier(ListRowSurface(isHovered: self.isHovered))"
        let count = source.components(separatedBy: call).count - 1
        #expect(count == 1, "ListRow.swift 里 `\(call)` 出现 \(count) 次——悬停判据测的是 ListRowSurface，本体没接上它时那条判据照绿")
    }
}
