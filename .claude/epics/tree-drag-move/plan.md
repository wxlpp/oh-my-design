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

- [x] 在 TreeMove.swift 定义值类型与拓扑解析，TreeMoveTests.swift 先覆盖无效落点、循环、同层/跨层、no-op。
- [x] TreeDragDrop.swift 实现同树系统拖动会话、DropDelegate 与视觉落点；Tree.swift 接入可选 onMove、搜索禁用及会话清理。
- [x] 更新 docs/components/tree.md、component-registry、设计摘要；加入预览可交互示例。
- [x] macOS Tree 定向测试、库约束检查、iOS 预览宿主构建、App 消费端真实拖动并截图。
- [x] 在设计库开 PR，发布独立 review；App 升级锁定 SHA，接入 reorder/move(before:) 和相关测试，完成消费构建与交互验证。

## 检查点

规划产物联合审阅一次；实施完成后完整增量审阅与真实渲染视觉审阅，按实际反馈定向修复，不重复全量派审。

规划反馈已处置：首步加入会话取消、拓扑变化、策略拒绝与恰好一次/零次回调测试；系统 API 已以本机 26.4 SwiftUI.swiftinterface 核实。行阈值、叶行语义、根末尾落点与退出清理时机见 spec 补充。

## 验证记录（2026-10-15）

- 最新手柄实现：TreeMoveTests 5 项通过，iOS 预览宿主构建通过。
- 此前完整 Tree 与仓库约束定向回归 241 项通过；手柄修订后未重复全部 241 项。
- App 冻结引用 0fbf8b9：7 项 OutlineEditingTests 通过；1 项真实拖动 UI 流程通过（同级排序、移入空卷、折叠/展开、移回根目录、打开章节）。
- 首次 UI 排序落点测试失败已保留；调整为行上半部内部落点、慢速拖动并停留 0.5 秒后通过，没有为测试修改组件行为。
- 代码首审两个阻断项已修复，定向复审 PASS，原始审阅已发布 PR #468。
- macOS 原生鼠标拖放、iPad 与真机拖放未验证；不将编译或逻辑测试当作这些设备的交互证据。
- PR #468 尚未合并；消费端 PR #232 一并更新，设计库应先合入。

### 最终交付补充

独立根末尾落区已经移除，最后一个根级行的下缘即末尾。最终非诊断源码的 5 项 TreeMoveTests 通过；App 的带日志诊断构建连续两次通过卷章完整拖动流程，视觉定向复核 PASS。临时日志已移除。早期首次拖动有偶发失败但没有失败会话日志，根因仍未关闭，PR 保持草稿；没有以成功样本替代失败记录。

最终更新：App 测试改为定位实际手柄控件，替代提前计算的绝对屏幕坐标；无诊断日志的 f418a675 完整 UI 用例通过。历史失败记录保留，真机拖放尚未验收。
