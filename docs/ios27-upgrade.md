# Xcode 27 / iOS 27 兼容性记录

本次保留 Package.swift 的 iOS/macOS 26 与 Swift tools 6.3 门槛。使用 Xcode 27.1 / Swift 6.4 / macOS 27.2 验证；这不等于已在 macOS 26 运行。

## 修改

- 纯几何 Shape、遮罩颜色辅助方法和测试数据结构显式 nonisolated，解决新 SDK 协议隔离一致性错误。公开入口的并发调用契约因此更宽，几何计算不变。
- 滑动确认的流光中心已由几何层换算为物理坐标；新系统 RTL 渐变再次翻转导致方向错误。新增内部标签视图，在系统27及之后把物理中心还原为逻辑中心，再交给系统镜像；26保留原坐标。始终只绘制一层文字，保留 RTL 排版与透明度。
- Swift 6.4 默认构建系统改为 swiftbuild。CI 显式保留 native 腿的原始颜色资源守卫；Shader 与 Toast 像素验证使用编译后的 Metal/颜色资源，并分别要求 suite 实际通过。
- Toast 文字截断基准使用真实动作样式；命中区对照仍保留紧凑 light 样式。边缘使用语义色图标定位，不再把新系统玻璃阴影计入内容边界。
- 玻璃按压反馈使用红色内容探针的对比度衡量变暗，不把不透明玻璃底层的 alpha 误当作内容亮度。

## 证据

证据目录为本 worktree 的 `.build/evidence/ios27/`。

- `rtl-shimmer-fixed.log`：实际 hosted RTL 流光方向测试通过。
- `glass-press-measurement.log`：按压反馈定向测试通过。
- `toast-compiled-fixed.log`：14 项 Toast 测试通过，包含普通/AX5 和命中区两个参数化场景。
- `compiled-resource-render-tests2.log`：43 项 Shader 测试通过，包含 metallib 实际加载。该次整体失败来自随后修复的 Toast 测试参考样式，不能称整个命令通过。
- `macos-native-final.log`：exit0，1694项/258 suites通过，5项known issues。
- `shimmer-single-layer-red.log` 复现叠画，`shimmer-single-layer-direct.log` 两项通过：原始单层文字与静止标签在明暗/半透明下等价，LTR/RTL高光方向保持正确。
- `scripts/require-test-summary.py` 验证CI成功终态；缺汇总、1项小分片日志均拒绝，1694项真实汇总通过。
- App 已以暂时提交 cffe8af 集成构建/测试；本次后续渲染修复还需更新 App 精确 pin 后再次验证。

定向复审与分支终审均 PASS，覆盖最终 c8a5c40；后续文档状态更新不改变源码。

未完成：远端 CI、App 最终 pin、实际 iOS 渲染及旧系统运行验收。此记录不是整体完成声明。

## CI 摘要扫描修复

40765247023 的 SwiftPM 测试与 compiled-resource 测试均通过，最后 design-digest 守卫失败。原因是扫描器漏掉 `nonisolated public struct StarShape` 与 `nonisolated static var maskOpaque`，不是公开 API 被删除。新增两个最小夹具先复现失败，扩展原扫描规则后通过；private 类型/颜色仍排除，FLOORS 未改，生成的 design-digest.md 无差异。CI 摘要步骤先运行夹具回归。该修改只影响文档扫描脚本，不改变已验收 Swift 产品。


## CI 命令守卫修正

CI 40769823476 的 iOS 任务检测到摘要同步命令被合并了前置夹具命令，触发既有 DesignDigestSyncGuard。将 Python 夹具拆为独立步骤，保持原同步命令及守卫不变。定向 Swift 测试 12 项通过，Python 夹具 2 项通过，摘要重生成无差异。此增量不改 Swift 产品。


## Tree 拖动 payload 重入

iOS27 App 实际跨卷拖动回归失败。无断点事件日志确认：系统同一次拖动多次调用 onDrag，旧 begin 每次更换 token，DropInfo 的 provider 却保留最初 token，导致 accepts 拒绝。延长停留和降低速度均不能解决，挂断点反而改变时序，不能作为修复证据。

新增 preparePayload，在同源、同结构的活动会话中复用 token；独立 begin 仍创建新会话。iOS27/macOS26 通过 onDragSessionUpdated 按系统会话ID回收对应 token，旧会话结束不会取消新会话；iOS26保持原路径与部署门槛。签名以 Xcode27.1 SDK 核对，Context7工具在当前会话不可用。

TreeMoveTests 先记录重复 payload 导致的3条失败断言，修正后7项通过。原坐标、原速度、无断点 App 目录回归首次完整通过（77.742秒），第二次复验仍进行中；取消后重拖与独立定向评审仍待验收。临时诊断日志已移除，未修改下载依赖缓存。
