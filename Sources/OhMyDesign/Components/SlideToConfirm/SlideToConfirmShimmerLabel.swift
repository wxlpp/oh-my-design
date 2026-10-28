import SwiftUI

/// 几何层已将流光中心换算成物理坐标；只固定渐变方向，保留标签本身的 RTL 排版。
struct SlideToConfirmShimmerLabel<Label: View>: View {
    let label: Label
    let bandCenter: CGFloat?

    var body: some View {
        self.label
            .foregroundStyle(Color.contentSecondary)
            .overlay {
                SlideToConfirmShimmer.style(bandCenter: self.bandCenter)
                    .environment(\.layoutDirection, .leftToRight)
                    .mask(self.label)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
