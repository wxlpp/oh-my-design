import SwiftUI
import OhMyDesign
#if canImport(AppKit)
import AppKit
#endif

@main
struct SpikeApp: App {
    @State private var state = SpikeState.shared

    var body: some Scene {
        WindowGroup {
            SpikeRootView()
                .environment(self.state)
                .frame(minWidth: 420, minHeight: 620)
        }
    }
}

struct SpikeRootView: View {
    @Environment(SpikeState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("mode=\(self.state.mode.rawValue) capture=\(self.state.capture.rawValue)")
                .font(.caption.monospaced())
                .accessibilityIdentifier("spike-header")

            Group {
                switch self.state.mode {
                case .probe: ProbePane()
                case .disclosureAuto: DisclosurePane(useCoreStyle: false)
                case .disclosureCore: DisclosurePane(useCoreStyle: true)
                case .listSelection: ListPane()
                case .custom: CustomPane()
                case .disclosureInset: InsetPane()
                case .listInScroll: ListInScrollPane()
                case .listSentinel: ListSentinelPane()
                case .textField: TextFieldPane()
                case .disclosureKeys: DisclosureKeysPane()
                }
            }
            .frame(maxHeight: 300)

            Divider()

            Text("expanded=\(self.state.expanded.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
            Text("selection=\(self.state.selection.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
            Text("listSel=\(self.state.listSelection.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
                .accessibilityIdentifier("spike-listsel")
            Text("focus=\(self.state.focusedID ?? "nil") act=\(self.state.activations.suffix(3).joined(separator: ","))")
                .font(.caption2.monospaced())
                .accessibilityIdentifier("spike-focus")

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(self.state.events.suffix(14).enumerated()), id: \.offset) { pair in
                        Text(pair.element)
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("spike-log")
        }
        .padding(8)
        .onAppear {
            self.state.reportRestoredExpandedOnLaunch()
            #if canImport(AppKit)
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            if ProcessInfo.processInfo.environment["SPIKE_SELFDRIVE"] == "1" {
                MacSelfDrive.start(state: self.state)
            }
            #endif
        }
    }
}

// MARK: - Shared key observer

enum SpikeEnv {
    static let containerFocus: Bool = ProcessInfo.processInfo.environment["SPIKE_CONTAINER_FOCUS"] != "0"
    static let preludeTabs: Int = Int(ProcessInfo.processInfo.environment["SPIKE_PRELUDE_TABS"] ?? "0") ?? 0
    static let listFocusOnly: Bool = ProcessInfo.processInfo.environment["SPIKE_LIST_FOCUS_ONLY"] == "1"
}

private struct KeyObserver: ViewModifier {
    let site: String
    @Environment(SpikeState.self) private var state

    func body(content: Content) -> some View {
        content.onKeyPress(phases: [.down]) { press in
            let forceIgnore = self.site == "sentinel"
                && ProcessInfo.processInfo.environment["SPIKE_SENTINEL_ALWAYS_IGNORE"] == "1"
            let handled = !forceIgnore && self.state.capture == .handled
            self.state.logKey(press, at: self.site, decision: handled ? "handled" : "ignored")
            return handled ? .handled : .ignored
        }
    }
}

private extension View {
    func keyObserver(_ site: String) -> some View {
        self.modifier(KeyObserver(site: site))
    }
}

// MARK: - P: raw delivery probe

struct ProbePane: View {
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            Text(self.focused ? "PROBE FOCUSED" : "probe not focused")
                .accessibilityIdentifier("spike-probe-focus")
            Rectangle()
                .fill(self.focused ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                .frame(height: 80)
        }
        .focusable(SpikeEnv.containerFocus)
        .focused(self.$focused)
        .keyObserver("P-probe")
        .onAppear { if SpikeEnv.containerFocus { self.focused = true } }
    }
}

// MARK: - A: recursive DisclosureGroup

struct DisclosurePane: View {
    let useCoreStyle: Bool

    @Environment(SpikeState.self) private var state
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                DisclosureTreeView(nodes: SpikeTree.roots, level: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(OptionalCoreStyle(enabled: self.useCoreStyle))
        }
        .focusable(SpikeEnv.containerFocus)
        .focused(self.$focused)
        .keyObserver(self.useCoreStyle ? "A-core" : "A-auto")
        .onAppear { if SpikeEnv.containerFocus { self.focused = true } }
    }
}

private struct OptionalCoreStyle: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if self.enabled {
            content.disclosureGroupStyle(.core)
        } else {
            content.disclosureGroupStyle(.automatic)
        }
    }
}

// MARK: - B: List(selection:) carrying the hierarchy

struct ListPane: View {
    @Environment(SpikeState.self) private var state
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var bindable = self.state
        return List(selection: $bindable.listSelection) {
            DisclosureTreeView(nodes: SpikeTree.roots, level: 1)
        }
        .focusable(SpikeEnv.containerFocus && !SpikeEnv.listFocusOnly)
        .focused(self.$focused)
        .onAppear { if SpikeEnv.containerFocus || SpikeEnv.listFocusOnly { self.focused = true } }
        .keyObserver("B-list")
        .onChange(of: self.state.listSelection) { _, newValue in
            self.state.log("LIST_SEL", "\(newValue.sorted())")
        }
    }
}

// MARK: - C: fully custom

struct CustomPane: View {
    var body: some View {
        ScrollView {
            CustomTreeView()
        }
    }
}

// MARK: - A inside InsetGroupedSection

struct InsetPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                InsetGroupedSection(header: "Tree in InsetGroupedSection") {
                    DisclosureTreeView(nodes: SpikeTree.roots, level: 1)
                        .modifier(NestedRestyle())
                }
                Text("sibling content below the section")
                    .accessibilityIdentifier("spike-sibling")
            }
            .padding(.horizontal, 12)
        }
        .disclosureGroupStyle(.core)
    }
}

// MARK: - B inside a ScrollView

struct ListInScrollPane: View {
    @Environment(SpikeState.self) private var state

    var body: some View {
        @Bindable var bindable = self.state
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("above the list").accessibilityIdentifier("spike-above")
                List(selection: $bindable.listSelection) {
                    DisclosureTreeView(nodes: SpikeTree.roots, level: 1)
                }
                Text("below the list").accessibilityIdentifier("spike-below")
            }
        }
    }
}

// MARK: - B with a focus sentinel outside the List

struct ListSentinelPane: View {
    @Environment(SpikeState.self) private var state
    @FocusState private var sentinelFocused: Bool

    var body: some View {
        @Bindable var bindable = self.state
        return VStack(spacing: 4) {
            Text(self.sentinelFocused ? "SENTINEL FOCUSED" : "sentinel unfocused")
                .accessibilityIdentifier("spike-sentinel")
                .padding(6)
                .background(self.sentinelFocused ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                .focusable()
                .focused(self.$sentinelFocused)
                .keyObserver("sentinel")
            List(selection: $bindable.listSelection) {
                DisclosureTreeView(nodes: SpikeTree.roots, level: 1)
            }
            .keyObserver("B-list-inner")
        }
        .onAppear { self.sentinelFocused = true }
        .onChange(of: self.sentinelFocused) { _, newValue in
            self.state.log("SENTINEL", "focused=\(newValue)")
        }
        .onChange(of: self.state.listSelection) { _, newValue in
            self.state.log("LIST_SEL", "\(newValue.sorted())")
        }
    }
}

// MARK: - TextField control: does the injection layer apply Shift?

struct TextFieldPane: View {
    @Environment(SpikeState.self) private var state
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            TextField("probe", text: self.$text)
                .accessibilityIdentifier("spike-textfield")
                .focused(self.$focused)
            Text("typed=\(self.text)").accessibilityIdentifier("spike-typed")
        }
        .onAppear { self.focused = true }
        .onChange(of: self.text) { _, newValue in
            self.state.log("TEXT", "field=\(newValue.debugDescription)")
        }
    }
}
