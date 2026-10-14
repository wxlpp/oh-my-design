# 轻量命名输入实施计划

> 使用 oh-my-superpowers:executing-plans 在当前会话执行。

**目标：** 为原生输入提供低干扰外观，在故事命名流程消费并提交设计库 PR。
**架构：** 无状态业务外观与 App 标题草稿/写入模型分离。
**技术栈：** Swift 6、SwiftUI、OhMyDesign、现有 OhMyNavigation。
**设计：** ../specs/2026-10-14-underlined-field-design.md

- [ ] 新增 Modifier/UnderlinedFieldModifier.swift，公开 View.underlinedField(isFocused:)，接收调用方焦点状态并读取 isEnabled/fieldValidation/coreAccent/displayScale，不画背景或改变业务内容。补组件使用文档与预览；该 private modifier 属主 target，现有登记表仅收录新 target 的扩展入口，不新增幽灵登记。
- [ ] 构建库、运行相关守卫/字段既有测试；公开入口通过真实 App 消费编译，不增加仅复述布局的测试。
- [ ] App WorkTitleField 改用轻量输入；WorkTitleSheet 改 ScrollView/VStack，保留保存恢复内容、取消/保存/迟到结果契约，medium/large detents；WorkTitlePresentation 创建空标题。先补现有 UI 测试的初始为空/空白禁用断言，运行 red 后改代码。
- [ ] 固定库分支 revision 并更新 Package.resolved；运行格式与 iPhone 新建/重命名和 iPad 新建回归；取得浅深色/键盘截图，独立审查代码与渲染。
- [ ] 库 PR 单独提交到 main，App 继续 #226。发布完整独立评审 COMMENT 并读回确认；构建并安装用户手机，报告实际完成范围，未合并不宣称已集成。

风险检查：焦点是否真正驱动线条；原生工具栏不重复套样式；恢复区离开 Form 后仍清晰可操作；长标题可编辑；半屏与键盘不挤掉输入；更新库 pin 带入的 Tree 变化需明确记录。

## 规划评审处置

Sol/high（标准服务请求）给出 REVISE：接受唯一焦点所有者、稳定 AX 标签、digest 基数和三处 pin 的补充；组件内部不安装 FocusState，App 显式 label。四态使用已测试的 FieldAppearance.resolve（disabled > invalid > focused > normal），不复制状态机；渲染检查补焦点/禁用效果，现有字段测试验证状态优先级。主 target 的私有 modifier 不进扩展入口登记表，更新 digest 52。真机安装沿用此会话此前用户明确要求“修好，再装到我的手机上”的授权，不另行扩大到上架或合并。
