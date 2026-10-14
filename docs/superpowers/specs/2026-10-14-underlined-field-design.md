# 轻量命名输入

用户已明确要求去除新建故事表单的卡片嵌套与厚重灰底，让故事标题成为主角，并单独提交设计库 PR。

## 设计

设计库新增 `.underlinedField()` View modifier：在调用方原生输入控件下绘制 hairline 分隔线；通过局部 FocusState 观察焦点，聚焦使用 coreAccent，禁用保持弱化。复用 fieldValidation 的错误色。无背景、圆角、字体或业务文案；不实现 TextFieldStyle 的私有入口，不包装文本绑定，不更改现有 FormField。

App 使用原生 TextField + plain style + title 字体 + underlinedField，移除 Form/Section 卡片与 required 星号。单字段的可访问标签保留 Story Title。初始标题为空，placeholder 为 Story title。Saved on this device. 放在字段外。Create 对空白输入禁用，保存、恢复草稿、冲突确认和关闭后导航保持现有契约。

实施判断：命名 sheet 默认 medium、可展开 large；使用 ScrollView 适应键盘和恢复提示，iPad 内容宽度限制 560。不自动弹键盘，保留原生输入焦点行为与原生工具栏。重命名复用相同布局并保留原题。

## 边界与验证

iOS 26 / macOS 26 / Swift 6；语义 token，Dynamic Type；不新增依赖。库从 origin/main 8ba79217 建分支，其相较 App 固定版本仅增加 Tree 搜索缓存变更；App 显式更新固定 revision，记录这一差异。检查库 macOS 编译与守卫、App iPhone/iPad 新建、空白禁用、取消、重命名和创建后导航；截图独立视觉评审。打开设计库 PR，App 更新现有 PR #226，不合并。
