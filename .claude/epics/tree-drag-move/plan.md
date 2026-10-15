# Tree 拖动排序实施计划

> 使用 oh-my-superpowers:executing-plans 实施。

**目标：** 设计库通用 Tree 拖放，并在 App 卷章目录消费。
**架构：** TreeMove 值类型表达移动；TreeStructure 从当前数据解析位置和防循环；本地拖动会话仅持有临时交互；调用方 owns 数据。
**技术：** Swift 6，SwiftUI，iOS/macOS 26，Swift Testing。
**设计：** [spec.md](spec.md)

## 约束与审阅重点

- 禁止直接修改 App 的 SwiftPM checkout；公开 API 同步 digest。
- 确认取消不会写入、动态结构变化不会落错位置、空卷能移入、拖动不抢行内按钮。
- 本次用户已授权实现，沿用已有 auto 模式；main 合并不在授权内。

## 步骤

- [ ] 在 TreeMove.swift 定义值类型与拓扑解析，TreeMoveTests.swift 先覆盖无效落点、循环、同层/跨层、no-op。
- [ ] TreeDragDrop.swift 实现同树系统拖动会话、DropDelegate 与视觉落点；Tree.swift 接入可选 onMove、搜索禁用及会话清理。
- [ ] 更新 docs/components/tree.md、component-registry、设计摘要；加入预览可交互示例。
- [ ] macOS Tree 定向测试、库约束检查、iOS 预览宿主真实拖动并截图。
- [ ] 在设计库开 PR，发布独立 review；App 升级锁定 SHA，接入 reorder/move(before:) 和相关测试，完成消费构建与交互验证。

## 检查点

规划产物联合审阅一次；实施完成后完整增量审阅与真实渲染视觉审阅，按实际反馈定向修复，不重复全量派审。

规划反馈已处置：首步加入会话取消、拓扑变化、策略拒绝与恰好一次/零次回调测试；系统 API 已以本机 26.4 SwiftUI.swiftinterface 核实。行阈值、叶行语义、根末尾落点与退出清理时机见 spec 补充。
