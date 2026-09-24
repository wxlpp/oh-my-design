import SwiftUI

// MARK: - Model

struct SpikeNode: Identifiable, Sendable {
    let id: String
    let name: String
    let children: [SpikeNode]?

    var isParent: Bool { self.children != nil }
}

enum SpikeTree {
    static let roots: [SpikeNode] = [
        SpikeNode(id: "alpha", name: "Alpha", children: [
            SpikeNode(id: "alpha-one", name: "Alpha One", children: [
                SpikeNode(id: "alpha-one-a", name: "Alpha One A", children: nil),
                SpikeNode(id: "alpha-one-b", name: "Alpha One B", children: nil),
            ]),
            SpikeNode(id: "alpha-two", name: "Alpha Two", children: nil),
        ]),
        SpikeNode(id: "beta", name: "Beta", children: nil),
        SpikeNode(id: "gamma", name: "Gamma", children: [
            SpikeNode(id: "gamma-one", name: "Gamma One", children: nil),
        ]),
    ]

    static func expandedIDs(toDepth depth: Int) -> Set<String> {
        var out: Set<String> = []
        func walk(_ nodes: [SpikeNode], level: Int) {
            for node in nodes {
                guard let kids = node.children else { continue }
                if level <= depth - 1 {
                    out.insert(node.id)
                    walk(kids, level: level + 1)
                }
            }
        }
        walk(self.roots, level: 1)
        return out
    }

    static var allParentIDs: Set<String> {
        var out: Set<String> = []
        func walk(_ nodes: [SpikeNode]) {
            for node in nodes where node.children != nil {
                out.insert(node.id)
                walk(node.children!)
            }
        }
        walk(self.roots)
        return out
    }

    struct Row: Identifiable {
        let node: SpikeNode
        let level: Int
        let parentID: String?
        var id: String { self.node.id }
    }

    static func visibleRows(expanded: Set<String>) -> [Row] {
        var out: [Row] = []
        func walk(_ nodes: [SpikeNode], level: Int, parent: String?) {
            for node in nodes {
                out.append(Row(node: node, level: level, parentID: parent))
                if let kids = node.children, expanded.contains(node.id) {
                    walk(kids, level: level + 1, parent: node.id)
                }
            }
        }
        walk(self.roots, level: 1, parent: nil)
        return out
    }

    static var allIDs: [String] {
        var out: [String] = []
        func walk(_ nodes: [SpikeNode]) {
            for node in nodes {
                out.append(node.id)
                if let kids = node.children { walk(kids) }
            }
        }
        walk(self.roots)
        return out
    }
}

// MARK: - Key description

enum SpikeKey {
    static func name(_ key: KeyEquivalent) -> String {
        let c = key.character
        switch c {
        case KeyEquivalent.upArrow.character: return "upArrow"
        case KeyEquivalent.downArrow.character: return "downArrow"
        case KeyEquivalent.leftArrow.character: return "leftArrow"
        case KeyEquivalent.rightArrow.character: return "rightArrow"
        case KeyEquivalent.home.character: return "home"
        case KeyEquivalent.end.character: return "end"
        case KeyEquivalent.pageUp.character: return "pageUp"
        case KeyEquivalent.pageDown.character: return "pageDown"
        case KeyEquivalent.space.character: return "space"
        case KeyEquivalent.return.character: return "return"
        case KeyEquivalent.tab.character: return "tab"
        case KeyEquivalent.escape.character: return "escape"
        case KeyEquivalent.delete.character: return "delete"
        case KeyEquivalent.deleteForward.character: return "deleteForward"
        case KeyEquivalent.clear.character: return "clear"
        default:
            let scalar = c.unicodeScalars.first.map { String($0.value, radix: 16) } ?? "?"
            return "char(\(c))U+\(scalar)"
        }
    }

    static func modifierNames(_ mods: EventModifiers) -> [String] {
        var out: [String] = []
        if mods.contains(.shift) { out.append("shift") }
        if mods.contains(.control) { out.append("control") }
        if mods.contains(.option) { out.append("option") }
        if mods.contains(.command) { out.append("command") }
        if mods.contains(.capsLock) { out.append("capsLock") }
        if mods.contains(.numericPad) { out.append("numericPad") }
        return out
    }
}

// MARK: - State + log

enum SpikeCapture: String, CaseIterable, Identifiable {
    case passthrough
    case handled
    var id: String { self.rawValue }
}

enum SpikeMode: String, CaseIterable, Identifiable {
    case probe = "P-probe"
    case disclosureAuto = "A-auto"
    case disclosureCore = "A-core"
    case listSelection = "B-list"
    case custom = "C-custom"
    case disclosureInset = "A-inset"
    case listInScroll = "B-inscroll"
    case listSentinel = "B-sentinel"
    case textField = "P-textfield"
    case disclosureKeys = "A-keys"
    var id: String { self.rawValue }
}

@MainActor
@Observable
final class SpikeState {
    static let shared = SpikeState()

    var mode: SpikeMode = .probe
    var capture: SpikeCapture = .passthrough
    var expanded: Set<String> = []
    var selection: Set<String> = []
    var listSelection: Set<String> = []
    var focusedID: String?
    var activations: [String] = []
    var events: [String] = []
    var typeAheadBuffer: String = ""

    let dir: URL

    private var seq = 0

    private init() {
        if let raw = ProcessInfo.processInfo.environment["SPIKE_LOG_DIR"], !raw.isEmpty {
            self.dir = URL(fileURLWithPath: raw, isDirectory: true)
        } else {
            let docs = try? FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            self.dir = docs ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.dir, withIntermediateDirectories: true)
        let env = ProcessInfo.processInfo.environment
        if env["SPIKE_RESET"] == "1" {
            try? FileManager.default.removeItem(at: self.dir.appendingPathComponent("events.tsv"))
        }
        if let raw = env["SPIKE_MODE"], let parsed = SpikeMode(rawValue: raw) { self.mode = parsed }
        if let raw = env["SPIKE_CAPTURE"], let parsed = SpikeCapture(rawValue: raw) { self.capture = parsed }
        if let raw = env["SPIKE_EXPAND_DEPTH"], let depth = Int(raw) {
            self.expanded = SpikeTree.expandedIDs(toDepth: depth)
        } else {
            self.expanded = self.loadPersistedExpanded() ?? []
        }
        if env["SPIKE_PERSIST_ON_CHANGE"] == "1" { self.persistOnChange = true }
    }

    var persistOnChange = false

    // MARK: - Event log

    func log(_ kind: String, _ detail: String) {
        self.seq += 1
        let line = "\(self.seq)\t\(kind)\t\(detail)"
        self.events.append(line)
        if self.events.count > 60 { self.events.removeFirst(self.events.count - 60) }
        self.appendEventFile(line)
        self.writeStateFile()
    }

    func logKey(_ press: KeyPress, at site: String, decision: String) {
        let mods = SpikeKey.modifierNames(press.modifiers).joined(separator: "+")
        let detail = "key=\(SpikeKey.name(press.key)) mods=[\(mods)] chars=\(press.characters.debugDescription) phase=\(press.phase) site=\(site) decision=\(decision)"
        self.log("KEY", detail)
    }

    private func appendEventFile(_ line: String) {
        let url = self.dir.appendingPathComponent("events.tsv")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    func writeStateFile() {
        let payload: [String: Any] = [
            "mode": self.mode.rawValue,
            "capture": self.capture.rawValue,
            "expanded": self.expanded.sorted(),
            "selection": self.selection.sorted(),
            "listSelection": self.listSelection.sorted(),
            "focusedID": self.focusedID ?? "<nil>",
            "activations": self.activations,
            "visibleRows": SpikeTree.visibleRows(expanded: self.expanded).map { "\($0.node.id)@\($0.level)" },
            "typeAheadBuffer": self.typeAheadBuffer,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: self.dir.appendingPathComponent("state.json"))
    }

    // MARK: - Persistence probe

    private var persistURL: URL { self.dir.appendingPathComponent("expanded-persisted.json") }

    func persistExpanded() {
        guard let data = try? JSONSerialization.data(withJSONObject: self.expanded.sorted()) else { return }
        try? data.write(to: self.persistURL)
        self.log("PERSIST", "wrote expanded=\(self.expanded.sorted())")
    }

    private func loadPersistedExpanded() -> Set<String>? {
        guard let data = try? Data(contentsOf: self.persistURL),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
        return Set(arr)
    }

    func reportRestoredExpandedOnLaunch() {
        self.log("LAUNCH", "restored expanded=\(self.expanded.sorted()) (source=expanded-persisted.json)")
    }

    // MARK: - Mutations

    func binding(forExpanding id: String) -> Binding<Bool> {
        Binding(
            get: { self.expanded.contains(id) },
            set: { newValue in
                if newValue { self.expanded.insert(id) } else { self.expanded.remove(id) }
                self.log("EXPAND", "\(id) -> \(newValue) set=\(self.expanded.sorted())")
                if self.persistOnChange { self.persistExpanded() }
            }
        )
    }

    func activate(_ id: String) {
        self.activations.append(id)
        if self.activations.count > 20 { self.activations.removeFirst(self.activations.count - 20) }
        self.log("ACTIVATE", id)
    }

    func toggleSelection(_ id: String) {
        if self.selection.contains(id) { self.selection.remove(id) } else { self.selection.insert(id) }
        self.log("SELECT", "toggle \(id) -> \(self.selection.sorted())")
    }

    func expand(toDepth depth: Int) {
        self.expanded = SpikeTree.expandedIDs(toDepth: depth)
        self.log("EXPAND_DEPTH", "depth=\(depth) set=\(self.expanded.sorted())")
    }

    func resetLog() {
        self.seq = 0
        self.events = []
        try? FileManager.default.removeItem(at: self.dir.appendingPathComponent("events.tsv"))
        self.writeStateFile()
    }
}
