# Gallery 验证与评审

## 范围

只交付 OhMyDesign 的 SelectionCard 和三组预览样例。未更新 OhMyStory 依赖、未修改首页卡片或全局 AI chat bar，未安装到手机。

## 已验证

- `swift test --build-system native --filter 'SelectionCardTests|ComponentRegistryGuard'`：13 项通过。先以缺失 SelectionCardAction 编译失败确认 RED，再实现；测试调用实际 Button 使用的同一操作路径。
- BoolExemptionGuard / ComponentTextParamGuard / ComponentContractStructureGuard / MainActorStaticRatchetGuard / NativeProtocolPurityGuard：38 项通过。
- 原生 Gallery 宿主：Xcode 27.2 SDK，iOS 27.0 模拟器，Debug-iphonesimulator 构建成功；不是仅验证 Swift Package。
- 独立临时 XCUITest 宿主：选择切换、重复选择、禁用/恢复，以及 320pt + 最大辅助字号下的选择，共 2 项通过。
- 窄宽/最大辅助字号额外滚动测试：1 项通过，实际滑动后断言选项纵向位置改变；截图附于 xcresult。
- 实际截图：材质浅色、选项浅色、内容组合浅/深、320pt 单列与最大辅助字号深色。
- 减弱动态效果偏好开启时上述 2 项交互测试通过，之后恢复原偏好。这只验证功能，不声称截图能证明动画轨迹或真机触感。

原始日志、PNG、xcresult 与临时 UI 测试工程保存在本工作树 `.build/gallery-evidence`、`.build/GalleryUITests`、`.build/GalleryUITestDerived`；日志副本在 gallery-evidence。归档前须另行保留这些忽略文件。

## 评审

- spec / plan：独立 reviewer PASS。
- 代码：完整增量 `217c10c..3074bf7` PASS；`3074bf7..faeea97` 的窄宽预览参数及单位补充定向复查 PASS。
- 视觉：实际渲染评价 B+，指出统计缺单位；补单位后进一步发现字数和天数混用。最终统一为 `8,420 字 / 目标 14,000 字 / 目标进度`，进度由相同数据计算。该文案/示例数据修正不再启动第三轮评审。
- 可选建议：奇数选项的 2+1 排列可再优化；深色故事副标题可提高对比。当前可读、非阻断，保留现有排版。
- reviewer 实际模型不可观测，记录为 unknown；未启用 Fast。

## 边界

未进行真机、VoiceOver 手工朗读或系统所有对比度组合验收。Gallery 中内容、字数和人物均为示例。App 原有 ShaderDemoSubject 补 @MainActor 是预览宿主的必要编译修正，不修改主库隔离策略。既有库其他 warning 未扩展处理。

## PR 收尾补查

补齐 design-digest 自动生成台账：SelectionCard 使组件数由 108 增至 109，同步严格计数基线；未放宽检查。解析夹具通过，生成两次逐字一致。此项仅生成索引与计数，复用已有组件代码评审和构建证据。

## CI 失败定位（2026-11-01）

运行 41299456819 的 SwiftPM 与 iOS 两腿均只有同一非预期失败：CoreMotionTokenDisciplineGuard 未登记 SelectionCard（缺条目及双向集合不一致，共 2 条断言）。SelectionCard 自身只改变透明度、颜色及描边，登记为 fadeOnly；按压缩放由已有 PressableButtonStyles 的 gated 策略负责。补齐严格台账，不关闭检查、不改变动画实现。其余报告为原有 known issues。

修复后 `swift test --build-system native --filter 'CoreMotionTokenDisciplineGuard|SelectionCardTests'`：7 项通过；源码未改，复用前述代码/视觉评审，不追加全量评审。仍须等新一轮远端 CI 成功才合并。
