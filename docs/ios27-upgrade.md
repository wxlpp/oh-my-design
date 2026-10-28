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
