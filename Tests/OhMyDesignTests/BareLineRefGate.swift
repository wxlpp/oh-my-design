import Foundation
import Testing

// MARK: - 散文里的裸行号引用：只出不进（Issue #337）

@Suite("散文里的裸行号引用只出不进（#337）")
struct BareLineRefGate {
    /// 存量登记：**已于 `#337` 清零**——13 个文件的存量裸行号引用已全部按形态 2 改写为
    /// 引文逐字形态（或删除 / 降级为无需坐标的措辞）。本表**恒为空**：任何新增、改写、
    /// 换目标的 `X.swift:NN` 命中一律判红（`#337` 之后由「只出不进」升级为「零容忍」）。
    ///
    /// ⚠️ **判据比的是「逐条命中串」不是「条数」**：只数条数时，把 `Sidebar.swift:157` 原地改成
    /// `Totally/Wrong.swift:9999` **判据全绿**（终审实测）—— 而「改一段文字时顺手把行号
    /// 更新成新数字 / 把引用换到另一个文件」正是**最日常的编辑形态**，比新增更常见。
    ///
    /// ⚠️ **射程**：`docs/**/*.{md,json}` + **仓根全部 `*.md`**。`.claude/` 下的 PRD / epic /
    /// archived 是历史档，有意不进（`#346` 已按此办）。
    /// ⚠️ **`docs/superpowers/` 下的 plan / spec 也算活文档**（它们在 `docs/` 里）——
    /// 分界就是「在不在 `docs/` 下」，不按内容是否已执行完判。
    ///
    /// ⚠️ **射程外还有约 49 条同病的裸行号**（终审量化）：44 条引 **非 `.swift`** 文件
    /// （`.md` / `.metal` 等），约 5 条中文「第 N 行」—— `#337` 只清了 `.swift:NN` 这一面。
    /// 收它们要把正则放宽成 `\.(swift|md|json|metal|yml):[0-9]+` 并重生成本表 —— 未做，登记在此。
    private nonisolated static let allowance: [(path: String, refs: [String])] = []

    /// ⚠️ 与 `#337` 普查用的是**同一条**正则，换了它两边的数就对不上。
    private nonisolated static let pattern = "[A-Za-z0-9_/.-]+\\.swift:[0-9]+(-[0-9]+)?"

    private nonisolated static func refs(in text: String) throws -> [String] {
        let re = try NSRegularExpression(pattern: Self.pattern)
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
            .sorted()
    }

    @Test("#337：活文档里的裸行号引用只出不进——新增、改写、换目标一律判红")
    func bareLineRefsAreRegistered() throws {
        let root = GuardScanRoots.repoRoot
        let docsRoot = root.appendingPathComponent("docs")

        // ⚠️ **扫描根不存在要判红，不是 skip**：整个根读不出来时「零违规」是假的
        // （终审实测：`.enabled(if:)` 形态下 `mv docs docs_` ⇒ 静默 skip、EXIT=0）。
        // 本仓成例见 `GuardScanRoots.assertRootsExist`：「判据无法工作，这不是零违规」。
        #expect(FileManager.default.fileExists(atPath: docsRoot.path),
                "扫描根 docs/ 不存在 —— 判据无法工作，这不是零违规")

        var files: [URL] = []
        let enumerator = FileManager.default.enumerator(at: docsRoot, includingPropertiesForKeys: nil)
        #expect(enumerator != nil, "docs/ 枚举器建不出来 —— 同上，不是零违规")
        while let url = enumerator?.nextObject() as? URL {
            guard ["md", "json"].contains(url.pathExtension) else { continue }
            files.append(url)
        }
        // 仓根全部 `*.md`（⚠️ 不是只有 CLAUDE.md / README.md —— `AGENTS.md` 是
        // `CLAUDE.md` 的 Codex 镜像，同样是活文档）
        for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        where url.pathExtension == "md" {
            files.append(url)
        }

        var actual: [String: [String]] = [:]
        for url in files {
            let relative = GuardScanRoots.relativePath(url, from: root)
            // ⚠️ 读不出来就抛错，不 `continue` —— 静默跳过会让新增混进来。
            let hits = try Self.refs(in: try String(contentsOf: url, encoding: .utf8))
            if !hits.isEmpty { actual[relative] = hits }
        }

        // ⚠️ 重复键要判红，不能让 `Dictionary(uniqueKeysWithValues:)` 崩掉整个进程
        // （终审实测：崩溃会连累同 bundle 的其它 suite 一起没跑）。
        let paths = Self.allowance.map(\.path)
        #expect(Set(paths).count == paths.count, "allowance 有重复键：\(paths.count - Set(paths).count) 个")
        let expected = Dictionary(Self.allowance.map { ($0.path, $0.refs) }, uniquingKeysWith: { a, _ in a })

        for path in Set(expected.keys).union(actual.keys).sorted() {
            let now = actual[path] ?? []
            let cap = expected[path] ?? []
            guard now != cap else { continue }
            let onDisk = FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
            let added = now.filter { !cap.contains($0) }
            let gone = cap.filter { !now.contains($0) }
            Issue.record("""
            \(path) 的裸行号引用与登记表不符（本判据比的是**逐条命中串**，不是条数）。
            \(onDisk ? "" : "⚠️ 该文件**已不在磁盘上** —— 删了请从 allowance 去掉；改名请同步键。\n")\
            多出来 \(added.count) 条：\(added.isEmpty ? "（无）" : added.joined(separator: "、"))
            少掉了 \(gone.count) 条：\(gone.isEmpty ? "（无）" : gone.joined(separator: "、"))

            · **多出来** ⇒ 改成**引文逐字**（形态 2）：写「`Foo.body` 逐字是 `.coreFont(.footnote)`」
              这类**符号 + 原文片段**，而不是 `Foo.swift:23-25`。
              ⚠️ 行号漂了指向的是「看起来合理的别的内容」，读者**以为自己核过了**；
              逐字引文漂了会 `grep` 得 **0 命中**，读者**知道**自己没核到。
            · **少掉了** ⇒ 好事，**把 allowance 一起改小**，否则棘轮松掉。
            · **两边都有** ⇒ 引用被**原地改写**了（换行号或换目标文件）。⚠️ 这是最日常的编辑形态，
              也是「只数条数」的判据完全看不见的那一种。
            """)
        }
    }
}
