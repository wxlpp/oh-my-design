import SwiftUI

// MARK: - View Extension

public extension View {
    /// 本库的 sheet 外观预设：圆角 `CoreRadius.xLarge`、可见拖拽指示条、`surfaceRaised` 背景，
    /// 并把 sheet 内容的有效层级设为 raised（内部的 `Card` 因而取 `surfaceElevated`）。
    ///
    /// 施加在 sheet 的内容上，而不是呈现 sheet 的宿主上。
    ///
    /// - Returns: 已应用 sheet 外观与层级的视图 / The view with the sheet presentation preset applied.
    func coreSheetPresentation() -> some View {
        self
            .environment(\.surfaceLevel, .raised)
            .presentationCornerRadius(CoreRadius.xLarge)
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.surfaceRaised)
    }
}

// MARK: - Previews

#Preview("coreSheetPresentation — Light") {
    CoreSheetPresentationPreview()
        .preferredColorScheme(.light)
}

#Preview("coreSheetPresentation — Dark") {
    CoreSheetPresentationPreview()
        .preferredColorScheme(.dark)
}

private struct CoreSheetPresentationPreview: View {
    @State private var isPresented = true

    var body: some View {
        Button("Show Sheet") {
            self.isPresented = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
        .sheet(isPresented: self.$isPresented) {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                Text("Sheet").coreFont(.headline)
                Card {
                    Text("Sheet 内的 Card：elevated").coreFont(.subheadline)
                }
            }
            .padding(CoreSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .coreSheetPresentation()
            .presentationDetents([.medium])
        }
    }
}
