import SwiftUI

// MARK: - CoreSheetBackground

/// `coreSheetPresentation(background:)` 的 sheet 背景取值 / Sheet background of the preset.
public nonisolated enum CoreSheetBackground: Sendable, Equatable {
    /// 保留系统 sheet 背景（iOS 26 为 Liquid Glass）。
    case system
    /// 不透明 `Color.surfaceRaised`。
    case raised
}

// MARK: - CoreSheetBackgroundModifier

struct CoreSheetBackgroundModifier: ViewModifier {
    let background: CoreSheetBackground

    @ViewBuilder
    func body(content: Content) -> some View {
        switch self.background {
        case .system: content
        case .raised: content.presentationBackground(Color.surfaceRaised)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// 本库的 sheet 预设：可见拖拽指示条、按 `background` 取背景，并把 sheet 内容的有效层级设为 raised
    /// （内部的 `Card` 因而取 `surfaceElevated`）。圆角交给系统，保持浮动 sheet 与屏幕圆角同心。
    ///
    /// 施加在 sheet 的内容上，而不是呈现 sheet 的宿主上。
    ///
    /// - Parameter background: sheet 背景，缺省 `.system`（系统 Liquid Glass）；`.raised` 为不透明 `surfaceRaised`。
    /// - Returns: 已应用 sheet 预设与层级的视图 / The view with the sheet presentation preset applied.
    func coreSheetPresentation(background: CoreSheetBackground = .system) -> some View {
        self
            .environment(\.surfaceLevel, .raised)
            .presentationDragIndicator(.visible)
            .modifier(CoreSheetBackgroundModifier(background: background))
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
    @State private var background: CoreSheetBackground?

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Button("Sheet（.system）") {
                self.background = .system
            }
            Button("Sheet（.raised）") {
                self.background = .raised
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
        .sheet(
            isPresented: Binding(
                get: { self.background != nil },
                set: { if !$0 { self.background = nil } }
            )
        ) {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                Text("Sheet").coreFont(.headline)
                Card {
                    Text("Sheet 内的 Card：elevated").coreFont(.subheadline)
                }
            }
            .padding(CoreSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .coreSheetPresentation(background: self.background ?? .system)
            .presentationDetents([.medium, .large])
        }
    }
}
