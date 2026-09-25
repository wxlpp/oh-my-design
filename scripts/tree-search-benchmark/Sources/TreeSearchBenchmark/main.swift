import AppKit
import OhMyDesign
import SwiftUI

// MARK: - 夹具 / Fixtures

struct Node: Identifiable {
    let id: String
    let name: String
    let children: [Node]?
}

func balanced(prefix: String = "", level: Int = 1) -> [Node] {
    (0..<10).map { index in
        let id = prefix.isEmpty ? "\(index)" : "\(prefix)-\(index)"
        return Node(id: id, name: "Node \(id)", children: level < 4 ? balanced(prefix: id, level: level + 1) : nil)
    }
}

func wide() -> [Node] {
    [Node(id: "root", name: "Root", children: (0..<10_000).map { Node(id: "l\($0)", name: "Leaf \($0)", children: nil) })]
}

func parentIDs(_ nodes: [Node]) -> Set<String> {
    var out: Set<String> = []
    for node in nodes {
        guard let kids = node.children else { continue }
        out.insert(node.id)
        out.formUnion(parentIDs(kids))
    }
    return out
}

// MARK: - 宿主 / Host

enum Variant: String {
    case versioned
    case unversioned
}

@MainActor
@Observable
final class Model {
    var query: String
    var version = 0
    var expanded: Set<String> = []
    var selection: Set<String> = []
    var checked: Set<String> = []

    init(query: String) {
        self.query = query
    }
}

nonisolated(unsafe) var evaluations = 0
nonisolated(unsafe) var rowContents = 0

struct Harness: View {
    let roots: [Node]
    let model: Model
    let checkBoxes: Bool
    let variant: Variant

    var body: some View {
        evaluations += 1
        return ScrollView {
            self.tree
        }
    }

    @ViewBuilder
    private var tree: some View {
        let tree = Tree(
            self.roots,
            children: \.children,
            expanded: Binding(get: { self.model.expanded }, set: { self.model.expanded = $0 }),
            selection: Binding(get: { self.model.selection }, set: { self.model.selection = $0 }),
            selectionMode: .multiple,
            checked: self.checkBoxes ? Binding(get: { self.model.checked }, set: { self.model.checked = $0 }) : nil
        ) { node in
            let _ = rowContents += 1
            if plainRows {
                Text(verbatim: node.name)
            } else {
                Text(verbatim: node.name, highlighting: self.model.query)
            }
        }
        #if UNVERSIONED_ONLY
        tree.searchFilter(self.model.query, text: \.name)
        #else
        switch self.variant {
        case .versioned: tree.searchFilter(self.model.query, text: \.name, version: self.model.version)
        case .unversioned: tree.searchFilter(self.model.query, text: \.name)
        }
        #endif
    }
}

// MARK: - 计时 / Timing

func percentile(_ values: [Double], _ fraction: Double) -> Double {
    let sorted = values.sorted()
    return sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * fraction).rounded()))]
}

@MainActor
func measure(
    _ label: String,
    roots: [Node],
    query: String,
    checkBoxes: Bool = false,
    expanded: Set<String> = [],
    variant: Variant,
    samples count: Int,
    mutate: (Model, Int) -> Void
) {
    let model = Model(query: query)
    model.expanded = expanded
    let host = NSHostingView(
        rootView: Harness(roots: roots, model: model, checkBoxes: checkBoxes, variant: variant)
            .frame(width: 400, height: 600)
    )
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 400, height: 600),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = host
    window.orderFront(nil)
    func settle() {
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
    settle()
    var samples: [Double] = []
    var stale = 0
    var rowCount = 0
    for index in 0..<(count + 3) {
        let before = evaluations
        let rowsBefore = rowContents
        let start = ContinuousClock.now
        mutate(model, index)
        host.layoutSubtreeIfNeeded()
        let elapsed = ContinuousClock.now - start
        // 存活读数：这一次改动没有让宿主 body 重算，计时量到的就不是重算。
        if evaluations == before { stale += 1 }
        if index >= 3 { rowCount += rowContents - rowsBefore }
        if index >= 3 {
            samples.append(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
        }
        settle()
    }
    window.orderOut(nil)
    print(String(
        format: "%@\t%@\t%.1f\t%.1f\tstale=%d\trows=%.1f",
        label, variant.rawValue, percentile(samples, 0.5), percentile(samples, 0.95), stale,
        Double(rowCount) / Double(count)
    ))
}

// MARK: - 场景 / Scenarios

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let environment = ProcessInfo.processInfo.environment
let variant = Variant(rawValue: environment["VARIANT"] ?? "versioned") ?? .versioned
let samples = Int(environment["SAMPLES"] ?? "25") ?? 25
// 行内容不画命中高亮（ROW_CONTENT=plain），用于把高亮的代价与过滤本身分开。
let plainRows = environment["ROW_CONTENT"] == "plain"
let only = CommandLine.arguments.dropFirst().first

let balancedRoots = balanced()
let wideRoots = wide()
let balancedParents = parentIDs(balancedRoots)
// 两个目标都在视口内（少量命中时的前几行是 0 › 0-7 › 0-7-7 › 0-7-7-7 › 1 …）。
let selectBalanced: (Model, Int) -> Void = { model, index in model.selection = index % 2 == 0 ? ["0-7"] : ["1-7"] }
// 两个目标都在视口外（行序第 30 行之后）。
let selectOffscreen: (Model, Int) -> Void = { model, index in model.selection = index % 2 == 0 ? ["7-7"] : ["8"] }
let selectWide: (Model, Int) -> Void = { model, index in model.selection = index % 2 == 0 ? ["root"] : ["l777"] }

let scenarios: [(String, @MainActor () -> Void)] = [
    ("few/balanced selection", { measure("few/balanced selection", roots: balancedRoots, query: "7-7-7", variant: variant, samples: samples, mutate: selectBalanced) }),
    ("few/balanced expanded", { measure("few/balanced expanded", roots: balancedRoots, query: "7-7-7", variant: variant, samples: samples) { model, index in model.expanded = index % 2 == 0 ? ["0"] : [] } }),
    ("few/balanced checked", { measure("few/balanced checked", roots: balancedRoots, query: "7-7-7", checkBoxes: true, variant: variant, samples: samples) { model, index in model.checked = index % 2 == 0 ? ["7-7-7-7"] : [] } }),
    ("few/balanced selection+checked", { measure("few/balanced selection+checked", roots: balancedRoots, query: "7-7-7", checkBoxes: true, variant: variant, samples: samples, mutate: selectBalanced) }),
    ("all/balanced selection", { measure("all/balanced selection", roots: balancedRoots, query: "Node", variant: variant, samples: samples, mutate: selectBalanced) }),
    ("few/wide selection", { measure("few/wide selection", roots: wideRoots, query: "Leaf 777", variant: variant, samples: samples, mutate: selectWide) }),
    ("few/wide selection+checked", { measure("few/wide selection+checked", roots: wideRoots, query: "Leaf 777", checkBoxes: true, variant: variant, samples: samples, mutate: selectWide) }),
    ("few/wide checked", { measure("few/wide checked", roots: wideRoots, query: "Leaf 777", checkBoxes: true, variant: variant, samples: samples) { model, index in model.checked = index % 2 == 0 ? ["l777"] : [] } }),
    ("few/balanced query", { measure("few/balanced query", roots: balancedRoots, query: "7-7-7", variant: variant, samples: samples) { model, index in model.query = index % 2 == 0 ? "7-7-8" : "7-7-7" } }),
    ("all/balanced query", { measure("all/balanced query", roots: balancedRoots, query: "Node", variant: variant, samples: samples) { model, index in model.query = index % 2 == 0 ? "NODE" : "Node" } }),
    ("few/wide query", { measure("few/wide query", roots: wideRoots, query: "Leaf 777", variant: variant, samples: samples) { model, index in model.query = index % 2 == 0 ? "Leaf 778" : "Leaf 777" } }),
    ("none/balanced selection", { measure("none/balanced selection", roots: balancedRoots, query: "", variant: variant, samples: samples) { model, index in model.selection = index % 2 == 0 ? ["7"] : ["8"] } }),
    ("none/balanced expanded-all selection", { measure("none/balanced expanded-all selection", roots: balancedRoots, query: "", expanded: balancedParents, variant: variant, samples: samples, mutate: selectBalanced) }),
    ("none/balanced three-levels selection", { measure("none/balanced three-levels selection", roots: balancedRoots, query: "", expanded: ["0", "1", "0-7", "1-7"], variant: variant, samples: samples, mutate: selectBalanced) }),
    ("few/balanced offscreen selection", { measure("few/balanced offscreen selection", roots: balancedRoots, query: "7-7-7", variant: variant, samples: samples, mutate: selectOffscreen) }),
    ("none/balanced offscreen selection", { measure("none/balanced offscreen selection", roots: balancedRoots, query: "", expanded: ["7", "7-7", "7-7-7"], variant: variant, samples: samples, mutate: selectOffscreen) }),
    ("none/balanced expanded", { measure("none/balanced expanded", roots: balancedRoots, query: "", expanded: ["0", "1", "0-7", "1-7"], variant: variant, samples: samples) { model, index in model.expanded = index % 2 == 0 ? ["0", "1", "0-7", "1-7", "9-9"] : ["0", "1", "0-7", "1-7"] } }),
    ("none/balanced checked", { measure("none/balanced checked", roots: balancedRoots, query: "", checkBoxes: true, expanded: ["0", "1", "0-7", "1-7"], variant: variant, samples: samples) { model, index in model.checked = index % 2 == 0 ? ["0-7-0"] : [] } }),
    ("none/balanced selection+checked", { measure("none/balanced selection+checked", roots: balancedRoots, query: "", checkBoxes: true, variant: variant, samples: samples) { model, index in model.selection = index % 2 == 0 ? ["7"] : ["8"] } }),
    ("none/wide expanded-all selection", { measure("none/wide expanded-all selection", roots: wideRoots, query: "", expanded: ["root"], variant: variant, samples: samples, mutate: selectWide) }),
]

if only == "--list" {
    for (name, _) in scenarios { print(name) }
} else {
    for (name, run) in scenarios where only == nil || only == name { run() }
}
