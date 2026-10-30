import SwiftUI

/// 几何层输出物理坐标；SDK 27 的渐变会随 RTL 镜像，传入前还原为逻辑坐标。
struct SlideToConfirmShimmerLabel<Label: View>: View {
    let label: Label
    let bandCenter: CGFloat?
    @Environment(\.layoutDirection) private var layoutDirection

    private var gradientCenter: CGFloat? {
        if #available(iOS 27, macOS 27, *), self.layoutDirection == .rightToLeft {
            return self.bandCenter.map { 1 - $0 }
        }
        return self.bandCenter
    }

    var body: some View {
        self.label.foregroundStyle(SlideToConfirmShimmer.style(bandCenter: self.gradientCenter))
    }
}
