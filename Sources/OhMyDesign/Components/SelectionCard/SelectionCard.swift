import SwiftUI

// MARK: - SelectionCard

/// 带说明内容槽的单选卡片，选择状态由调用方绑定持有。
public struct SelectionCard<Value: Equatable, Label: View>: View {
    private let value: Value
    @Binding private var selection: Value
    private let label: Label
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.coreAccent) private var resolvedAccent
    @Environment(\.colorSchemeContrast) private var contrast

    /// - Parameters:
    ///   - value: 本卡片代表的值。
    ///   - selection: 共享的当前选择；重复选择当前项不清空。
    ///   - label: 图标、标题和说明内容，不应包含嵌套交互控件。
    public init(value: Value, selection: Binding<Value>, @ViewBuilder label: () -> Label) {
        self.value = value
        _selection = selection
        self.label = label()
    }

    public var body: some View {
        let selected = selection == value
        let shape = RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
        Button {
            SelectionCardAction.select(self.value, selection: self.$selection, isEnabled: self.isEnabled)
        } label: {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.contentPrimary)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                }
                self.label
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.contentPrimary)
            .padding(CoreSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background {
                shape.fill(Color.surfaceRaised)
                    .overlay {
                        shape.fill(selected ? self.resolvedAccent.opacity(0.10) : Color.clear)
                    }
            }
            .overlay {
                shape.strokeBorder(
                    selected ? self.resolvedAccent : Color.borderSubtle,
                    lineWidth: selected || self.contrast == .increased ? 2 : CoreBorderWidth.hairline
                )
                .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
        .buttonStyle(.pressableCard)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .coreAnimation(.selection, value: selected)
    }
}

// MARK: - Selection action

enum SelectionCardAction {
    static func select<Value: Equatable>(_ value: Value, selection: Binding<Value>, isEnabled: Bool) {
        guard isEnabled, selection.wrappedValue != value else { return }
        selection.wrappedValue = value
    }
}

#Preview {
    @Previewable @State var selection = "focus"
    SelectionCard(value: "focus", selection: $selection) {
        VStack(alignment: .leading) {
            Label("专注", systemImage: "circle.lefthalf.filled")
            Text("留白更多，让思路安静").font(.caption)
        }
    }
    .padding()
}
