import SwiftUI
@testable import OhMyDesign
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - SearchField 改动前原样拷贝（4c858c2）/ Pre-fix copy

struct PreFixSearchField: View {
    init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSubmit: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        PreFixNativeSearchField(
            text: self.$text,
            placeholder: self.placeholder,
            onSubmit: self.onSubmit,
            focusRequests: self.focusRequests
        )
        .fieldAccessibility()
        .frame(maxWidth: .infinity)
        .overlay {
            if FieldAppearance.resolve(isEnabled: self.isEnabled, validation: self.validation, isFocused: false) == .invalid {
                Capsule()
                    .strokeBorder(Color.statusDangerForeground, lineWidth: CoreBorderWidth.thin)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .onTapGesture { self.focusRequests += 1 }
    }

    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: ((String) -> Void)?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fieldValidation) private var validation

    @State private var focusRequests: Int = 0
}

#if canImport(UIKit)
struct PreFixNativeSearchField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: ((String) -> Void)?
    let focusRequests: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.returnKeyType = .search
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = self.placeholder
        field.accessibilityLabel = self.placeholder.isEmpty
            ? String(localized: "Search", bundle: .module)
            : nil
        if field.text != self.text {
            field.text = self.text
        }
        if context.coordinator.lastFocusRequest != self.focusRequests {
            context.coordinator.lastFocusRequest = self.focusRequests
            if self.focusRequests > 0, !field.isFirstResponder {
                field.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PreFixNativeSearchField
        var lastFocusRequest: Int = 0

        init(_ parent: PreFixNativeSearchField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            self.parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            self.parent.onSubmit?(field.text ?? "")
            return true
        }
    }
}
#else
struct PreFixNativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: ((String) -> Void)?
    let focusRequests: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.controlSize = .large
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = self.placeholder
        field.setAccessibilityLabel(
            self.placeholder.isEmpty ? String(localized: "Search", bundle: .module) : nil
        )
        if field.stringValue != self.text {
            field.stringValue = self.text
        }
        if context.coordinator.lastFocusRequest != self.focusRequests {
            context.coordinator.lastFocusRequest = self.focusRequests
            if self.focusRequests > 0 {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: PreFixNativeSearchField
        var lastFocusRequest: Int = 0

        init(_ parent: PreFixNativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            self.parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            self.parent.onSubmit?(control.stringValue)
            return true
        }
    }
}
#endif
