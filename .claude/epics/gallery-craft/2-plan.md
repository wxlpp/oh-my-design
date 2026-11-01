# Gallery 材质与内容组合实施计划

> 使用 oh-my-superpowers:executing-plans 逐步实施。

**目标：** 三组可操作原生 Gallery 与可复用 SelectionCard。
**架构：** 核心库仅增加选择卡片；示例、背景与业务文案归 App/Sources，保持依赖方向。
**技术：** 当前 SwiftUI、iOS/macOS 26+，不升级依赖。
**设计：** 1-spec.md。

- [ ] SelectionCard 的单选行为测试先失败，再实现原生 Button 和选择绑定；禁用门禁、selected trait、语义配色与自然换行。
- [ ] 同步 docs/components/selection-card.md、组件登记表与 README；运行对应守卫和定向行为测试。
- [ ] 新增 GalleryCraft.swift，三项 ComponentMeta 入口，直达启动适配；手动添加项目文件引用，避免重新生成工程噪声。
- [ ] 构建 iOS 宿主，模拟器运行选择与外观切换，截图检查浅/深及大字/窄宽边界，交视觉评审。
- [ ] 代码终审与定向修复，记录实际验证，创建 PR，不自动合并、不改 App 依赖。

风险重点：玻璃叠彩背景时文字可读性；选中不只靠颜色；固定尺寸不能截断说明；手动 Xcode 引用必须真实编译；原有组件行为保持。
