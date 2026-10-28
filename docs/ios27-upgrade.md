# Xcode 27 / iOS 27 兼容性记录

本次保留 Package.swift 的 iOS/macOS 26 与 Swift tools 6.3 门槛。使用 Xcode 27.1 / Swift 6.4 / macOS 27.2 验证；这不等于已在 macOS 26 运行。

## 修改

- 纯几何 Shape、遮罩颜色辅助方法和测试数据结构显式 nonisolated，解决新 SDK 协议隔离一致性错误。公开入口的并发调用契约因此更宽，几何计算不变。
- 滑动确认的流光中心已由几何层换算为物理坐标；新系统 RTL 渐变再次翻转导致方向错误。新增内部标签视图，只固定渐变方向，保留文字的 RTL 排版。
- Swift 6.4 默认构建系统改为 swiftbuild。CI 显式保留 native 腿的原始颜色资源守卫；Shader 与 Toast 像素验证使用编译后的 Metal/颜色资源，并分别要求 suite 实际通过。
- Toast 文字截断基准使用真实动作样式；命中区对照仍保留紧凑 light 样式。边缘使用语义色图标定位，不再把新系统玻璃阴影计入内容边界。
- 玻璃按压反馈使用红色内容探针的对比度衡量变暗，不把不透明玻璃底层的 alpha 误当作内容亮度。

## 证据

证据目录为本 worktree 的 `.build/evidence/ios27/`。

- `rtl-shimmer-fixed.log`：实际 hosted RTL 流光方向测试通过。
- `glass-press-measurement.log`：按压反馈定向测试通过。
- `toast-compiled-fixed.log`：14 项 Toast 测试通过，包含普通/AX5 和命中区两个参数化场景。
- `compiled-resource-render-tests2.log`：43 项 Shader 测试通过，包含 metallib 实际加载。该次整体失败来自随后修复的 Toast 测试参考样式，不能称整个命令通过。
- `macos-native-final.log`：当前全量 native 验证日志，终态待核对。
- App 已以暂时提交 cffe8af 集成构建/测试；本次后续渲染修复还需更新 App 精确 pin 后再次验证。

未完成：全量 native 终态、新修改独立评审、App 最终 pin、实际 iOS 渲染验收。此记录不是整体完成声明。
