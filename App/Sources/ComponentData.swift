import SwiftUI
import OhMyDesign
// ⚠️ **多 product 之后必须逐条 import**（#245 的失效形态：`App/project.yml` 只写
// `- package: OhMyDesign` 时预览宿主编译得过、但画廊里的新组件 import 不到）。
// `project.yml` 那侧的三条 `product:` 与这两行是**一对**，改一边必须改另一边。
import OhMyDesignCharts
import OhMyDesignEffects

// MARK: - ComponentCategory

enum ComponentCategory: String, CaseIterable, Identifiable {
    case button = "Button"
    case form = "Form"
    case indicator = "Indicator"
    case layout = "Layout"
    case container = "Container"
    case navigation = "Navigation"
    case feedback = "Feedback"
    /// `OhMyDesignEffects` 的 36 个 API 单位（微交互 8 + 转场 16 + 庆祝与处理中 4
    /// + 文本与展示 4 + 跨平台改造 4）。
    case effect = "Effect"
    /// `OhMyDesignCharts` 的 4 个图表。
    case chart = "Chart"

    var id: String { self.rawValue }
}

// MARK: - ComponentMeta

struct ComponentMeta: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: ComponentCategory
    let preview: () -> AnyView
    let demoAction: (() -> AnyView)?

    static func == (lhs: ComponentMeta, rhs: ComponentMeta) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

    init(
        id: String,
        name: String,
        description: String,
        category: ComponentCategory,
        @ViewBuilder preview: @escaping () -> some View,
        demoAction: (() -> AnyView)? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.preview = { AnyView(preview()) }
        self.demoAction = demoAction
    }
}

// MARK: - Component Registry

extension ComponentMeta {
    @MainActor static let all: [ComponentMeta] = [
        // Button
        ComponentMeta(id: "button", name: "Button", description: "3 种 ButtonStyle：solid / light / borderless，按 role 参数化配色", category: .button) {
            ButtonPreview()
        },
        ComponentMeta(id: "float-button", name: "FloatButton", description: "悬浮按钮：ExtendedFloatButtonStyle 胶囊玻璃 + CircularGlassButtonStyle 圆形玻璃", category: .button) {
            FloatButtonPreview()
        },

        ComponentMeta(id: "pressable-button-styles", name: "Pressable Button Styles", description: "按压反馈 ButtonStyle：.pressableRow 铺按下底色 / .pressableCard 按下缩放，只装饰 label", category: .button) {
            PressableButtonStylesPreview()
        },
        // Form
        ComponentMeta(id: "label-icon", name: "Form Icons", description: "表单图标：LabelIcon / ChevronRightIcon / DangerIcon", category: .form) {
            FormIconsPreview()
        },
        ComponentMeta(id: "segmented-control", name: "SegmentedControl", description: "分段控件，token 化配色 + 选中态", category: .form) {
            SegmentedControlPreview()
        },
        ComponentMeta(id: "search-field", name: "SearchField", description: "搜索输入框 — magnifyingglass + clear button + focus ring", category: .form) {
            SearchFieldPreview()
        },
        ComponentMeta(id: "rating", name: "Rating", description: "Binding<Double> 驱动的星级评分控件，step 参数控制步进粒度", category: .form) {
            RatingPreview()
        },
        ComponentMeta(id: "rating-display", name: "RatingDisplay", description: "只读评分展示（indicator）——无手势、不走原生 disabled 变灰", category: .form) {
            RatingDisplayPreview()
        },
        ComponentMeta(id: "pin-code", name: "PinCode", description: "验证码 / PIN 分格输入，隐藏 TextField 承接系统键盘 + iOS 单条码 OTP 自动填充", category: .form) {
            PinCodePreview()
        },
        ComponentMeta(id: "radio-group", name: "RadioGroup", description: "互斥单选组，与 CheckBox 成对的视觉语汇", category: .form) {
            RadioGroupPreview()
        },
        ComponentMeta(id: "tag-input", name: "TagInput", description: "标签输入框：Tag chip + 内联 TextField，回车/逗号提交", category: .form) {
            TagInputPreview()
        },
        ComponentMeta(id: "tag-group", name: "TagGroup", description: "可选标签组：none / single / multiple，禁用集合，选中色跟随 coreAccent", category: .form) {
            TagGroupPreview()
        },
        ComponentMeta(id: "form-field", name: "FormField", description: "字段容器：label + 必填星号 + description + 错误行；.fieldValidation / .fieldRequirement 环境值", category: .form) {
            FormFieldPreview()
        },
        ComponentMeta(id: "form-field-controls-valid", name: "FormField · 控件 valid", description: "PinCode / TagInput / SearchField / CheckBox / RadioGroup 放进 FormField：valid", category: .form) {
            FormFieldControlsPreview(state: .valid)
        },
        ComponentMeta(id: "form-field-controls-invalid", name: "FormField · 控件 invalid", description: "五个控件 invalid：描边 / 图标取 statusDangerForeground，错误原因挂到真实输入节点的 hint", category: .form) {
            FormFieldControlsPreview(state: .invalid)
        },
        ComponentMeta(id: "form-field-controls-plain", name: "FormField · 控件不在 FormField 内", description: "五个控件裸放、无校验态：无障碍 label / hint 与接入前一致", category: .form) {
            FormFieldControlsPlainPreview()
        },
        ComponentMeta(id: "form-field-controls-edge", name: "FormField · 控件边界情形", description: "调用方自带 accessibilityLabel、嵌套 FormField 最近一层生效", category: .form) {
            FormFieldControlsEdgePreview()
        },
        ComponentMeta(id: "form-field-controls-disabled", name: "FormField · 控件 disabled + invalid", description: "disabled 压过 invalid：与 disabled + valid 外观一致，错误原因只留在 hint", category: .form) {
            FormFieldControlsPreview(state: .disabledInvalid)
        },

        // Indicator
        ComponentMeta(id: "badge", name: "Badge", description: "5 状态等级指示器：info / success / warning / danger / neutral", category: .indicator) {
            BadgePreview()
        },
        ComponentMeta(id: "anchored-badge", name: "anchoredBadge", description: "View.anchoredBadge(_:placement:hostShape:)：头像 / 图标角上的红点、计数（max+ 截断）、短文本；固定 danger 色，不跟随 accent", category: .indicator) {
            AnchoredBadgePreview()
        },
        ComponentMeta(id: "tag", name: "Tag", description: "调用方自定义颜色的分类标签，支持 removable", category: .indicator) {
            TagPreview()
        },
        ComponentMeta(id: "banner", name: "Banner", description: "通知横幅，五级语义，可带标题 / 动作 / 关闭", category: .indicator) {
            BannerPreview()
        },
        ComponentMeta(id: "banner-levels", name: "Banner · 五档 Plain / Bordered", description: "五档语义在分组画布上的 Plain 与 Bordered 外观", category: .indicator) {
            BannerLevelsPreview(backdrop: .canvas)
        },
        ComponentMeta(id: "banner-on-card", name: "Banner · 白底卡片里", description: "同一组五档放进 systemBackground 白底卡片，对照分组画布", category: .indicator) {
            BannerLevelsPreview(backdrop: .card)
        },
        ComponentMeta(id: "progress-indicator", name: "ProgressIndicator", description: "通用圆形加载指示器，可选文案渲染于 spinner 下方", category: .indicator) {
            ProgressIndicatorGalleryPreview()
        },
        ComponentMeta(id: "skeleton", name: "Skeleton", description: "骨架屏容器：SkeletonLine / SkeletonRect / SkeletonCircle 占位形状 + shimmer 扫光", category: .indicator) {
            SkeletonPreview()
        },
        ComponentMeta(id: "steps", name: "Steps", description: "步骤条：4 种呈现（steps / segmentedBar / navigation / text）× 点状 / 数字指示器", category: .indicator) {
            StepsPreview()
        },
        ComponentMeta(id: "timeline", name: "Timeline", description: "时间线：4 种排布（vertical / alternate / horizontal / grouped），节点 + 连线 + 内容", category: .indicator) {
            TimelinePreview()
        },

        // Layout
        ComponentMeta(id: "avatar", name: "Avatar", description: "头像组件，按名称首字母生成", category: .layout) {
            AvatarPreview()
        },
        ComponentMeta(id: "size-system", name: "Size System", description: "同一 controlSize 下 Avatar / 文本 / Badge / Tag 同排对齐，五档对照", category: .layout) {
            SizeSystemPreview()
        },
        ComponentMeta(id: "list-row", name: "ListRow", description: "3-槽位泛型列表行：leading / label / trailing", category: .layout) {
            ListRowPreview()
        },
        ComponentMeta(id: "carousel", name: "Carousel", description: "走马灯：ScrollView 分页滚动 + 自动轮播 + 页点指示器", category: .layout) {
            CarouselPreview()
        },
        ComponentMeta(id: "tree", name: "Tree", description: "层级树：受控展开（Set<ID>）+ 单选 / 多选 + 父节点三态复选框 + W3C Treeview 键盘导航", category: .layout) {
            TreePreview()
        },

        // Container（Phase 2）
        ComponentMeta(id: "settings-screen", name: "Settings Screen", description: "SC#10：仅用 OhMyDesign 复刻一屏 iOS 设置页（InsetGroupedSection + SettingsRow）", category: .container) {
            SettingsScreenDemo()
        },
        ComponentMeta(id: "inset-grouped-section", name: "InsetGroupedSection", description: "iOS .insetGrouped 分组容器 + 自动分隔线 inset + 页眉页脚", category: .container) {
            InsetGroupedSectionPreview()
        },
        ComponentMeta(id: "settings-row", name: "SettingsRow", description: "设置行：图标方块 + 标题 + 副标题 + accessory（value / chevron / Toggle / 自定义）", category: .container) {
            SettingsRowPreview()
        },
        ComponentMeta(id: "settings-row-in-list", name: "SettingsRow in List", description: "AC9：SettingsRow 直接作原生 List 行 + .listRowInsets(EdgeInsets()) 消双重 inset", category: .container) {
            SettingsRowInListDemo()
        },
        ComponentMeta(id: "card", name: "Card", description: ".surface(.content) 具名封装 + 默认内边距，浮于画布之上", category: .container) {
            CardPreview()
        },
        ComponentMeta(id: "separator", name: "Separator", description: "可控 leading inset 的 hairline 分隔线，走 dividerDefault 系统色", category: .container) {
            SeparatorPreview()
        },
        ComponentMeta(id: "section-header-footer", name: "Section Header / Footer", description: "iOS 分组页眉（大写 footnote 灰）/ 页脚说明", category: .container) {
            SectionHeaderFooterPreview()
        },
        ComponentMeta(id: "descriptions", name: "Descriptions", description: "描述列表：.core LabeledContentStyle + InsetGroupedSection，1/2 列 + 大字号自动塌列", category: .container) {
            DescriptionsPreview()
        },

        // Form（Phase 2 .core style）
        ComponentMeta(id: "core-progressview", name: ".core ProgressView", description: "系统 ProgressView 的 .core style，填充走 .tint", category: .form) {
            CoreProgressViewPreview()
        },
        ComponentMeta(id: "core-circular-progressview", name: ".coreCircular ProgressView", description: "系统 ProgressView 的环形 .coreCircular style，圆弧走 .tint，nil 进度回退系统 spinner", category: .form) {
            CoreCircularProgressViewPreview()
        },
        ComponentMeta(id: "core-label", name: ".core Label", description: "系统 Label 的 .core style，icon 走 .tint", category: .form) {
            CoreLabelPreview()
        },
        ComponentMeta(id: "core-disclosuregroup", name: ".core DisclosureGroup", description: "系统 DisclosureGroup 的 .core style，chevron 走 .tint + leading 缩进", category: .form) {
            CoreDisclosureGroupPreview()
        },

        // Navigation
        ComponentMeta(id: "underlined-tab-bar", name: "UnderlinedTabBar", description: "下划线式 TabBar，token 化配色 + 选中态指示器", category: .navigation) {
            UnderlinedTabBarPreview()
        },

        // Feedback
        ComponentMeta(id: "toast", name: "Toast", description: "Scene-scoped toast host + 队列状态机", category: .feedback, preview: {
            ToastLevelPreview()
        }, demoAction: { AnyView(ToastDemoButton()) }),
        ComponentMeta(id: "toast-rich-capsule", name: "Toast · 标题 + 说明 + 动作", description: "floatingCapsule：title + description + ToastAction，常驻显示便于检视", category: .feedback) {
            ToastRichPreview(presentation: .floatingCapsule)
        },
        ComponentMeta(id: "toast-rich-banner", name: "Toast · fullWidthBanner 动作", description: "fullWidthBanner：title + description + ToastAction", category: .feedback) {
            ToastRichPreview(presentation: .fullWidthBanner)
        },
        ComponentMeta(id: "toast-rich-hud", name: "Toast · centeredHUD 动作", description: "centeredHUD：title + description + ToastAction", category: .feedback) {
            ToastRichPreview(presentation: .centeredHUD)
        },
        ComponentMeta(id: "toast-rich-danger-capsule", name: "Toast · danger 胶囊", description: "floatingCapsule：danger 单行标题（含长单词，检视 AX 字号折行）", category: .feedback) {
            ToastRichPreview(presentation: .floatingCapsule, sample: ToastPreviewSamples.danger())
        },
        ComponentMeta(id: "toast-rich-danger-banner", name: "Toast · danger 横幅", description: "fullWidthBanner：danger 单行标题，外壳延伸进状态栏", category: .feedback) {
            ToastRichPreview(presentation: .fullWidthBanner, sample: ToastPreviewSamples.danger())
        },
        ComponentMeta(id: "toast-rich-danger-hud", name: "Toast · danger HUD", description: "centeredHUD：danger 单行标题，外壳不透底层文字", category: .feedback) {
            ToastRichPreview(presentation: .centeredHUD, sample: ToastPreviewSamples.danger())
        },
        ComponentMeta(id: "spinning", name: "Spinning", description: "View.spinning(_:text:presentation:tint:)：overlay 遮罩（阻塞）/ topBar / inline（非阻塞）；取色走 tint: 参数，三个形态一致", category: .feedback) {
            SpinningPreview()
        },
        ComponentMeta(id: "spinning-nonblocking", name: "Spinning · 非阻塞", description: "topBar 顶条 / inline 行内：不铺遮罩、不禁用交互", category: .feedback) {
            SpinningNonBlockingPreview()
        },
    ] + Self.shipSwiftEntries
}

// MARK: - `shipswift-effects` epic 的 40 个 API 单位（#256 串行合并）
//
// ⚠️⚠️ **本数组是本 epic 唯一的画廊写入窗口**：`epic.md`《Implementation Strategy》把
// `ComponentData.swift` 列为并行冲突面，task 001–006 只产出片段、**由本 task 统一合并**；
// `shipswift-shaders` 的 B-4 复用同一窗口（追加自己的分节，不要重排本节）。
//
// ⚠️ 与主数组分成两个 `static let` 是有意的：40 条追加进上面那个字面量会让整个
// `all` 的类型检查退化（SwiftUI 的 `some View` 闭包 + 40 元素数组字面量），
// 且合并冲突面会从「本节」扩大到「整个 all」。
//
// ⚠️ **"可用"的第 ③ 条（有 `#Preview` 且进画廊）在本仓分两处兑现**：`#Preview` 在
// 各自的 `Sources/OhMyDesign*/…` 源文件里（库内视觉冒烟），画廊条目在这里。
//
// ⚠️ **本节有意不补 `App/Sources/Previews.swift` 的宿主 `#Preview`**，两条理由：
// ① 这批 API 单位绝大多数是**只在值变化 / 进出那一瞬间**才有东西可看的动效，
//    静止帧与未加修饰的内容像素级相同，收进 `docs/snapshots` 只是噪声；
// ② 提交态的快照按**产地**收（只收 `OhMyDesignPreview_*`），而库内 `#Preview`
//    一律不入库 —— 规则与三次全量渲染的实测证据写在
//    `scripts/run-snapshots.sh` 默认模式那段注释里，判据在
//    `Tests/OhMyDesignTests/SnapshotArtifactGuard.swift`。
extension ComponentMeta {

    @MainActor static let shipSwiftEntries: [ComponentMeta] = [
        // MARK: 微交互 8 个（#250）
        ComponentMeta(id: "effect-shake", name: ".shake(trigger:)", description: "trigger 值变化时左右抖动；承载「输入错误」这类状态语义，a11y 通告由调用方提供", category: .effect) {
            MicroInteractionDemo(label: "抖一下", symbol: "exclamationmark.triangle.fill") { view, fire in
                view.shake(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-jump", name: ".jump(trigger:)", description: "trigger 值变化时上跳并带 squash / stretch；Reduce Motion 下降级为无位移", category: .effect) {
            MicroInteractionDemo(label: "跳一下", symbol: "arrow.up.circle.fill") { view, fire in
                view.jump(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-spin", name: ".spin(trigger:)", description: "trigger 值变化时单次整圈旋转，方向由 SpinDirection 决定（不是 clockwise: Bool）", category: .effect) {
            MicroInteractionDemo(label: "转一圈", symbol: "arrow.triangle.2.circlepath") { view, fire in
                view.spin(trigger: fire, direction: .counterClockwise)
            }
        },
        ComponentMeta(id: "effect-ping", name: ".ping(trigger:)", description: "trigger 值变化时在内容背后扩散同心圆环；装饰层已 accessibilityHidden(true)", category: .effect) {
            MicroInteractionDemo(label: "扩散一次", symbol: "dot.radiowaves.left.and.right") { view, fire in
                view.ping(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-spray", name: ".spray(trigger:symbol:)", description: "trigger 值变化时喷出 SF Symbol 粒子；colors 空数组时全取调用方 .tint，这里给了彩虹色板", category: .effect) {
            MicroInteractionDemo(label: "喷一次", symbol: "sparkle") { view, fire in
                view.spray(trigger: fire, symbol: "sparkle", strength: .pronounced, colors: GalleryPalette.festive)
            }
        },
        ComponentMeta(id: "effect-rise", name: ".rise(trigger:text:)", description: "trigger 值变化时浮起一段文字；text 是 LocalizedStringKey（公约 B 类）", category: .effect) {
            MicroInteractionDemo(label: "+1", symbol: "star.fill") { view, fire in
                view.rise(trigger: fire, text: "+1")
            }
        },
        ComponentMeta(id: "effect-haptic", name: ".haptic(_:trigger:)", description: "对 sensoryFeedback 的薄封装，提升可发现性；⚠️ 模拟器上没有触感硬件，只能在真机上感知", category: .effect) {
            MicroInteractionDemo(label: "触感（真机可感）", symbol: "iphone.radiowaves.left.and.right") { view, fire in
                view.haptic(.success, trigger: fire)
            }
        },
        ComponentMeta(id: "effect-shine", name: ".shine(trigger:)", description: "trigger 值变化时一道高光扫过内容形状；高光色取 Color.specularHighlight 而非写死白色", category: .effect) {
            MicroInteractionDemo(label: "扫一道光", symbol: "sparkles") { view, fire in
                view.shine(trigger: fire)
            }
        },

        // MARK: 转场簇 A · 滤镜类 4 种（#266）
        ComponentMeta(id: "effect-transition-blur", name: "Transition .blur", description: "进出时内容失焦并淡出；hasMotion == false，无位移", category: .effect) {
            TransitionDemo(transition: .blur)
        },
        ComponentMeta(id: "effect-transition-film-exposure", name: "Transition .filmExposure", description: "像一格胶片被过度曝光：亮度冲高、饱和度与对比度洗白", category: .effect) {
            TransitionDemo(transition: .filmExposure)
        },
        ComponentMeta(id: "effect-transition-snapshot", name: "Transition .snapshot", description: "像即显相纸：一下快门白场，随后从低对比逐渐显影", category: .effect) {
            TransitionDemo(transition: .snapshot)
        },
        ComponentMeta(id: "effect-transition-flicker", name: "Transition .flicker", description: "像接触不良的灯管忽明忽暗；频率钉在 WCAG 的 3 次/秒线下", category: .effect) {
            TransitionDemo(transition: .flicker)
        },

        // MARK: 转场簇 B · 3D 与弹性 6 种（#267）
        ComponentMeta(id: "effect-transition-flip", name: "Transition .flip", description: "卡片翻面：带透视的 3D 旋转（两端 ±90°）+ 淡入淡出", category: .effect) {
            TransitionDemo(transition: .flip)
        },
        ComponentMeta(id: "effect-transition-rotate3d", name: "Transition .rotate3D", description: "绕任意轴翻滚并向纵深退一点；默认 75°，与 flip 钉死的 90° 有意错开", category: .effect) {
            TransitionDemo(transition: .rotate3D)
        },
        ComponentMeta(id: "effect-transition-swoosh", name: "Transition .swoosh", description: "穿行转场：从 edge 进、朝对侧出，途中带动态模糊与沿运动方向的拉伸", category: .effect) {
            TransitionDemo(transition: .swoosh)
        },
        ComponentMeta(id: "effect-transition-boing", name: "Transition .boing", description: "弹性缩放：从小放大、越过原尺寸再回落坐定", category: .effect) {
            TransitionDemo(transition: .boing(strength: .pronounced))
        },
        ComponentMeta(id: "effect-transition-skid", name: "Transition .skid", description: "刹车打滑：从 edge 滑进来、冲过头再刹住，车身跟着甩一个小角度", category: .effect) {
            TransitionDemo(transition: .skid)
        },
        ComponentMeta(id: "effect-transition-move", name: "Transition .move（极坐标）", description: "沿任意极角平移进出；与 SwiftUI 自带的 .move(edge:) 是重载而非覆盖", category: .effect) {
            TransitionDemo(transition: .move(angle: .degrees(-45), distance: 60))
        },

        // MARK: 转场簇 C · mask reveal 6 种（#268）
        ComponentMeta(id: "effect-transition-iris", name: "Transition .iris", description: "圆形光圈从 anchor 向外张开，半径自动取到最远角", category: .effect) {
            TransitionDemo(transition: .iris)
        },
        ComponentMeta(id: "effect-transition-wipe", name: "Transition .wipe", description: "一条直边沿指定角度扫过（默认 0°，左→右）", category: .effect) {
            TransitionDemo(transition: .wipe)
        },
        ComponentMeta(id: "effect-transition-blinds", name: "Transition .blinds", description: "若干条横向百叶各自从自己的中线向上下张开，默认 8 条", category: .effect) {
            TransitionDemo(transition: .blinds)
        },
        ComponentMeta(id: "effect-transition-clock", name: "Transition .clock", description: "扇形扫针从 12 点扫一圈，方向由 SpinDirection 决定", category: .effect) {
            TransitionDemo(transition: .clock)
        },
        ComponentMeta(id: "effect-transition-glare", name: "Transition .glare", description: "斜掠的直边扫过（默认 35°），揭示边上骑一条柔光带", category: .effect) {
            TransitionDemo(transition: .glare)
        },
        ComponentMeta(id: "effect-transition-dissolve", name: "Transition .dissolve", description: "网格逐格按确定性伪随机次序浮现，默认格边长 24pt", category: .effect) {
            TransitionDemo(transition: .dissolve)
        },

        // MARK: 庆祝与处理中 4 个（#252）
        ComponentMeta(id: "effect-confetti", name: ".confetti(trigger:)", description: "trigger 值变化时喷发一次彩纸；后台不画、低电量减半（NFR-7）", category: .effect) {
            ConfettiDemo()
        },
        ComponentMeta(id: "effect-scanning-overlay", name: "ScanningOverlay", description: "上下往复的扫描光带，表示「正在识别 / 处理」；常驻渲染，受能耗闸管辖", category: .effect) {
            ScanningOverlayDemo()
        },
        ComponentMeta(id: "effect-glow-sweep", name: "GlowSweep", description: "沿内容轮廓环绕的辉光扫针；低电量下不画辉光（policy.usesGlow）", category: .effect) {
            GlowSweepDemo()
        },
        ComponentMeta(id: "effect-light-sweep", name: "LightSweep", description: "横向往复的柔光带，表示「后台仍在工作」", category: .effect) {
            LightSweepDemo()
        },

        // MARK: 文本与展示 4 个（#253）
        ComponentMeta(id: "effect-typewriter-text", name: "TypewriterText", description: "逐字打字机；两个 init 分别收 LocalizedStringResource 与 verbatim 流式文本", category: .effect) {
            TypewriterTextDemo()
        },
        ComponentMeta(id: "effect-animated-mesh-gradient", name: "AnimatedMeshGradient", description: "MeshGradient 控制点缓慢漂移；colors 默认空数组 ⇒ 取语义 token", category: .effect) {
            AnimatedMeshGradientDemo()
        },
        ComponentMeta(id: "effect-before-after-slider", name: "BeforeAfterSlider", description: "拖动分隔线对比两张内容；labels 是语义枚举（.shown / .hidden），不是 Bool", category: .effect) {
            BeforeAfterSliderDemo()
        },
        ComponentMeta(id: "effect-particle-transition", name: "Transition .particle", description: "进出时内容轻微缩放淡出、一圈粒子向外飞散", category: .effect) {
            TransitionDemo(transition: .particle)
        },

        // MARK: 跨平台改造 4 个（#254）
        ComponentMeta(id: "effect-orbiting-logos", name: "OrbitingLogos", description: "环形轨道上的点阵与 logo；上游用 SpriteKit，本仓重写为纯 SwiftUI（AD-E）", category: .effect) {
            OrbitingLogosDemo()
        },
        ComponentMeta(id: "effect-dot-sphere", name: "DotSphere", description: "自转的点阵球；上游 import UIKit，本仓重写为跨平台 Canvas（AD-E）", category: .effect) {
            DotSphereDemo()
        },
        ComponentMeta(id: "effect-char-sphere", name: "CharSphere", description: "自转的字符球，字形由确定性散列分配（不是 Int.random）", category: .effect) {
            CharSphereDemo()
        },
        ComponentMeta(id: "effect-full-screen-button", name: "FullScreenButton", description: "点开为全屏详情；zoom 转场是 iOS-only，其它平台按 FullScreenTransitionPlan 降级（AD-E）", category: .effect) {
            FullScreenButtonDemo()
        },

        // MARK: 四个图表（#255）
        ComponentMeta(id: "chart-radar", name: "RadarChart", description: "多维雷达图；轴少于 3 条 / 含非有限值时渲染空态而不是 crash（AD-F）", category: .chart) {
            RadarChartDemo()
        },
        ComponentMeta(id: "chart-ring", name: "RingChart", description: "同心活动环；goal ≤ 0 或非有限时渲染空态，建议环数上限 6", category: .chart) {
            RingChartDemo()
        },
        ComponentMeta(id: "chart-activity-heatmap", name: "ActivityHeatmap", description: "贡献热力图；日期归一化由注入的 Calendar 决定，上限 1830 天", category: .chart) {
            ActivityHeatmapDemo()
        },
        ComponentMeta(id: "chart-network-graph", name: "NetworkGraph", description: "力导向关系图；超过 150 节点 / 600 边时截断 + 降级 + 标注，不抛断言（AD-F）", category: .chart) {
            NetworkGraphDemo()
        },
    ]
}

// MARK: - 画廊场景色板
//
// ⚠️ **色板住在画廊、不住在库里**：`ParticleTransition` 的文件头逐字写着
// 「不给彩虹默认色板——那是品牌决定」，`Confetti` / `Spray` / `DotSphere` /
// `RingChart` 同族，`colors: []` 一律退回调用方的单一 `.tint`。
// ⇒ 「彩纸是单色的」不是库的缺陷，是画廊一直没给色。
private enum GalleryPalette {
    /// 庆祝类（彩纸 / 喷洒 / 粒子）。彩虹序，冷暖交替避免相邻两色糊在一起。
    static let festive: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
    /// 活动三环。对应「活动 / 锻炼 / 站立」三个**互相独立的量**，不是同一量的三档深浅。
    static let activityRings: [Color] = [.pink, .green, .cyan]
    /// 多品牌轨道 / 字符球这类「一堆同级实体」。
    static let entities: [Color] = [.orange, .teal, .indigo, .pink, .green]
}

// MARK: - Component Previews

private struct ButtonPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Button("Solid") {}.buttonStyle(.solid(role: .primary))
            Button("Light") {}.buttonStyle(.light(role: .primary))
            Button("Borderless") {}.buttonStyle(.borderless(role: .primary))
        }
    }
}

private struct FormIconsPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            LabelIcon(systemName: "person.fill", backgroundColor: .blue)
            LabelIcon(systemName: "star.fill", backgroundColor: .yellow)
            ChevronRightIcon()
            DangerIcon()
        }
    }
}

private struct SegmentedControlPreview: View {
    let items = ["One", "Two", "Three"]
    @State private var selection = "One"
    @State private var plainSelection = "One"
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Text(verbatim: "GlassSegmentedControlStyle（默认；iOS 上是原生 UISegmentedControl）")
                .coreFont(.caption)
                .foregroundStyle(.secondary)
            SegmentedControl(items: self.items, selection: self.$selection, title: { $0 })

            Text(verbatim: "PlainSegmentedControlStyle（全平台走 SwiftUI 回退 + matchedGeometryEffect）")
                .coreFont(.caption)
                .foregroundStyle(.secondary)
            SegmentedControl(items: self.items, selection: self.$plainSelection, title: { $0 })
                .segmentedControlStyle(PlainSegmentedControlStyle())
        }
    }
}

private struct SearchFieldPreview: View {
    @State private var text = "filter results"
    var body: some View { SearchField(text: self.$text) }
}

private let sizeLadder: [(String, ControlSize)] = [
    ("mini", .mini), ("small", .small), ("regular", .regular), ("large", .large), ("extraLarge", .extraLarge),
]

private struct SizeLadderRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            Text(verbatim: self.label)
                .coreFont(.caption)
                .foregroundStyle(Color.contentSecondary)
                .frame(width: 72, alignment: .leading)
            self.content()
        }
    }
}

private struct BadgePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            HStack(spacing: CoreSpacing.sm) {
                Badge("Info", variant: .info)
                Badge("Success", variant: .success)
                Badge("Warning", variant: .warning)
                Badge("Danger", variant: .danger)
                Badge("Neutral")
            }
            ForEach(sizeLadder, id: \.0) { label, size in
                SizeLadderRow(label: label) {
                    Badge("Beta", variant: .info)
                    Badge("Draft", variant: .warning, outlined: true)
                }
                .controlSize(size)
            }
        }
    }
}

private struct TagPreview: View {
    @State private var removedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            HStack(spacing: CoreSpacing.md) {
                Tag("removable", color: .blue, removable: true, onRemove: { self.removedCount += 1 })
                Text(verbatim: "Removed: \(self.removedCount)")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentSecondary)
                    .accessibilityIdentifier("tag-removed-count")
            }
            HStack(spacing: CoreSpacing.sm) {
                Tag("bug", color: .red)
                Tag("enhancement", color: .blue)
                Tag("good first issue", color: .purple)
                Tag("doc", color: .cyan, removable: true, onRemove: {})
            }
            ForEach(sizeLadder, id: \.0) { label, size in
                SizeLadderRow(label: label) {
                    Tag("bug", color: .red)
                    Tag("doc", color: .cyan, removable: true, onRemove: {})
                }
                .controlSize(size)
            }
        }
    }
}

private struct TagGroupPreviewItem: Identifiable, Hashable {
    let id: String
}

private struct TagGroupPreview: View {
    @State private var single: Set<String> = ["Weekly"]
    @State private var multiple: Set<String> = ["Swift", "Rust"]
    @State private var withDisabled: Set<String> = ["Go"]
    @State private var accented: Set<String> = ["Design"]
    @State private var sized: Set<String> = ["On"]
    @State private var mutable: [TagGroupPreviewItem] = ["Alpha", "Bravo", "Charlie", "Delta"].map(TagGroupPreviewItem.init(id:))
    @State private var mutableSelection: Set<String> = ["Bravo"]
    // 单调递增，不用 count —— 「加、删中间、再加」会让 count + 1 撞出两个同名 ID，
    // 而 TagGroup 的契约要求 data 内 ID 唯一。
    @State private var mutableSerial = 0

    private let ranges = ["Daily", "Weekly", "Monthly", "Yearly"].map(TagGroupPreviewItem.init(id:))
    private let languages = ["Swift", "Kotlin", "Rust", "TypeScript", "Python"].map(TagGroupPreviewItem.init(id:))
    private let platforms = ["iOS", "macOS", "Go", "watchOS"].map(TagGroupPreviewItem.init(id:))
    private let teams = ["Design", "Engineering", "Research"].map(TagGroupPreviewItem.init(id:))
    private let toggles = ["On", "Off"].map(TagGroupPreviewItem.init(id:))

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            self.row("none") {
                TagGroup(self.languages, selection: .constant(["Swift"]), selectionMode: .none, color: .contentPrimary) {
                    Text($0.id)
                }
            }
            self.row("single") {
                TagGroup(self.ranges, selection: self.$single, selectionMode: .single, color: .contentPrimary) {
                    Text($0.id)
                }
                Text(verbatim: "Selected: \(self.single.sorted().joined(separator: ", "))")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentSecondary)
                    .accessibilityIdentifier("tag-group-single-selection")
            }
            self.row("multiple") {
                TagGroup(self.languages, selection: self.$multiple, color: .contentPrimary) {
                    Text($0.id)
                }
            }
            self.row("disabled") {
                TagGroup(self.platforms, selection: self.$withDisabled, disabled: ["Go", "watchOS"], color: .contentPrimary) {
                    Text($0.id)
                }
            }
            self.row("coreAccent(.blue)") {
                TagGroup(self.teams, selection: self.$accented, color: .contentPrimary) {
                    Text($0.id)
                }
                .coreAccent(.blue)
            }
            self.row("增删转场") {
                TagGroup(self.mutable, selection: self.$mutableSelection, color: .contentPrimary) {
                    Text($0.id)
                }
                HStack(spacing: CoreSpacing.sm) {
                    Button {
                        self.mutableSerial += 1
                        self.mutable.append(TagGroupPreviewItem(id: "tag\(self.mutableSerial)"))
                    } label: {
                        Text(verbatim: "Append")
                    }
                    .buttonStyle(.light())
                    .accessibilityIdentifier("tag-group-append")

                    Button {
                        guard self.mutable.count > 1 else { return }
                        self.mutable.remove(at: self.mutable.count / 2)
                    } label: {
                        Text(verbatim: "Remove middle")
                    }
                    .buttonStyle(.light())
                    .accessibilityIdentifier("tag-group-remove-middle")
                }
            }
            ForEach(sizeLadder, id: \.0) { label, size in
                SizeLadderRow(label: label) {
                    TagGroup(self.toggles, selection: self.$sized, color: .contentPrimary) {
                        Text($0.id)
                    }
                }
                .controlSize(size)
            }
        }
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            Text(verbatim: title)
                .coreFont(.caption)
                .foregroundStyle(Color.contentSecondary)
            content()
        }
    }
}

private struct BannerPreview: View {
    @State private var dismissed: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: CoreSpacing.sm) {
                Banner(level: .info) { Text("Info message") }
                Banner(level: .success) { Text("Success message") }
                Banner(level: .warning) { Text("Warning message") }
                Banner(level: .danger) { Text("Danger message") }
                Banner(level: .neutral) { Text("Neutral message") }
                self.fullBanner(id: "plain-info", level: .info, style: PlainBannerStyle())
                self.fullBanner(id: "plain-neutral", level: .neutral, style: PlainBannerStyle())
                self.fullBanner(id: "bordered-danger", level: .danger, style: BorderedBannerStyle())
                self.fullBanner(id: "bordered-neutral", level: .neutral, style: BorderedBannerStyle())
                Banner(level: .info) { Text("Info bordered") }
                    .bannerStyle(BorderedBannerStyle())
                if !self.dismissed.isEmpty {
                    Button("Restore dismissed banners") { self.dismissed.removeAll() }
                        .buttonStyle(.borderless(role: .primary))
                }
            }
            .padding(.vertical, CoreSpacing.lg)
        }
    }

    @ViewBuilder
    private func fullBanner(id: String, level: StatusLevel, style: some BannerStyle) -> some View {
        if !self.dismissed.contains(id) {
            Banner(level: level, title: "Update available", message: "Restart the app to finish installing version 2.4.") {
                Button("Restart now") {}
                    .buttonStyle(.solid(role: level == .danger ? .danger : .primary))
                    .controlSize(.small)
                Button("Later") {}
                    .buttonStyle(.borderless(role: .primary))
                    .controlSize(.small)
            } onDismiss: {
                self.dismissed.insert(id)
            }
            .bannerStyle(style)
        }
    }
}

private struct BannerLevelsPreview: View {
    enum Backdrop {
        case canvas
        case card
    }

    let backdrop: Backdrop

    private static let levels: [(StatusLevel, String)] = [
        (.info, "Info message"),
        (.success, "Success message"),
        (.warning, "Warning message"),
        (.danger, "Danger message"),
        (.neutral, "Neutral message"),
    ]

    var body: some View {
        switch self.backdrop {
        case .canvas:
            self.stack
        case .card:
            self.stack
                .padding(CoreSpacing.md)
                .background(Color.surfaceBase, in: CoreShape.rounded(CoreRadius.large))
        }
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            self.group("Plain") {
                ForEach(Self.levels, id: \.1) { level, text in
                    Banner(level: level) { Text(verbatim: text) }
                }
            }
            self.group("Bordered") {
                ForEach(Self.levels, id: \.1) { level, text in
                    Banner(level: level) { Text(verbatim: text) }
                }
                .bannerStyle(BorderedBannerStyle())
            }
        }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            Text(verbatim: title)
                .coreFont(.caption)
                .foregroundStyle(Color.contentSecondary)
            content()
        }
    }
}

private struct SizeSystemPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            ForEach(sizeLadder, id: \.0) { label, size in
                SizeLadderRow(label: label) {
                    Avatar(name: "Evan").clipShape(Circle())
                    Text(verbatim: "Evan")
                        .coreFont(CoreControlMetrics.compactFontToken(for: size))
                        .foregroundStyle(Color.contentPrimary)
                    Badge("Pro", variant: .success)
                    Tag("design", color: .blue, removable: true, onRemove: {})
                }
                .controlSize(size)
            }
        }
    }
}

private struct AnchoredBadgePreview: View {
    @State private var count = 9

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xxl) {
            HStack(spacing: CoreSpacing.xxl) {
                Image(systemName: "bell.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.count(self.count, max: 999))
                Button("−1") { self.count -= 1 }
                Button("+1") { self.count += 1 }
                Button("9") { self.count = 9 }
                Button("99") { self.count = 99 }
            }
            .buttonStyle(.light())
            HStack(spacing: CoreSpacing.xxl) {
                self.avatar("Evan", side: CoreSpacing.xxxxl)
                    .anchoredBadge(.dot, hostShape: .circle)
                self.avatar("Aurora", side: CoreSpacing.xxxxl)
                    .anchoredBadge(.count(120, max: 99), hostShape: .circle)
                self.avatar("Design", side: CoreSpacing.xxxxl)
                    .anchoredBadge(.count(3), placement: .bottomTrailing, hostShape: .circle)
                self.avatar("OhMyDesign", side: CoreSpacing.huge)
                    .anchoredBadge(.text("NEW"), hostShape: .circle)
            }
            HStack(spacing: CoreSpacing.xxl) {
                Image(systemName: "bell.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.dot)
                Image(systemName: "envelope.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.count(7))
                Image(systemName: "tray.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.count(0))
                Image(systemName: "gift.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.text("NEW"), placement: .topLeading)
                Image(systemName: "message.fill")
                    .font(.title)
                    .foregroundStyle(Color.contentSecondary)
                    .anchoredBadge(.count(120))
            }
        }
        .padding(CoreSpacing.lg)
    }

    private func avatar(_ name: String, side: CGFloat) -> some View {
        Avatar(name: name, size: .fixed(side))
            .clipShape(Circle())
    }
}

private struct AvatarPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            ForEach(sizeLadder, id: \.0) { label, size in
                SizeLadderRow(label: label) {
                    Avatar(name: "Evan").clipShape(Circle())
                    Avatar(name: "OhMyDesign").clipShape(Circle())
                    AvatarGroup {
                        Avatar(name: "Ada")
                        Avatar(name: "Linus")
                        Avatar(name: "Grace")
                        Avatar(name: "Alan")
                    }
                }
                .controlSize(size)
            }
            SizeLadderRow(label: ".fixed(64)") {
                Avatar(name: "Evan", size: .fixed(64)).clipShape(Circle())
            }
        }
    }
}

private struct ListRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ListRow(label: { Text("Full row").foregroundStyle(Color.contentPrimary) })
            ListRow(
                leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
                label: { Text("With icon").foregroundStyle(Color.contentPrimary) },
                trailing: { Image(systemName: "chevron.forward").foregroundStyle(Color.contentMuted) }
            )
        }
    }
}

private struct UnderlinedTabBarPreview: View {
    let items = ["Tab 1", "Tab 2", "Tab 3"]
    @State private var selection = "Tab 1"
    var body: some View {
        UnderlinedTabBar(items: self.items, selection: self.$selection, title: { $0 })
    }
}

// MARK: - ToastLevelPreview

private struct ToastLevelPreview: View {
    @Environment(\.toastHost) private var toast

    private let levels: [(label: String, level: StatusLevel)] = [
        ("Info", .info),
        ("Success", .success),
        ("Warning", .warning),
        ("Danger", .danger),
        ("Neutral", .neutral),
    ]

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Toast 通过 `.toastHost(edge:)` modifier 挂载到 WindowGroup 根级别")
                .font(CoreTypography.Token.footnote.font)
                .foregroundStyle(Color.contentMuted)
            FlowLayout(spacing: CoreSpacing.sm) {
                ForEach(self.levels, id: \.label) { entry in
                    Button(entry.label) {
                        self.toast?.show("\(entry.label) message", level: entry.level)
                    }
                    .buttonStyle(.light(role: .secondary))
                    .controlSize(.small)
                }
            }
            FlowLayout(spacing: CoreSpacing.sm) {
                Button("Description + action") {
                    self.toast?.show(ToastPreviewSamples.archived(duration: .seconds(5)))
                }
                Button("Persistent") {
                    self.toast?.show(ToastPreviewSamples.archived(duration: .persistent))
                }
                Button("Dismiss all") {
                    self.toast?.dismissAll()
                }
            }
            .buttonStyle(.light(role: .secondary))
            .controlSize(.small)
        }
    }
}

// MARK: - ToastRichPreview

private enum ToastPreviewSamples {
    static func archived(duration: ToastDuration) -> ToastItem {
        ToastItem(
            title: "Conversation archived",
            description: "It moves back to the inbox if you undo within a few seconds.",
            level: .neutral,
            duration: duration,
            action: ToastAction("Undo") {}
        )
    }

    static func danger() -> ToastItem {
        ToastItem(title: "Connection interrupted", level: .danger, duration: .persistent)
    }
}

private struct ToastRichPreview: View {
    let presentation: ToastPresentation
    var sample: ToastItem = ToastPreviewSamples.archived(duration: .persistent)

    var body: some View {
        ToastRichPreviewContent(sample: self.sample)
            .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
            .toastHost(edge: .top, presentation: self.presentation)
    }
}

private struct ToastRichPreviewContent: View {
    let sample: ToastItem
    @Environment(\.toastHost) private var toast

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Persistent toast with title, description and action.")
                .font(CoreTypography.Token.footnote.font)
                .foregroundStyle(Color.contentMuted)
            Button("Show again") {
                self.toast?.dismissAll()
                self.toast?.show(ToastItem(
                    title: self.sample.title, description: self.sample.description,
                    level: self.sample.level, duration: .persistent, action: self.sample.action
                ))
            }
            .buttonStyle(.light(role: .secondary))
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { self.toast?.show(self.sample) }
    }
}

// MARK: - ToastDemoButton

/// Subview to read `\.toastHost` inside the scope where `.toastHost(edge:)` is applied.
/// Referenced by `ComponentMeta.all` via `demoAction` closure.
private struct ToastDemoButton: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        Button("Show Demo Toast") {
            self.toast?.show("Toast message", level: .info)
        }
        .buttonStyle(.solid(role: .primary))
    }
}

// MARK: - Phase 2 Container Previews

private struct CardPreview: View {
    @State private var sheetDemo: CardSheetDemo?

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(Color.contentSecondary)
                }
            }
            Card(padding: CoreSpacing.md, alignment: .center) {
                Text("居中 + 紧凑内边距").coreFont(.subheadline)
            }
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("外层 Card：raised").coreFont(.headline)
                    Card {
                        #if os(macOS)
                        Text("内层 Card：elevated，无投影，保留描边").coreFont(.subheadline)
                        #else
                        Text("内层 Card：elevated，无投影、无描边").coreFont(.subheadline)
                        #endif
                    }
                    Card(kind: .grouped) {
                        Text("内层 grouped：elevated").coreFont(.subheadline)
                    }
                    Button("系统 sheet（无预设，挂在外层 Card 内）") {
                        self.sheetDemo = .plain
                    }
                    .buttonStyle(.solid(role: .secondary))
                    .sheet(item: self.$sheetDemo) { demo in
                        CardSheetContent(demo: demo)
                            .cardSheetPreset(demo)
                            .presentationDetents([.medium, .large])
                    }
                }
            }
            HStack(spacing: CoreSpacing.sm) {
                Button("预设 .system") { self.sheetDemo = .system }
                    .buttonStyle(.solid(role: .primary))
                Button("预设 .raised") { self.sheetDemo = .raised }
                    .buttonStyle(.solid(role: .primary))
            }
        }
    }
}

private enum CardSheetDemo: String, Identifiable {
    case plain
    case system
    case raised

    var id: String { self.rawValue }
}

private extension View {
    @ViewBuilder
    func cardSheetPreset(_ demo: CardSheetDemo) -> some View {
        switch demo {
        case .plain: self
        case .system: self.coreSheetPresentation(background: .system)
        case .raised: self.coreSheetPresentation(background: .raised)
        }
    }
}

private struct CardSheetContent: View {
    let demo: CardSheetDemo

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Text("Sheet：\(self.demo.rawValue)").coreFont(.headline)
            Text(self.demo == .plain
                ? "无预设：层级从宿主继承（挂在外层 Card 内）。"
                : "coreSheetPresentation：内容层级为 raised。")
                .coreFont(.subheadline)
                .foregroundStyle(Color.contentSecondary)
            Card {
                Text("Sheet 内的 Card").coreFont(.subheadline)
            }
        }
        .padding(CoreSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SeparatorPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Text("贯穿").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator()
            Text("leading 缩进（58pt，对齐设置行标题）").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator(inset: .leading(58))
        }
    }
}

private struct SectionHeaderFooterPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            SectionHeader("General")
            Card { Text("分组内容").coreFont(.body) }
            SectionFooter("Applies to all accounts on this device.")
        }
    }
}

private struct SettingsRowPreview: View {
    @State private var on = true
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: .init(systemName: "wifi", background: .blue),
                title: "Wi-Fi",
                subtitle: "HomeNetwork"
            ) {
                Text("On").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(58))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: "Notifications"
            ) {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .tint(.green)
        }
        .background(Color.surfaceCard)
        .clipShape(CoreShape.rounded(CoreRadius.medium))
    }
}

private struct InsetGroupedSectionPreview: View {
    @State private var airplane = false
    var body: some View {
        InsetGroupedSection(header: "Connectivity", footer: "Airplane Mode disables Wi-Fi and Bluetooth.") {
            SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
            }
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
        }
        .tint(.green)
    }
}

private struct CoreCircularProgressViewPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            HStack(spacing: CoreSpacing.xl) {
                ForEach([0.0, 0.25, 0.6, 1.0], id: \.self) { value in
                    ProgressView(value: value, label: { EmptyView() }, currentValueLabel: { Text(value, format: .percent) })
                        .progressViewStyle(.coreCircular)
                }
            }
            HStack(spacing: CoreSpacing.xl) {
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).controlSize(.small)
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).tint(.red)
                ProgressView(value: 0.6).progressViewStyle(.coreCircular).controlSize(.large)
                ProgressView().progressViewStyle(.coreCircular)
            }
        }
    }
}

private struct PressableButtonStylesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            InsetGroupedSection(header: ".pressableRow", footer: "第二行为禁用态。") {
                Button {} label: {
                    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                        Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                }
                .buttonStyle(.pressableRow)
                Button {} label: {
                    SettingsRow(icon: .init(systemName: "lock.fill", background: .gray), title: "Passcode") {
                        SettingsRowChevron()
                    }
                }
                .buttonStyle(.pressableRow)
                .disabled(true)
            }
            Text(".pressableCard").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Button {} label: {
                Card {
                    VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                        Text("Weekly report").coreFont(.headline)
                        Text("Tap to open the detail").foregroundStyle(Color.contentSecondary)
                    }
                }
            }
            .buttonStyle(.pressableCard)
        }
    }
}

private struct CoreProgressViewPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                .progressViewStyle(.core)
            ProgressView(value: 0.6)
                .progressViewStyle(.core)
                .tint(.red)
        }
    }
}

private struct CoreLabelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Label("Sync", systemImage: "arrow.triangle.2.circlepath").labelStyle(.core)
            Label("Delete", systemImage: "trash.fill").labelStyle(.core).tint(.red)
        }
    }
}

private struct CoreDisclosureGroupPreview: View {
    @State private var expanded = true
    var body: some View {
        DisclosureGroup("Details", isExpanded: self.$expanded) {
            Text("Additional information goes here.").foregroundStyle(Color.contentSecondary)
        }
        .disclosureGroupStyle(.core)
        .tint(.red)
    }
}

// MARK: - SettingsRow in native List（AC9 验证）

/// SettingsRow 直接作原生 List 的行,配 .listRowInsets(EdgeInsets()) 清零 List 侧
/// inset,由 SettingsRow 独占 16pt 内边距——验证无双重 inset。
private struct SettingsRowInListDemo: View {
    @State private var on = true
    var body: some View {
        List {
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            .listRowInsets(EdgeInsets())
            SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .listRowInsets(EdgeInsets())
            .tint(.green)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Settings Screen Demo（Success Criteria #10）

/// 仅用 OhMyDesign 组件复刻一屏 iOS 设置页——不写任何 OhMyDesign 之外的样式代码。
private struct SettingsScreenDemo: View {
    @State private var airplane = false
    @State private var wifiOn = true
    @State private var bluetoothOn = true
    @State private var notificationsOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: CoreSpacing.xl) {
                InsetGroupedSection {
                    SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                        Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                        Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "personalhotspot", background: .green), title: "Personal Hotspot") {
                        Text("Off").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                }

                InsetGroupedSection(header: "Notifications", footer: "Choose how you receive alerts from apps.") {
                    SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
                        Toggle("Notifications", isOn: self.$notificationsOn).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "speaker.wave.2.fill", background: .pink), title: "Sounds & Haptics") {
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "moon.fill", background: .indigo), title: "Focus", subtitle: "Do Not Disturb") {
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: "Version") {
                        Text("0.4.0").foregroundStyle(Color.contentSecondary)
                    }
                    SettingsRow(title: "Legal") {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}

// MARK: - Phase 3 Previews（semi-mobile-components epic，0.7.0）

private struct FloatButtonPreview: View {
    var body: some View {
        ZStack {
            // 悬浮按钮的意义是「浮在内容之上」，底衬要像真实内容而不是一块纯色。
            LinearGradient(colors: [.teal, .green, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(CoreShape.rounded(CoreRadius.medium))

            HStack(spacing: CoreSpacing.lg) {
                Button {} label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.extendedFloat(size: .regular))
                .foregroundStyle(.white)

                Button {} label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                }
                .buttonStyle(.circularGlass(size: .regular))
                .foregroundStyle(.white)
            }
            .padding(CoreSpacing.xl)
        }
    }
}

private struct RatingPreview: View {
    @State private var value: Double = 3.5
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Rating(value: self.$value, step: 0.5)
            Rating(value: .constant(4))
                .disabled(true)
        }
        // 评分星现实里一律是琥珀 / 金色，不是 App 强调色。星形填充走 `.tint`。
        .tint(.orange)
    }
}

private struct RatingDisplayPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            RatingDisplay(value: 4)
            RatingDisplay(value: 3.5)
        }
        .tint(.orange)
    }
}

private struct PinCodePreview: View {
    @State private var code = "12"
    var body: some View {
        PinCode(value: self.$code, length: 6)
    }
}

private struct RadioGroupPreview: View {
    @State private var selection = "pro"
    @State private var accepted = false

    private let options = [
        RadioOption(value: "basic", title: "Basic"),
        RadioOption(value: "pro", title: "Pro"),
        RadioOption(value: "enterprise", title: "Enterprise"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            RadioGroup(selection: self.$selection, options: self.options)
            Toggle("Accept terms", isOn: self.$accepted)
                .toggleStyle(CheckBoxToggleStyle())
            Separator()
            Toggle("Disabled, on", isOn: .constant(true))
                .toggleStyle(CheckBoxToggleStyle())
                .disabled(true)
            Toggle("Disabled, off", isOn: .constant(false))
                .toggleStyle(CheckBoxToggleStyle())
                .disabled(true)
            RadioGroup(selection: .constant("pro"), options: self.options)
                .disabled(true)
        }
    }
}

private struct TagInputPreview: View {
    @State private var tags: [String] = ["bug", "enhancement"]
    @State private var mutable: [String] = ["alpha", "bravo", "charlie", "delta", "echo"]
    @State private var mutableSerial = 0
    var body: some View {
        // Phase 3 / #173 视觉复查发现：默认 tagColor（.contentSecondary）经 Tag 的
        // `.opacity(0.12)` 背景公式，在暗色纯黑画布上对比度接近不可辨——这是 Tag 既有
        // 公式对中性色的固有表现，不是本次改动引入的缺陷（组件默认值本身不在本任务改动
        // 范围内）。画廊演示改用更有辨识度的 .blue，让暗色变体清晰可读；调用方仍可自由
        // 传入任意颜色，含中性色。
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            TagInput(tags: self.$tags, placeholder: "Add tag", tagColor: .blue)

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "增删转场（稳定 chip 身份）")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentSecondary)
                TagInput(tags: self.$mutable, placeholder: "Add tag", tagColor: .blue)
                HStack(spacing: CoreSpacing.sm) {
                    Button {
                        self.mutableSerial += 1
                        self.mutable.append("tag\(self.mutableSerial)")
                    } label: {
                        Text(verbatim: "Append")
                    }
                    .buttonStyle(.light())
                    .accessibilityIdentifier("tag-input-append")

                    Button {
                        guard self.mutable.count > 1 else { return }
                        self.mutable.remove(at: self.mutable.count / 2)
                    } label: {
                        Text(verbatim: "Remove middle")
                    }
                    .buttonStyle(.light())
                    .accessibilityIdentifier("tag-input-remove-middle")
                }
            }
        }
    }
}

private struct FormFieldPreview: View {
    @State private var name = ""
    @State private var email = "jane@"
    @State private var team = "Design"
    @State private var city = ""
    @State private var postalCode = "950"
    @State private var host = "example"
    @State private var port = "80800"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            FormField("Full name", description: "Shown on your public profile.") {
                TextField("Jane Appleseed", text: self.$name)
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            .fieldRequirement(.required)

            FormField("Email", description: "We never share your address.") {
                TextField("you@example.com", text: self.$email)
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            .fieldRequirement(.required)
            .fieldValidation(self.emailValidation)

            FormField("Password") {
                SecureField("Password", text: .constant("abc"))
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            .fieldValidation(.invalid("Use at least 12 characters, including a number and a symbol, and avoid words that appear in your name or email address."))

            FormField("Team", description: "Managed by your administrator.") {
                TextField("Team", text: self.$team)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.contentDisabled)
                    .fieldAccessibility()
            }
            .fieldValidation(.invalid("Disabled wins over invalid."))
            .disabled(true)

            Text(verbatim: "Inline layout")
                .coreFont(.headline)
                .foregroundStyle(Color.contentSecondary)

            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                FormField("City", description: "Used for shipping estimates.", layout: .inline) {
                    TextField("Cupertino", text: self.$city)
                        .textFieldStyle(.roundedBorder)
                        .fieldAccessibility()
                }

                FormField("Postal code", layout: .inline) {
                    TextField("95014", text: self.$postalCode)
                        .textFieldStyle(.roundedBorder)
                        .fieldAccessibility()
                }
                .fieldRequirement(.required)
                .fieldValidation(self.postalCode.count == 5 ? .valid : .invalid("Enter a 5-digit postal code."))
            }
            .formFieldLabelColumn()

            InsetGroupedSection(header: "Server", dividerInset: .textAligned) {
                FormField("Host", layout: .inline) {
                    TextField("example.com", text: self.$host)
                        .textFieldStyle(.plain)
                        .fieldAccessibility()
                }
                .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
                .padding(.vertical, CoreSpacing.sm)

                FormField("Port", layout: .inline) {
                    TextField("443", text: self.$port)
                        .textFieldStyle(.plain)
                        .fieldAccessibility()
                }
                .fieldValidation(self.port.count <= 5 && (Int(self.port) ?? 0) <= 65535 ? .valid : .invalid("Port must be 65535 or lower."))
                .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
                .padding(.vertical, CoreSpacing.sm)
            }
            .formFieldLabelColumn()
        }
    }

    private var emailValidation: FieldValidation {
        let parts = self.email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts[1].contains(".")
            ? .valid
            : .invalid("Enter a valid email address.")
    }
}

private struct FormFieldControlsPreview: View {
    enum Mode {
        case valid
        case invalid
        case disabledInvalid
    }

    let state: Mode

    @State private var code = "12"
    @State private var tags = ["design", "ios"]
    @State private var query = "release"
    @State private var accepted = false
    @State private var plan = "basic"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            FormField("Verification code", description: "Sent to your phone.") {
                PinCode(value: self.$code, length: 6)
            }
            .fieldRequirement(.required)
            .fieldValidation(self.validation("The code has expired."))

            FormField("Labels", description: "Press Return or comma to add.") {
                TagInput(tags: self.$tags, placeholder: "Add tag")
            }
            .fieldValidation(self.validation("Add at most 3 labels."))

            FormField("Filter") {
                SearchField(text: self.$query, placeholder: "Search releases")
            }
            .fieldValidation(self.validation("No results match this filter."))

            FormField("Terms") {
                Toggle("I accept the terms of service", isOn: self.$accepted)
                    .toggleStyle(CheckBoxToggleStyle())
            }
            .fieldRequirement(.required)
            .fieldValidation(self.validation("Accept the terms to continue."))

            FormField("Plan", description: "You can change it later.") {
                RadioGroup(
                    selection: self.$plan,
                    options: [
                        RadioOption(value: "basic", title: "Basic"),
                        RadioOption(value: "pro", title: "Pro"),
                    ],
                    axis: .horizontal,
                    spacing: CoreSpacing.lg
                )
            }
            .fieldValidation(self.validation("Pro is unavailable in your region."))
        }
        .disabled(self.state == .disabledInvalid)
    }

    private func validation(_ reason: LocalizedStringResource) -> FieldValidation {
        self.state == .valid ? .valid : .invalid(reason)
    }
}

private struct FormFieldControlsPlainPreview: View {
    @State private var code = "12"
    @State private var tags = ["design"]
    @State private var query = "release"
    @State private var accepted = false
    @State private var plan = "basic"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            PinCode(value: self.$code, length: 4)
            TagInput(tags: self.$tags, placeholder: "Add tag")
            SearchField(text: self.$query, placeholder: "Search releases")
            Toggle("I accept the terms of service", isOn: self.$accepted)
                .toggleStyle(CheckBoxToggleStyle())
            RadioGroup(
                selection: self.$plan,
                options: [RadioOption(value: "basic", title: "Basic"), RadioOption(value: "pro", title: "Pro")],
                axis: .horizontal
            )
        }
    }
}

private struct FormFieldControlsEdgePreview: View {
    @State private var code = ""
    @State private var query = ""
    @State private var accepted = false

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            FormField("Filter") {
                SearchField(text: self.$query, placeholder: "Search releases")
                    .accessibilityLabel(Text(verbatim: "Caller search label"))
            }
            .fieldValidation(.invalid("Filter is invalid."))

            FormField("Terms") {
                Toggle("I accept the terms of service", isOn: self.$accepted)
                    .toggleStyle(CheckBoxToggleStyle())
                    .accessibilityLabel(Text(verbatim: "Caller toggle label"))
            }
            .fieldValidation(.invalid("Terms are required."))

            FormField("Outer", description: "Outer description.") {
                FormField("Inner", description: "Inner description.") {
                    PinCode(value: self.$code, length: 4)
                }
                .fieldValidation(.invalid("Inner is wrong."))
            }
            .fieldValidation(.invalid("Outer is wrong."))
        }
    }
}

private struct ProgressIndicatorGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            // 三个真实场景，各自的取色与语义一致：上传走强调色、同步走中性、
            // 失败重试走 danger。`tint:` 是参数而不是外加 `.tint(_:)`——理由见
            // `ProgressIndicator.tint` 的文档注释。
            HStack(spacing: CoreSpacing.sm) {
                ProgressIndicator().controlSize(.small)
                Text(verbatim: "正在上传 3 个文件…").coreFont(.subheadline)
            }
            HStack(spacing: CoreSpacing.sm) {
                ProgressIndicator(tint: Color.contentSecondary).controlSize(.small)
                Text(verbatim: "后台同步中").coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
            HStack(spacing: CoreSpacing.sm) {
                ProgressIndicator(tint: .danger).controlSize(.small)
                Text(verbatim: "重试连接（第 2 次）").coreFont(.subheadline)
                    .foregroundStyle(Color.statusDangerForeground)
            }
            Divider()
            ProgressIndicator(text: "正在导出…", tint: .green)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SkeletonPreview: View {
    @State private var isLoading = true
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Toggle(isOn: self.$isLoading) { Text("isLoading") }
                .tint(Color.accent)
            Skeleton(isLoading: self.isLoading) {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    SkeletonCircle(diameter: 40)
                    SkeletonLine(lineCount: 2)
                }
            } content: {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    Circle().fill(Color.accent).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                        Text("王晓龙").coreFont(.subheadline)
                        Text("OhMyDesign 维护者").coreFont(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct StepsPreview: View {
    static let items: [StepItem] = [
        StepItem(title: "Cart"),
        StepItem(title: "Shipping"),
        StepItem(title: "Payment"),
        StepItem(title: "Confirm"),
    ]
    // ⚠️ 设备端画廊是 `#Preview` 之外的**第二条**视觉通路，且是唯一跑在真机 / 模拟器上的
    // 那条（`swift test` 与 CI 都不构建 App/）。`#60` 新增的呈现必须在这里出现，否则它们在
    // 真机上零覆盖（PR #206 第 2 轮 review 抓到）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Steps(items: Self.items, currentIndex: 1, axis: .horizontal, indicatorStyle: .numbered)
            Steps(items: Self.items, currentIndex: 2, presentation: .segmentedBar)
            Steps(items: Self.items, currentIndex: 1, presentation: .navigation)
            Steps(items: Self.items, currentIndex: 1, presentation: .text)
        }
    }
}

private struct TimelinePreview: View {
    private static var items: [TimelineItem] {
        [
            TimelineItem(status: .info) { Text("已创建").coreFont(.callout) },
            TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) },
            TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) },
            TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) },
            TimelineItem(status: .neutral) { Text("已归档").coreFont(.callout) },
        ]
    }

    // ⚠️ `.alternate` 与 `.horizontal` 的几何**只在渲染时可见**，`swift build` / `swift test`
    // 一定绿 —— 这条通路是它们在真机上唯一的检查点（PR #206 第 2 轮 review 抓到）。
    // `.alternate` 那条特意混入一个**宽内容**（固定 220pt），因为「节点恒在同一条中轴」
    // 恰恰是在内容固有宽度超过半槽时才会破。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Timeline(items: Self.items)
            Timeline(
                items: [
                    TimelineItem(status: .info) {
                        // 本槽位存在的意义是「非文本的定高内容」，用真实的附件行
                        // 而不是一块纯色，才看得出 `.alternate` 的对齐。
                        HStack(spacing: CoreSpacing.xs) {
                            Image(systemName: "paperclip")
                                .foregroundStyle(Color.contentSecondary)
                            Text(verbatim: "合同终稿.pdf").coreFont(.footnote)
                            Text(verbatim: "2.4 MB").coreFont(.caption)
                                .foregroundStyle(Color.contentSubtle)
                        }
                        .padding(.horizontal, CoreSpacing.sm)
                        .frame(width: 220, height: 32, alignment: .leading)
                        .background(Color.surfaceRaised, in: CoreShape.rounded(CoreRadius.small))
                    },
                    TimelineItem(status: .success) { Text("短").coreFont(.callout) },
                    TimelineItem(status: .warning) { Text("再一条").coreFont(.callout) },
                ],
                layout: .alternate
            )
            Timeline(items: Self.items, layout: .horizontal)
            Timeline(items: Self.items, layout: .grouped)
        }
    }
}

private struct CarouselPreviewItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreview: View {
    private let cards: [CarouselPreviewItem] = [
        CarouselPreviewItem(id: 0, title: "限时 5 折", color: .orange),
        CarouselPreviewItem(id: 1, title: "新品上架", color: .purple),
        CarouselPreviewItem(id: 2, title: "会员专享", color: .teal),
    ]
    var body: some View {
        Carousel(self.cards, autoAdvance: false) { item in
            CoreShape.rounded(CoreRadius.large)
                .fill(item.color.gradient)
                .overlay {
                    Text(item.title).coreFont(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                }
        }
        .frame(height: 120)
    }
}

private struct DescriptionsPreview: View {
    var body: some View {
        Descriptions(header: "Order") {
            LabeledContent("Status") { Text("Active") }
            LabeledContent("Total") { Text("$42.00") }
            LabeledContent("Placed") { Text("2026-07-20") }
        }
    }
}

private struct SpinningPreview: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
        .spinning(true, text: "Refreshing…", tint: .green)
    }
}

private struct SpinningNonBlockingPreview: View {
    // ⚠️ `.topBar` 的扫条动画与 `.inline` 的几何只在渲染时可见（PR #206 第 2 轮 review）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Card {
                Text("topBar：顶边细条，内容不被遮罩、仍可交互").coreFont(.subheadline)
            }
            .spinning(true, presentation: .topBar)

            HStack(spacing: CoreSpacing.lg) {
                Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
                Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
            }
        }
    }
}

// MARK: - ShipSwift 动效与图表的画廊演示
//
// ⚠️ 本节全部是**可交互**的演示宿主，不是静态截图源：36 个动效里绝大多数只有在
// 值变化 / 插入删除的**那一瞬间**才有东西可看，静止帧与未加修饰的内容像素级相同。
// ⇒ 画廊（模拟器里点得动）才是这批 API 单位的真实评审面。

// MARK: 微交互：8 个 modifier 共用一个演示宿主

/// 8 个 `trigger:` 型微交互的共用宿主。
///
/// ⚠️ **`decorate` 收 `AnyView` 而不是泛型 `Content: View`**：8 个 modifier 的返回类型
/// 各不相同（`ModifiedContent<…, TriggerRelay<…>>` 各是一个具体类型），泛型闭包参数
/// 在调用点无法从 `{ view, fire in view.shake(trigger: fire) }` 反推出 `Content`。
/// 返回类型那一侧才是需要泛型的（`Decorated`），入参这侧擦除掉最省事。
private struct MicroInteractionDemo<Decorated: View>: View {
    let label: LocalizedStringKey
    let symbol: String
    let decorate: (AnyView, Int) -> Decorated

    @State private var fire = 0

    init(
        label: LocalizedStringKey,
        symbol: String,
        decorate: @escaping (AnyView, Int) -> Decorated
    ) {
        self.label = label
        self.symbol = symbol
        self.decorate = decorate
    }

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            self.decorate(
                AnyView(
                    Image(systemName: self.symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                ),
                self.fire
            )
            .frame(height: 72)

            Button(self.label) { self.fire += 1 }
                .buttonStyle(.light(role: .primary))

            Text(verbatim: "trigger = \(self.fire)")
                .font(CoreTypography.Token.caption.font)
                .foregroundStyle(Color.contentSubtle)
        }
    }
}

// MARK: 转场：16 + 1 种共用一个演示宿主

/// 全部 `Transition` 入口点的共用宿主。
///
/// ⚠️ **必须由 `withAnimation` 驱动插入/删除**：`Transition` 只在视图**进出**时求值，
/// 光把它挂在一个常驻视图上什么都看不到。
/// 转场的被试内容。
///
/// ⚠️ **不能是一块纯色矩形**：转场里最难判的是旋转 / 翻转 / 溶解**有没有作用到内容上**，
/// 而纯色块转起来跟不转几乎一样。给它真实卡片的结构（缩略图 + 标题 + 副标题 + 角标）
/// 之后，`rotate3d` 的背面、`flip` 的镜像、`blinds` 的条带才有可辨的参照物。
private struct TransitionSubject: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(
                colors: [.orange, .pink, .purple],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 64)
            .overlay(alignment: .topTrailing) {
                Text(verbatim: "NEW")
                    .font(CoreTypography.Token.caption.font.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, CoreSpacing.xs)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.28), in: Capsule())
                    .padding(CoreSpacing.xs)
            }
            .overlay(alignment: .bottomLeading) {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(CoreSpacing.xs)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "夜航西飞")
                    .font(CoreTypography.Token.footnote.font.weight(.semibold))
                    .foregroundStyle(Color.contentPrimary)
                Text(verbatim: "柏林爱乐 · 4:12")
                    .font(CoreTypography.Token.caption.font)
                    .foregroundStyle(Color.contentSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background(Color.surfaceRaised)
        }
        .frame(width: 160, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

private struct TransitionDemo<T: Transition>: View {
    let transition: T

    @State private var isShown = true

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            ZStack {
                Color.clear.frame(height: 140)
                if self.isShown {
                    TransitionSubject()
                        .transition(self.transition)
                }
            }

            Button(self.isShown ? "移除" : "插入") {
                withAnimation(.easeInOut(duration: 0.8)) { self.isShown.toggle() }
            }
            .buttonStyle(.light(role: .primary))
        }
    }
}

// MARK: 庆祝与处理中 4 个

private struct ConfettiDemo: View {
    @State private var completed = 0

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                // 「完成」的语义色是 success 绿，不是 App 强调色。
                .foregroundStyle(Color.success)
            Button("完成一项") { self.completed += 1 }
                .buttonStyle(.light(role: .primary))
            Text(verbatim: "completed = \(self.completed)")
                .font(CoreTypography.Token.caption.font)
                .foregroundStyle(Color.contentSubtle)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .confetti(trigger: self.completed, strength: .pronounced, colors: GalleryPalette.festive)
    }
}

private struct ScanningOverlayDemo: View {
    var body: some View {
        ScanningOverlay {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 120)
                .overlay {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.contentMuted)
                }
        }
    }
}

private struct GlowSweepDemo: View {
    var body: some View {
        GlowSweep {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 100)
                .overlay {
                    Text("Thinking…").font(CoreTypography.Token.callout.font)
                }
        }
    }
}

private struct LightSweepDemo: View {
    var body: some View {
        LightSweep {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 100)
                .overlay {
                    Text("Syncing…").font(CoreTypography.Token.callout.font)
                }
        }
    }
}

// MARK: 文本与展示 4 个

private struct TypewriterTextDemo: View {
    @State private var streamed = "流式文本走 verbatim init，不进本地化目录。"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            TypewriterText("Welcome aboard", speed: .slow)
                .font(CoreTypography.Token.headline.font)
            TypewriterText(verbatim: self.streamed)
                .font(CoreTypography.Token.callout.font)
                .foregroundStyle(Color.contentSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnimatedMeshGradientDemo: View {
    var body: some View {
        AnimatedMeshGradient(colors: [.indigo, .purple, .pink, .orange],
                            alternateColors: [.teal, .blue, .indigo, .purple])
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
    }
}

private struct BeforeAfterSliderDemo: View {
    var body: some View {
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            ZStack {
                Color.secondaryFill
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.contentSubtle)
            }
        } after: {
            ZStack {
                Color.accentSubtleBackground
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
    }
}

// MARK: 跨平台改造 4 个

/// `OrbitingLogos` 的入参是**泛型集合 + `Identifiable`**（AD-E 重写后的形态），
/// 这里用画廊自己的模型类型接上，正是下游的用法。
private struct OrbitingBrand: Identifiable {
    let id: Int
    let symbol: String
}

private struct OrbitingLogosDemo: View {
    private static let brands = [
        OrbitingBrand(id: 0, symbol: "swift"),
        OrbitingBrand(id: 1, symbol: "applelogo"),
        OrbitingBrand(id: 2, symbol: "cloud.fill"),
        OrbitingBrand(id: 3, symbol: "bolt.fill"),
        OrbitingBrand(id: 4, symbol: "cube.fill"),
    ]

    var body: some View {
        OrbitingLogos(Self.brands, colors: GalleryPalette.entities) { brand in
            // ⚠️ 逐 logo 取色必须在**内容闭包**里做：`OrbitingLogos(colors:)` 给的是
            // 轨道粒子的色板，盖不住这里；上一版写 `.foregroundStyle(.tint)`，
            // 五个品牌图标于是全是同一个强调色。
            Image(systemName: brand.symbol)
                .font(.system(size: 18))
                .foregroundStyle(GalleryPalette.entities[brand.id % GalleryPalette.entities.count])
        } center: {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.contentPrimary)
        }
        .frame(height: 220)
    }
}

private struct DotSphereDemo: View {
    var body: some View {
        DotSphere(colors: GalleryPalette.entities).frame(height: 200)
    }
}

private struct CharSphereDemo: View {
    var body: some View {
        CharSphere(["道", "德", "经", "S", "w", "i", "f", "t"], colors: GalleryPalette.entities)
            .frame(height: 200)
    }
}

private struct FullScreenButtonDemo: View {
    // ⚠️ 自带 `NavigationStack`：`navigationTransition(.zoom)` 要求源与目的地在**同一个**
    // 导航栈里，而画廊详情页把 preview 渲染两遍（Light / Dark）、本身不提供栈。
    var body: some View {
        NavigationStack {
            FullScreenButton {
                VStack(spacing: CoreSpacing.md) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("展开后的全屏详情")
                        .font(CoreTypography.Token.headline.font)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surfaceCanvas)
            } label: {
                RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                    .fill(Color.surfaceRaised)
                    .frame(height: 120)
                    .overlay {
                        Label("点开看看", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(CoreTypography.Token.callout.font)
                    }
            }
        }
        .frame(height: 200)
    }
}

// MARK: 四个图表

/// ⚠️ 三个图表的数据契约都是**泛型协议**，画廊按下游用法用自己的模型类型接上
/// （而不是库自带的具体 struct —— 那正是 `#255` 终审 I-7 要求避开的形态）。
private struct GalleryMetric: ChartValue {
    let id: Int
    let label: String
    let value: Double
}

private struct GalleryDay: HeatmapDay {
    let id: Int
    let date: Date
    let count: Int
}

private struct GalleryNode: GraphNode {
    let id: String
    let label: String
}

private struct RadarChartDemo: View {
    var body: some View {
        RadarChart([
            GalleryMetric(id: 0, label: "速度", value: 82),
            GalleryMetric(id: 1, label: "力量", value: 61),
            GalleryMetric(id: 2, label: "耐力", value: 94),
            GalleryMetric(id: 3, label: "技巧", value: 47),
            GalleryMetric(id: 4, label: "智力", value: 73),
        ], tint: .indigo)
        .frame(height: 220)
    }
}

private struct RingChartDemo: View {
    var body: some View {
        RingChart([
            GalleryMetric(id: 0, label: "活动", value: 420),
            GalleryMetric(id: 1, label: "锻炼", value: 28),
            GalleryMetric(id: 2, label: "站立", value: 9),
        ], goal: 500, colors: GalleryPalette.activityRings)
        .frame(height: 200)
    }
}

private struct ActivityHeatmapDemo: View {
    /// ⚠️ **锚定到固定日期而不是 `.now`**：`.now` 会让同一份代码每天渲出不同的日期标签
    /// ——库内那个 `#Preview` 用的正是 `.now`（视觉冒烟无所谓），而画廊要能横向对比。
    private static let anchor = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC

    private static let days: [GalleryDay] = (0..<120).map { offset in
        GalleryDay(
            id: offset,
            date: Self.anchor.addingTimeInterval(Double(offset) * 86_400),
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    }

    var body: some View {
        // 贡献热力图的现实原型（GitHub / 健身打卡）一律是绿色阶。
        ActivityHeatmap(Self.days, tint: .green).frame(height: 120)
    }
}

private struct NetworkGraphDemo: View {
    private static let nodes = (0..<14).map { GalleryNode(id: "n\($0)", label: "节点 \($0)") }
    private static let edges = (0..<20).map {
        GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)")
    }

    var body: some View {
        NetworkGraph(nodes: Self.nodes, edges: Self.edges, tint: .teal).frame(height: 260)
    }
}

private struct GalleryTreeNode: Identifiable {
    let id: String
    let name: String
    let children: [GalleryTreeNode]?
}

private struct TreePreview: View {
    private static let roots: [GalleryTreeNode] = [
        GalleryTreeNode(id: "design", name: "Design", children: [
            GalleryTreeNode(id: "tokens", name: "Tokens", children: [
                GalleryTreeNode(id: "color", name: "Color", children: nil),
                GalleryTreeNode(id: "spacing", name: "Spacing", children: nil),
                GalleryTreeNode(id: "motion", name: "Motion", children: nil),
            ]),
            GalleryTreeNode(id: "icons", name: "Icons", children: nil),
        ]),
        GalleryTreeNode(id: "readme", name: "README.md", children: nil),
        GalleryTreeNode(id: "tests", name: "Tests", children: [
            GalleryTreeNode(id: "unit", name: "Unit", children: nil),
            GalleryTreeNode(id: "snapshot", name: "Snapshot", children: nil),
        ]),
    ]

    // ⚠️ 键盘导航在模拟器上只有接了硬件键盘才走得到；这一屏是它唯一的人工检查点。
    @State private var expanded: Set<String> = Tree<[GalleryTreeNode], String, Text>.expandedIDs(
        TreePreview.roots, id: \.id, children: \.children, toDepth: 2
    )
    @State private var selection: Set<String> = []
    @State private var checked: Set<String> = ["color"]
    @State private var activated: String = "—"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "单选 / single").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
                Tree(
                    Self.roots,
                    children: \.children,
                    expanded: self.$expanded,
                    selection: self.$selection,
                    onActivate: { self.activated = $0 }
                ) { node in
                    Text(verbatim: node.name).coreFont(.callout)
                }
            }
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "多选 + 三态复选框 / multiple + tri-state checkbox")
                    .coreFont(.footnote).foregroundStyle(Color.contentSecondary)
                Tree(
                    Self.roots,
                    children: \.children,
                    expanded: self.$expanded,
                    selection: self.$selection,
                    selectionMode: .multiple,
                    checked: self.$checked
                ) { node in
                    Text(verbatim: node.name).coreFont(.callout)
                }
            }
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(verbatim: "导航器 / navigator（.treeStyle(.navigator) + .controlSize(.small) + .rowClickBehavior(.selectAndToggleExpansion) + 单选，VS Code Explorer 式：单击替换选中；单击文件夹行即展开 / 折叠，再点已选中的文件夹保持选中）")
                    .coreFont(.footnote).foregroundStyle(Color.contentSecondary)
                ExplorerTreePreview()
            }
            Text(verbatim: "expanded=\(self.expanded.sorted()) selection=\(self.selection.sorted()) checked=\(self.checked.sorted()) activated=\(self.activated)")
                .coreFont(.caption)
                .foregroundStyle(Color.contentSubtle)
        }
    }
}

private struct GalleryFileNode: Identifiable {
    enum GitStatus { case modified, untracked }

    let id: String
    let name: String
    let children: [GalleryFileNode]?
    var git: GitStatus?
}

private struct ExplorerTreePreview: View {
    static let roots: [GalleryFileNode] = [
        GalleryFileNode(id: "Sources", name: "Sources", children: [
            GalleryFileNode(id: "Sources/Tree", name: "Tree", children: [
                GalleryFileNode(id: "Sources/Tree/Tree.swift", name: "Tree.swift", children: nil, git: .modified),
                GalleryFileNode(id: "Sources/Tree/TreeCore.swift", name: "TreeCore.swift", children: nil),
                GalleryFileNode(id: "Sources/Tree/TreeStyle.swift", name: "TreeStyle.swift", children: nil, git: .untracked),
            ]),
            GalleryFileNode(id: "Sources/Resources", name: "Resources", children: [
                GalleryFileNode(id: "Sources/Resources/Localizable.strings", name: "Localizable.strings", children: nil),
            ]),
        ]),
        GalleryFileNode(id: "docs", name: "docs", children: [
            GalleryFileNode(id: "docs/tree.md", name: "tree.md", children: nil, git: .modified),
            GalleryFileNode(id: "docs/component-registry.json", name: "component-registry.json", children: nil),
        ]),
        GalleryFileNode(id: "Package.swift", name: "Package.swift", children: nil),
        GalleryFileNode(id: "README.md", name: "README.md", children: nil),
    ]

    @State private var expanded: Set<String> = Tree<[GalleryFileNode], String, Text>.expandedIDs(
        ExplorerTreePreview.roots, id: \.id, children: \.children, toDepth: 3
    )
    @State private var selection: Set<String> = ["Sources/Tree/TreeStyle.swift"]
    @State private var lastMenuAction: String = "—"
    @State private var query: String = ""

    private var isSearching: Bool {
        !self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var matchCount: Int {
        Tree.searchMatches(Self.roots, id: \.id, children: \.children, query: self.query, text: \.name).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            TextField("Filter files", text: self.$query)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            self.explorer
            if self.isSearching, self.matchCount == 0 {
                ContentUnavailableView.search(text: self.query)
            }
            if self.isSearching {
                Text(verbatim: "命中 / matches: \(self.matchCount)（直接命中的节点数，不计只作上下文保留的祖先 / 后代）")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentSecondary)
            }
            Text(verbatim: "搜索 / filter: \"\(self.query)\" — expanded=\(self.expanded.sorted())（搜索期间不写）")
                .coreFont(.caption)
                .foregroundStyle(Color.contentSubtle)
            Text(verbatim: "右键菜单 / context menu: \(self.lastMenuAction)")
                .coreFont(.caption)
                .foregroundStyle(Color.contentSubtle)
        }
        .task(id: self.query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, self.isSearching else { return }
            AccessibilityNotification.Announcement("\(self.matchCount) matches").post()
        }
    }

    private var explorer: some View {
        Tree(
            Self.roots,
            children: \.children,
            expanded: self.$expanded,
            selection: self.$selection,
            selectionMode: .single
        ) { node in
            HStack(spacing: CoreSpacing.xs) {
                Label {
                    Text(verbatim: node.name, highlighting: self.query)
                        .foregroundStyle(Self.tint(for: node.git) ?? Color.contentPrimary)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: Self.icon(for: node))
                        .foregroundStyle(Color.contentSecondary)
                }
                .coreFont(.callout)
                Spacer(minLength: 0)
                if let git = node.git {
                    Text(verbatim: Self.letter(for: git))
                        .coreFont(.caption)
                        .foregroundStyle(Self.tint(for: git) ?? Color.contentSecondary)
                }
            }
        }
        .searchFilter(self.query, text: \.name)
        .rowClickBehavior(.selectAndToggleExpansion)
        .rowContextMenu { targets in
            Button("New File", systemImage: "doc.badge.plus") {
                self.lastMenuAction = "New File in \(targets.sorted())"
            }
            Button("Rename", systemImage: "pencil") {
                self.lastMenuAction = "Rename \(targets.sorted())"
            }
            .disabled(targets.count != 1)
            Divider()
            Button("Delete \(targets.count) item(s)", systemImage: "trash", role: .destructive) {
                self.lastMenuAction = "Delete \(targets.sorted())"
            }
        }
        .treeStyle(.navigator)
        .controlSize(.small)
        .padding(.vertical, CoreSpacing.xs)
        .surface(.content)
    }

    private static func icon(for node: GalleryFileNode) -> String {
        guard node.children == nil else { return "folder" }
        switch (node.name as NSString).pathExtension {
        case "swift": return "swift"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        default: return "doc"
        }
    }

    private static func letter(for status: GalleryFileNode.GitStatus) -> String {
        switch status {
        case .modified: "M"
        case .untracked: "U"
        }
    }

    private static func tint(for status: GalleryFileNode.GitStatus?) -> Color? {
        switch status {
        case .modified: .warning
        case .untracked: .success
        case nil: nil
        }
    }
}
