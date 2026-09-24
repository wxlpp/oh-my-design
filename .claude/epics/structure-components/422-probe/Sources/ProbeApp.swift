import SwiftUI
import OhMyDesign
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Fixture

struct ProbeNode: Identifiable {
    let id: String
    let name: String
    let children: [ProbeNode]?
}

enum ProbeTree {
    static let roots: [ProbeNode] = [
        ProbeNode(id: "a", name: "Alpha", children: [
            ProbeNode(id: "a1", name: "Alpha One", children: [
                ProbeNode(id: "a1x", name: "Alpha One X", children: nil),
                ProbeNode(id: "a1y", name: "Alpha One Y", children: nil),
            ]),
            ProbeNode(id: "a2", name: "Alpha Two", children: nil),
        ]),
        ProbeNode(id: "b", name: "Beta", children: nil),
        ProbeNode(id: "c", name: "Gamma", children: [
            ProbeNode(id: "c1", name: "Gamma One", children: nil),
        ]),
    ]
}

// MARK: - State + log

@MainActor
@Observable
final class ProbeState {
    static let shared = ProbeState()

    var expanded: Set<String> = []
    var selection: Set<String> = []
    var checked: Set<String> = []
    var activations: [String] = []
    var tail: [String] = []

    let mode: TreeSelectionMode
    let dir: URL

    private var seq = 0

    private init() {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["PROBE_LOG_DIR"], !raw.isEmpty {
            self.dir = URL(fileURLWithPath: raw, isDirectory: true)
        } else {
            let docs = try? FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            self.dir = docs ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.dir, withIntermediateDirectories: true)
        self.mode = env["PROBE_MODE"] == "single" ? .single : .multiple
        if env["PROBE_RESET"] == "1" {
            try? FileManager.default.removeItem(at: self.dir.appendingPathComponent("events.tsv"))
        }
        let depth = Int(env["PROBE_EXPAND_DEPTH"] ?? "2") ?? 2
        self.expanded = Tree<[ProbeNode], String, Text>.expandedIDs(
            ProbeTree.roots, id: \.id, children: \.children, toDepth: depth
        )
    }

    func log(_ kind: String, _ detail: String) {
        self.seq += 1
        let line = "\(self.seq)\t\(kind)\t\(detail)"
        self.tail.append(line)
        if self.tail.count > 20 { self.tail.removeFirst(self.tail.count - 20) }
        let url = self.dir.appendingPathComponent("events.tsv")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
        self.writeStateFile()
    }

    func writeStateFile() {
        let payload: [String: Any] = [
            "mode": self.mode == .single ? "single" : "multiple",
            "expanded": self.expanded.sorted(),
            "selection": self.selection.sorted(),
            "checked": self.checked.sorted(),
            "activations": self.activations,
            "visibleRows": ProbeState.visibleRowIDs(expanded: self.expanded),
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: self.dir.appendingPathComponent("state.json"))
    }

    static func visibleRowIDs(expanded: Set<String>) -> [String] {
        var out: [String] = []
        func walk(_ nodes: [ProbeNode]) {
            for node in nodes {
                out.append(node.id)
                if let kids = node.children, !kids.isEmpty, expanded.contains(node.id) { walk(kids) }
            }
        }
        walk(ProbeTree.roots)
        return out
    }

    var expandedBinding: Binding<Set<String>> {
        Binding(
            get: { self.expanded },
            set: { newValue in
                let added = newValue.subtracting(self.expanded).sorted()
                let removed = self.expanded.subtracting(newValue).sorted()
                self.expanded = newValue
                self.log("EXPAND", "+\(added) -\(removed) set=\(newValue.sorted())")
            }
        )
    }

    var selectionBinding: Binding<Set<String>> {
        Binding(
            get: { self.selection },
            set: { newValue in
                let added = newValue.subtracting(self.selection).sorted()
                let removed = self.selection.subtracting(newValue).sorted()
                self.selection = newValue
                self.log("SELECT", "+\(added) -\(removed) set=\(newValue.sorted())")
            }
        )
    }

    var checkedBinding: Binding<Set<String>> {
        Binding(
            get: { self.checked },
            set: { newValue in
                let added = newValue.subtracting(self.checked).sorted()
                let removed = self.checked.subtracting(newValue).sorted()
                self.checked = newValue
                self.log("CHECK", "+\(added) -\(removed) set=\(newValue.sorted())")
            }
        )
    }

    func activate(_ id: String) {
        self.activations.append(id)
        self.log("ACTIVATE", id)
    }
}

// MARK: - App

@main
struct ProbeApp: App {
    @State private var state = ProbeState.shared

    var body: some Scene {
        WindowGroup {
            ProbeRootView()
                .environment(self.state)
                .frame(minWidth: 380, minHeight: 560)
        }
    }
}

struct ProbeRootView: View {
    @Environment(ProbeState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "mode=\(self.state.mode == .single ? "single" : "multiple")")
                .font(.caption.monospaced())
                .accessibilityIdentifier("probe-header")

            Tree(
                ProbeTree.roots,
                children: \.children,
                expanded: self.state.expandedBinding,
                selection: self.state.selectionBinding,
                selectionMode: self.state.mode,
                checked: self.state.checkedBinding,
                onActivate: { self.state.activate($0) }
            ) { node in
                Text(verbatim: node.name)
                    .accessibilityIdentifier("row-\(node.id)")
            }

            Divider()
            Text(verbatim: "expanded=\(self.state.expanded.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
            Text(verbatim: "selection=\(self.state.selection.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
                .accessibilityIdentifier("probe-selection")
            Text(verbatim: "checked=\(self.state.checked.sorted().joined(separator: ","))")
                .font(.caption2.monospaced())
                .accessibilityIdentifier("probe-checked")
            Text(verbatim: "act=\(self.state.activations.suffix(3).joined(separator: ","))")
                .font(.caption2.monospaced())
                .accessibilityIdentifier("probe-activations")

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(self.state.tail.suffix(12).enumerated()), id: \.offset) { pair in
                        Text(verbatim: pair.element)
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .onKeyPress(phases: .down) { press in
            self.state.log("SENTINEL", "key=\(press.key) mods=\(press.modifiers) chars=\(press.characters.debugDescription)")
            return .ignored
        }
        .onKeyPress(phases: .repeat) { press in
            self.state.log("SENTINEL-REPEAT", "key=\(press.key)")
            return .ignored
        }
        .onAppear {
            self.state.log("LAUNCH", "expanded=\(self.state.expanded.sorted()) rows=\(ProbeState.visibleRowIDs(expanded: self.state.expanded))")
            #if canImport(AppKit)
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            #endif
        }
    }
}
