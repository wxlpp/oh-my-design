#!/usr/bin/env python3
"""拒绝测试进程提前返回 0、却没有完整 Swift Testing 汇总的日志。"""
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("log", type=Path)
parser.add_argument("--minimum", type=int, required=True)
args = parser.parse_args()
text = args.log.read_text(errors="replace")
counts = [int(value) for value in re.findall(
    r"Test run with (\d+) tests? (?:in \d+ suites? )?passed after", text
)]
if not counts or max(counts) < args.minimum:
    raise SystemExit(
        f"缺少完整测试成功汇总：至少需要 {args.minimum} 项，实际汇总 {counts}。"
        "进程 exit 0 不能替代测试完成证据。"
    )
print(f"已确认成功终态汇总：{max(counts)} 项测试。")
