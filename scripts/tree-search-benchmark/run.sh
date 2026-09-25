#!/bin/bash
# Tree 搜索重算读数（#441）：`docs/components/tree.md`「搜索性能：版本号缓存」表的来源。
#
# 测法：macOS 上 400 × 600 pt 的 NSHostingView，Tree 放在 ScrollView 里；从改宿主状态计时到
# layoutSubtreeIfNeeded() 返回（body 重算 + 视口内的行更新）。每格预热 3 次后取 SAMPLES 次的中位数 / p95，
# 每格每轮起一个新进程，跑 ROUNDS 轮，汇总取各轮的中位数。stale 列必须为 0（改动没触发重算时计数）。
#
# 前置条件：macOS 26 + Xcode 26（Swift 6.3）、python3（汇总表）、显示器亮着的登录会话（显示器睡眠时读数明显偏低）。
# BASE= 指向的 checkout 必须已含 #423（`searchFilter(_:text:)` 与 `Text(verbatim:highlighting:)`），否则编译不过。
# 耗时量级：首跑要 release 构建一遍库（带 BASE= 时两遍），约 1–3 分钟；默认 3 轮 × 全部场景约 15–25 分钟。
#
# 用法：
#   scripts/tree-search-benchmark/run.sh                       # 本仓，带 / 不带版本号两种
#   BASE=/path/to/old/checkout scripts/tree-search-benchmark/run.sh   # 另加修前那份 checkout 作对照（只测不带版本号）
#   ROUNDS=1 scripts/tree-search-benchmark/run.sh "few/balanced selection"   # 只跑一格
#   ROW_CONTENT=plain scripts/tree-search-benchmark/run.sh …   # 行内容不画命中高亮，把高亮的代价分出来
#   SUMMARY_ONLY=1 scripts/tree-search-benchmark/run.sh        # 只重新汇总上一次的 results.tsv
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROUNDS="${ROUNDS:-3}"
OUT="${OUT:-$HERE/results.tsv}"
cd "$HERE"
if [[ -z "${SUMMARY_ONLY:-}" ]]; then
swift build -c release --scratch-path .build >/dev/null
BIN_NEW="$HERE/.build/release/TreeSearchBenchmark"
BIN_BASE=""
if [[ -n "${BASE:-}" ]]; then
  TREE_BENCH_LIB="$BASE" swift build -c release --scratch-path .build-base -Xswiftc -DUNVERSIONED_ONLY >/dev/null
  BIN_BASE="$HERE/.build-base/release/TreeSearchBenchmark"
fi
scenarios=()
if [[ $# -gt 0 ]]; then scenarios=("$@"); else while IFS= read -r line; do scenarios+=("$line"); done < <("$BIN_NEW" --list); fi
: > "$OUT"
for round in $(seq 1 "$ROUNDS"); do
  for sc in "${scenarios[@]}"; do
    [[ -n "$BIN_BASE" ]] && echo -e "$round\tbase\t$(VARIANT=unversioned "$BIN_BASE" "$sc")\t$(sysctl -n vm.loadavg)" >> "$OUT"
    for v in unversioned versioned; do
      echo -e "$round\t$v\t$(VARIANT=$v "$BIN_NEW" "$sc")\t$(sysctl -n vm.loadavg)" >> "$OUT"
    done
  done
done
fi
python3 - "$OUT" <<'PY'
import collections, statistics, sys
rows = collections.defaultdict(list); stale = 0; loads = []
for line in open(sys.argv[1]):
    fields = line.rstrip("\n").split("\t")
    tag, name, median, p95, stale_field, load = fields[1], fields[2], fields[4], fields[5], fields[6], fields[-1]
    rows[(name, tag)].append((float(median), float(p95)))
    stale += int(stale_field.split("=")[1]); loads.append(float(load.split()[1]))
names = list(dict.fromkeys(name for name, _ in rows))
tags = [t for t in ("base", "unversioned", "versioned") if any(k[1] == t for k in rows)]
print("| scenario | " + " | ".join(tags) + " |")
for name in names:
    cells = []
    for tag in tags:
        values = rows.get((name, tag), [])
        cells.append("%.1f / %.1f" % (statistics.median(v[0] for v in values), statistics.median(v[1] for v in values)) if values else "-")
    print("| %s | %s |" % (name, " | ".join(cells)))
print("stale total = %d (must be 0); load1 %.1f–%.1f" % (stale, min(loads), max(loads)))
PY
