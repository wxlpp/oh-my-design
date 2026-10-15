# Tree 拖动排序与层级移动

## 目标与范围

用户要求在设计库补齐 Tree 拖动排序，应用于故事卷章目录，减少独立排序页面操作。扩展既有 Tree，不引入新依赖、不认识故事业务。iOS/macOS 26，单节点在同一 Tree 内移动；父节点连子树移动。多选批量拖动、跨 Tree/跨应用导入不在本次范围。

## 交互

- 系统长按/鼠标拖动整行；上/下缘为前/后插入，容器中央为移入末尾。children != nil 表示可容纳子项，包括空数组。
- 插入位置用细线、移入用轮廓强调。未授权落点不显示有效高亮。
- 源数据仅在成功落放时由调用方修改；取消、拒绝、拖动期间结构变化均不回调。选中/展开不因拖动改变。
- 只允许当前 Tree 发起的本地拖动。禁止自身/后代循环、失效 ID 和无变化操作；搜索过滤期间禁用拖动以避免不完整排序。
- 系统滚动容器承载滚动，不新增手写全局手势或自动滚动状态机；验证实际拖动与滚动兼容。

## API 与职责

`TreeMove<ID>` 是值类型，含 `id`、`parentID`、`beforeID`；parentID=nil 为根，beforeID=nil 为目标末尾，位置在移除源节点之后解释。
`Tree.onMove(canMove:perform:)` 可选启用，canMove 判断调用方业务规则，perform 接收已验证移动请求。Tree 使用最新拓扑验证；调用方持久化失败时保持原数据，负责错误提示。不强迫 ID Codable/Transferable。
实现通过系统 onDrag/onDrop DropDelegate 取得连续落点；以每实例唯一 UTType 和 ownProcess provider 限制同树，onDragSessionUpdated 清理取消/结束。

## App 集成

卷只能位于根，章节可进卷或移回根。同层调用 reorderOutline，跨层调用 moveChapter(before:)。沿用 revision 校验与现有写入/恢复模型，不乐观改写数据库查询结果。设计库先开 PR，App 固定提交与实际消费验证；未经授权不合入 main。

## 验收

纯逻辑覆盖前后插入、末尾、空容器、跨父级、自身后代拒绝、no-op、数据变化及策略拒绝；现有 Tree 回归。iOS 宿主与 macOS 构建；实际模拟器拖动验证并截图评审。公开 API 文档、登记表与 design digest 同步。
