// swift-tools-version: 6.3
// Tree 搜索重算读数（#441）。跑法与读法见同目录 run.sh。
import Foundation
import PackageDescription

// 默认测本仓；设 TREE_BENCH_LIB 指向另一份 checkout（如修前的提交）可在同一台机器上对照。
let library = ProcessInfo.processInfo.environment["TREE_BENCH_LIB"] ?? "../.."

let package = Package(
    name: "TreeSearchBenchmark",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(name: "OhMyDesign", path: library),
    ],
    targets: [
        .executableTarget(
            name: "TreeSearchBenchmark",
            dependencies: [.product(name: "OhMyDesign", package: "OhMyDesign")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
