import SwiftUI
import OhMyDesign

// MARK: - Snapshot Previews
// 每个组件至少一个 #Preview 宏，供 SnapshotTest 自动收编生成 PNG。
// 命名为简单组件名称即可——SnapshotPreviews 会自动追加 _Light / _Dark 变体后缀。

#Preview("Badge") {
    HStack(spacing: CoreSpacing.sm) {
        Badge("Info", variant: .info)
        Badge("Success", variant: .success)
        Badge("Warning", variant: .warning)
        Badge("Danger", variant: .danger)
        Badge("Neutral")
    }
    .padding()
}

#Preview("Tag") {
    HStack(spacing: CoreSpacing.sm) {
        Tag("bug", color: .red)
        Tag("enhancement", color: .blue)
        Tag("doc", color: .cyan, removable: true, onRemove: {})
    }
    .padding()
}

#Preview("Banner") {
    VStack(spacing: CoreSpacing.sm) {
        Banner(level: .info) { Text("Info message") }
        Banner(level: .success) { Text("Success message") }
        Banner(level: .warning) { Text("Warning message") }
        Banner(level: .danger) { Text("Danger message") }
        Banner(level: .neutral) { Text("Neutral message") }
        Banner(level: .info, title: "Update available", message: "Restart the app to finish installing version 2.4.") {
            Button("Restart now") {}
                .buttonStyle(.solid(role: .primary))
                .controlSize(.small)
        } onDismiss: {}
    }
    .padding()
}

#Preview("Button") {
    VStack(spacing: CoreSpacing.sm) {
        Button("Solid Primary") {}.buttonStyle(.solid(role: .primary))
        Button("Light Secondary") {}.buttonStyle(.light(role: .secondary))
        Button("Borderless Danger") {}.buttonStyle(.borderless(role: .danger))
    }
    .padding()
}

#Preview("Form Icons") {
    HStack(spacing: CoreSpacing.md) {
        LabelIcon(systemName: "person.fill", backgroundColor: .blue)
        ChevronRightIcon()
        DangerIcon()
    }
    .padding()
}

#Preview("SegmentedControl") {
    SegmentedControl(items: ["One", "Two", "Three"], selection: .constant("One"), title: { $0 })
        .padding()
}

#Preview("SearchField") {
    SearchField(text: .constant("filter results"))
        .padding()
}

#Preview("Avatar") {
    HStack(spacing: CoreSpacing.md) {
        Avatar(name: "Evan").controlSize(.small).clipShape(Circle())
        Avatar(name: "OhMyDesign").clipShape(Circle())
        Avatar(name: "Ada").controlSize(.extraLarge).clipShape(Circle())
        Avatar(name: "Linus", size: .fixed(64)).clipShape(Circle())
    }
    .padding()
}

#Preview("ListRow") {
    VStack(spacing: 0) {
        ListRow(label: { Text("Label only").foregroundStyle(Color.contentPrimary) })
        ListRow(
            leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
            label: { Text("With icon + chevron").foregroundStyle(Color.contentPrimary) },
            trailing: { Image(systemName: "chevron.forward").foregroundStyle(Color.contentMuted) }
        )
    }
    .padding()
}

#Preview("UnderlinedTabBar") {
    UnderlinedTabBar(
        items: ["Tab 1", "Tab 2", "Tab 3"],
        selection: .constant("Tab 1"),
        title: { $0 }
    )
    .padding()
}

#Preview("Toast") {
    ToastSnapshotHarness()
        .toastHost(edge: .top)
}

// ⚠️ `#65` 形态 D2 的三种呈现各注册一条 —— **只往组件源文件加 `#Preview` 进不了快照
// 流水线**，脚本默认模式只保留 `Previews.swift` 驱动的 `OhMyDesignPreview_*`。
#Preview("Toast · fullWidthBanner") {
    ToastSnapshotHarness()
        .toastHost(edge: .top, presentation: .fullWidthBanner)
}

#Preview("Toast · centeredHUD") {
    ToastSnapshotHarness()
        .toastHost(edge: .top, presentation: .centeredHUD)
}

#Preview("Toast · title + description + action") {
    ToastSnapshotHarness(rich: ToastItem(
        title: "Conversation archived",
        description: "It moves back to the inbox if you undo within a few seconds.",
        level: .neutral,
        duration: .persistent,
        action: ToastAction("Undo") {}
    ))
    .toastHost(edge: .top)
}

#Preview("Toast · fullWidthBanner bottom") {
    ToastSnapshotHarness()
        .toastHost(edge: .bottom, presentation: .fullWidthBanner)
}

/// Toast snapshot demo：按钮点击触发 toast 显示，初始状态展示场景脚手架。
private struct ToastSnapshotHarness: View {
    @Environment(\.toastHost) private var toast
    var rich: ToastItem?

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Tap button to show a toast.")
                .font(CoreTypography.Token.callout.font)
                .foregroundStyle(Color.contentMuted)
            Button("Info") { self.toast?.show("Info: demo", level: .info) }
            Button("Success") { self.toast?.show("Success: demo", level: .success) }
            Button("Warning") { self.toast?.show("Warning: demo", level: .warning) }
            Button("Danger") { self.toast?.show("Danger: demo", level: .danger) }
            Button("Neutral") { self.toast?.show("Neutral: demo", level: .neutral) }
        }
        .padding(CoreSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
        .task {
            if let rich = self.rich {
                self.toast?.show(rich)
            } else {
                self.toast?.show("Toast snapshot", level: .info)
            }
        }
    }
}

// MARK: - Three-in-one components

#Preview("ProgressIndicator") {
    VStack(spacing: CoreSpacing.md) {
        ProgressIndicator()
            .controlSize(.small)
        ProgressIndicator()
            .controlSize(.regular)
        ProgressIndicator()
            .controlSize(.large)
        // Issue #172 增强：可选文案 init，渲染于 spinner 下方。
        ProgressIndicator(text: "Loading…")
            .controlSize(.large)
    }
    .padding()
}

// ProgressBar 的快照 #Preview 已随弃用移除（0.6.0）——索引不再引用其图，
// 迁移期请看 "Core Control Styles" 预览的 .core ProgressView。

#Preview("StateLabel") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        StateLabel(style: .active)
        StateLabel(style: .draft)
        StateLabel(style: .completed)
        StateLabel(style: .cancelled)
        StateLabel(style: .active, label: "In Progress")
    }
    .padding()
}

#Preview("AvatarGroup") {
    VStack(spacing: CoreSpacing.md) {
        AvatarGroup {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
            Circle().fill(.orange).frame(width: 32, height: 32)
            Circle().fill(.purple).frame(width: 32, height: 32)
        }
        AvatarGroup(max: 2) {
            Circle().fill(.blue).frame(width: 24, height: 24)
            Circle().fill(.green).frame(width: 24, height: 24)
            Circle().fill(.red).frame(width: 24, height: 24)
        }
        // `#60` 形态 D2 新增的三种排布。⚠️ 注册在**本文件**才会进 `docs/snapshots/` ——
        // `run-snapshots.sh` 默认模式只保留 `OhMyDesignPreview_*`（本文件驱动），库内
        // `#Preview` 产出的 `OhMyDesign_*` 会被 `find -delete` 删掉（PR #206 第 2 轮
        // Copilot review 抓到：只往库内加 `#Preview` 进不了快照流水线）。
        AvatarGroup(max: 3, layout: .spaced) {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
            Circle().fill(.orange).frame(width: 32, height: 32)
        }
        AvatarGroup(max: 3, layout: .grid) {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
            Circle().fill(.orange).frame(width: 32, height: 32)
            Circle().fill(.purple).frame(width: 32, height: 32)
        }
        AvatarGroup(layout: .countOnly) {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
        }
    }
    .padding()
}

#Preview("FlowLayout") {
    FlowLayout(spacing: CoreSpacing.xs) {
        ForEach(
            ["bug", "enhancement", "help wanted", "documentation", "good first issue", "dependencies"],
            id: \.self
        ) { label in
            Tag(label, color: .blue)
        }
    }
    .padding()
    .frame(width: 280)
}

#Preview("AsyncButton") {
    VStack(spacing: CoreSpacing.sm) {
        AsyncButton("Solid Primary") { }.buttonStyle(.solid(role: .primary))
        AsyncButton("Light Secondary") { }.buttonStyle(.light(role: .secondary))
        AsyncButton("Borderless Danger") { }.buttonStyle(.borderless(role: .danger))
        AsyncButton {
            // idle 态 snapshot,这里无需真的 sleep
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.circularGlass)
    }
    .padding()
}

// MARK: - Phase 2（0.4.0）

#Preview("Card") {
    VStack(spacing: CoreSpacing.md) {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("Card 标题").coreFont(.headline)
                Text("卡片浮于画布之上").coreFont(.subheadline).foregroundStyle(Color.contentSecondary)
            }
        }
        Card(padding: CoreSpacing.md, alignment: .center) {
            Text("居中 + 紧凑内边距").coreFont(.subheadline)
        }
        Card {
            Card {
                Text("嵌套 Card：elevated").coreFont(.subheadline)
            }
        }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Separator") {
    VStack(alignment: .leading, spacing: CoreSpacing.md) {
        Text("贯穿").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
        Separator()
        Text("leading 缩进 58pt").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
        Separator(inset: .leading(58))
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Section Header Footer") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        SectionHeader("General")
        Card { Text("分组内容").coreFont(.body) }
        SectionFooter("Applies to all accounts on this device.")
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("SettingsRow") {
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
            Toggle("Notifications", isOn: .constant(true)).labelsHidden()
        }
        .tint(.green)
    }
    .background(Color.surfaceCard)
    .clipShape(CoreShape.rounded(CoreRadius.medium))
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("InsetGroupedSection") {
    InsetGroupedSection(header: "Connectivity", footer: "Airplane Mode disables Wi-Fi and Bluetooth.") {
        SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
            Toggle("Airplane Mode", isOn: .constant(false)).labelsHidden()
        }
        SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
            Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
            SettingsRowChevron()
        }
    }
    .tint(.green)
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Core Control Styles") {
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
            .progressViewStyle(.core)
            .tint(.red)
        ProgressView(value: 0.6).progressViewStyle(.coreCircular).tint(.red)
        Label("Sync", systemImage: "arrow.triangle.2.circlepath").labelStyle(.core).tint(.blue)
        DisclosureGroup("Details", isExpanded: .constant(true)) {
            Text("Additional information goes here.").foregroundStyle(Color.contentSecondary)
        }
        .disclosureGroupStyle(.core)
        .tint(.red)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

// MARK: - Phase 3（semi-mobile-components epic，0.7.0）

#Preview("Skeleton") {
    SkeletonPreviewsPreviewGallery()
        .padding()
        .background(Color.surfaceCanvas)
}

private struct SkeletonPreviewsPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            HStack(alignment: .top, spacing: CoreSpacing.md) {
                SkeletonCircle(diameter: 40)
                SkeletonLine(lineCount: 2)
            }
            SkeletonRect(height: 100)
        }
    }
}

#Preview("Steps") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        Steps(
            items: [
                StepItem(title: "Cart", description: "Review items"),
                StepItem(title: "Shipping", description: "Add address"),
                StepItem(title: "Payment", description: "Enter card details"),
                StepItem(title: "Confirm", description: "Review & place order"),
            ],
            currentIndex: 1,
            axis: .horizontal,
            indicatorStyle: .dot
        )
        Steps(
            items: [
                StepItem(title: "Cart"),
                StepItem(title: "Shipping"),
                StepItem(title: "Payment"),
                StepItem(title: "Confirm"),
            ],
            currentIndex: 2,
            axis: .vertical,
            indicatorStyle: .numbered
        )
        // `#60` 形态 D2 新增的三种呈现（见 AvatarGroup 处关于「为什么必须注册在本文件」）。
        Steps(items: PreviewSnapshotFixtures.stepsSnapshotItems, currentIndex: 2, presentation: .segmentedBar)
        Steps(items: PreviewSnapshotFixtures.stepsSnapshotItems, currentIndex: 1, presentation: .navigation)
        Steps(items: PreviewSnapshotFixtures.stepsSnapshotItems, currentIndex: 1, presentation: .text)
    }
    .padding()
    .background(Color.surfaceCanvas)
}


#Preview("Timeline") {
    Timeline {
        TimelineItem(status: .success) {
            Text("审核通过").coreFont(.callout)
        }
        TimelineItem(status: .warning) {
            Text("即将过期提醒").coreFont(.callout)
        }
        TimelineItem(status: .danger) {
            Text("处理失败").coreFont(.callout)
        }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Timeline Activity") {
    // 活动流：40pt 头像大于 24pt 下限，撑宽节点列；分组标题与纯运行期摘要是非行子视图 / 无标题行。
    Timeline { PreviewSnapshotFixtures.timelineActivityRows }
        .padding()
        .background(Color.surfaceCanvas)
}

#Preview("Timeline Deploy Log") {
    // 部署日志：自定义图标节点 + `status:`，状态随标题播报，图标自身的 label 已隐藏。
    Timeline { PreviewSnapshotFixtures.timelineDeployRows }
        .padding()
        .background(Color.surfaceCanvas)
}

#Preview("Tree") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        Tree(
            PreviewSnapshotFixtures.treeNodes,
            children: \.children,
            expanded: .constant(["design", "tokens"]),
            selection: .constant(["icons"]),
            selectionMode: .multiple,
            checked: .constant(["color"])
        ) { node in
            Text(verbatim: node.name).coreFont(.callout)
        }
        Tree(
            PreviewSnapshotFixtures.treeNodes,
            children: \.children,
            expanded: .constant(["design", "tokens", "tests"]),
            selection: .constant(["spacing"])
        ) { node in
            Label(node.name, systemImage: node.children == nil ? "doc" : "folder").coreFont(.callout)
        }
        .treeStyle(.navigator)
        .controlSize(.small)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Timeline Layouts") {
    // `#60` 形态 D2 新增的三种排布。⚠️ `.alternate` 那组特意混入一个**宽内容**（220pt）——
    // 「节点恒在同一条中轴」恰恰只在内容固有宽度超过半槽时才会破，全用短文本的样本
    // 结构上暴露不出这个 case。
    ScrollView {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Timeline(layout: .alternate) {
                TimelineItem(status: .info) {
                    Color.statusAccentEmphasis.frame(width: 220, height: 32)
                }
                TimelineItem(status: .success) { Text("短").coreFont(.callout) }
                TimelineItem(status: .warning) { Text("再一条").coreFont(.callout) }
            }
            Timeline(layout: .horizontal) { PreviewSnapshotFixtures.timelineRows }
            Timeline(layout: .grouped) { PreviewSnapshotFixtures.timelineRows }
        }
        .padding()
    }
    .background(Color.surfaceCanvas)
}

#Preview("Timeline Alternate Widths") {
    // 同一份数据放进三种**不同宽度**的容器，节点必须在各自容器里居中（三条中轴各自不同、
    // 但每条都在自己容器的正中），且连线必须**穿过**圆点而不是从旁边擦过。
    //
    // ⚠️ **它证不了「冻结」**（PR #206 第 4 轮 review 纠正了我上一版的注释，那句话是假的）：
    // `@State` 是**按视图实例**存的，三个 `.frame(width:)` 里是三个独立 identity，冻结版会
    // 各自在自己的首帧测到自己的容器宽、各自正确收敛，画出来和现在**一模一样**。冻结的定义
    // 是「**同一个实例**的 proposal 随时间变化时不跟随」（旋转 / 拖分栏 / 缩窗口），而这里
    // 没有任何 proposal 随时间变化。
    // ⚠️ **量出来的 0.5px（≈0.167pt）是光栅残差，不是布局偏移，别去「修」它**：10pt 圆点
    // @3x 占 30px ⇒ 中心落在 x.5；1pt 连线 @3x 占 3px ⇒ 中心落在整数。两者奇偶必然不同，
    // 差半个像素消不掉。真正的回归长什么样有参照：第 3 轮那次是 **7.2pt**（= (24-10)/2）。
    //
    // ⇒ 「不会冻结」由 `TimelineStackLayout` **无存储状态**这一结构事实保证（槽宽每次
    // `sizeThatFits` / `placeSubviews` 都从 proposal 现算），不由本预览保证。留着它是因为
    // 「不同宽度下各自居中 + 连线穿过圆点」本身值得看 —— 第 4 轮的 7pt 偏移正是在这张图上
    // 被量出来的。
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        ForEach([200.0, 280.0, 360.0] as [CGFloat], id: \.self) { width in
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(verbatim: "容器宽 \(Int(width))pt")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentSecondary)
                Timeline(layout: .alternate) { PreviewSnapshotFixtures.timelineRows }
                    .frame(width: width)
                    .background(Color.surfaceRaised)
            }
        }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Spinning Presentations") {
    // `#60` 形态 D2 新增的两种**非阻塞**呈现。`.overlay`（默认）另有 ComponentData 那条。
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        Card {
            Text("topBar：顶边细条，内容不被遮罩").coreFont(.subheadline)
        }
        .spinning(true, presentation: .topBar)

        HStack(spacing: CoreSpacing.lg) {
            Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
            Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
        }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

/// 快照 `#Preview` 共用的样本数据（`enum` 作命名空间，不产生实例）。
///
/// ⚠️ `@MainActor` 必需：`StepItem` / `TimelineItem` 的 init 在库侧是 MainActor 隔离的，
/// 而 `enum` 的 static 成员默认落在 nonisolated 上下文，不标注会编译失败。
@MainActor
enum PreviewSnapshotFixtures {
    /// `Steps` 三种新呈现共用的样本 —— 同一份数据换 `presentation`，差异才归因于呈现本身。
    /// ⚠️ 用 `var` 而非 `let`：实测（Xcode 26.4 / Swift 6，本 App target 开
    /// `-default-isolation MainActor`）`static let stepsSnapshotItems: [StepItem] = [...]`
    /// 报 `main actor-isolated default value in a nonisolated context` —— `StepItem.init`
    /// 的 `id: UUID = UUID()` 默认值是 MainActor 隔离的，而 `static let` 的初始化表达式
    /// 求值在 nonisolated 上下文。改 computed `var` + 类型上的 `@MainActor` 后通过。
    /// （限定为这个具体形态，不是「`@MainActor` 类型上的 `static let` 一律非法」。）
    static var stepsSnapshotItems: [StepItem] {
        [
            StepItem(title: "Cart"),
            StepItem(title: "Shipping"),
            StepItem(title: "Payment"),
            StepItem(title: "Confirm"),
        ]
    }

    @ViewBuilder
    static var timelineRows: some View {
        TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) }
        TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) }
        TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) }
    }

    /// 活动流参考形态：非行分组标题 + 头像节点的标题行 + 纯运行期文本的无标题行。
    @ViewBuilder
    static var timelineActivityRows: some View {
        Text(verbatim: "Today")
            .coreFont(.footnote)
            .foregroundStyle(Color.contentSecondary)
        ForEach(Self.timelineActivityEvents, id: \.actor) { event in
            TimelineItem("\(event.actor) pushed \(event.count) commits", time: Text(verbatim: event.time)) {
                Avatar(name: event.actor, size: .fixed(40))
            } content: {}
        }
        TimelineItem {
            Text(verbatim: "CI summary from server: 3 checks passed").coreFont(.callout)
        }
    }

    static var timelineActivityEvents: [(actor: String, count: Int, time: String)] {
        [("Evan", 3, "2h ago"), ("Mia", 2, "5h ago")]
    }

    /// 部署日志参考形态：逐项 success / danger 的自定义图标节点，状态随标题播报。
    @ViewBuilder
    static var timelineDeployRows: some View {
        ForEach(Self.timelineDeploys, id: \.version) { deploy in
            TimelineItem(
                "Deployed \(deploy.version)", time: Text(verbatim: deploy.time), status: deploy.ok ? .success : .danger
            ) {
                Image(systemName: deploy.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(deploy.ok ? Color.statusSuccessEmphasis : Color.statusDangerEmphasis)
                    .accessibilityHidden(true)
            } content: {
                Text(verbatim: deploy.commit).coreFont(.caption).monospaced()
            }
        }
    }

    static var timelineDeploys: [(version: String, time: String, ok: Bool, commit: String)] {
        [("1.4.0", "09:12", true, "a1b2c3d"), ("1.4.1", "11:40", false, "e4f5a6b"), ("1.4.2", "12:05", true, "c7d8e9f")]
    }

    static var treeNodes: [SnapshotTreeNode] {
        [
            SnapshotTreeNode(id: "design", name: "Design", children: [
                SnapshotTreeNode(id: "tokens", name: "Tokens", children: [
                    SnapshotTreeNode(id: "color", name: "Color", children: nil),
                    SnapshotTreeNode(id: "spacing", name: "Spacing", children: nil),
                ]),
                SnapshotTreeNode(id: "icons", name: "Icons", children: nil),
            ]),
            SnapshotTreeNode(id: "readme", name: "README.md", children: nil),
            SnapshotTreeNode(id: "tests", name: "Tests", children: [
                SnapshotTreeNode(id: "unit", name: "Unit", children: nil),
            ]),
        ]
    }
}

struct SnapshotTreeNode: Identifiable {
    let id: String
    let name: String
    let children: [SnapshotTreeNode]?
}

#Preview("Rating") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        Rating(value: .constant(3))
        Rating(value: .constant(2.5), step: 0.5)
        Rating(value: .constant(3), step: 0.5)
            .disabled(true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("RatingDisplay") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        RatingDisplay(value: 4)
        RatingDisplay(value: 3.5)
        RatingDisplay(value: 7, count: 10)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("PinCode") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        PinCode(value: .constant("123"), length: 6)
        PinCode(value: .constant("42"), length: 4, isSecure: true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Radio Group") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        RadioGroup(
            selection: .constant("pro"),
            options: [
                RadioOption(value: "basic", title: "Basic"),
                RadioOption(value: "pro", title: "Pro"),
                RadioOption(value: "enterprise", title: "Enterprise"),
            ]
        )
        RadioGroup(
            selection: .constant(2),
            options: [
                RadioOption(value: 1, title: "S"),
                RadioOption(value: 2, title: "M"),
                RadioOption(value: 3, title: "L"),
            ],
            axis: .horizontal
        )
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("TagInput") {
    // tagColor: .blue——见 ComponentData.swift 的 TagInputPreview 同款注释：默认
    // .contentSecondary 经 Tag 的 .opacity(0.12) 背景公式在暗色画布上对比度过低。
    TagInput(
        tags: .constant(["bug", "enhancement", "help wanted"]),
        placeholder: "Add tag",
        tagColor: .blue
    )
    .padding()
    .frame(width: 320)
    .background(Color.surfaceCanvas)
}

#Preview("TagGroup") {
    struct Item: Identifiable, Hashable { let id: String }
    let languages = ["Swift", "Kotlin", "Rust", "TypeScript", "Go"].map(Item.init(id:))
    return VStack(alignment: .leading, spacing: CoreSpacing.md) {
        TagGroup(languages, selection: .constant(["Swift", "Rust"]), disabled: ["Go"], color: .contentPrimary) {
            Text($0.id)
        }
        TagGroup(languages, selection: .constant(["Kotlin"]), selectionMode: .single, color: .contentPrimary) {
            Text($0.id)
        }
        .coreAccent(.blue)
    }
    .padding()
    .frame(width: 320)
    .background(Color.surfaceCanvas)
}

#Preview("FormField") {
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        FormField("Full name", description: "Shown on your public profile.") {
            TextField("Jane Appleseed", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .fieldAccessibility()
        }
        .fieldRequirement(.required)

        FormField("Email") {
            TextField("you@example.com", text: .constant("jane@"))
                .textFieldStyle(.roundedBorder)
                .fieldAccessibility()
        }
        .fieldRequirement(.required)
        .fieldValidation(.invalid("Enter a valid email address."))

        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            FormField("City", layout: .inline) {
                TextField("Cupertino", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            FormField("Postal code", layout: .inline) {
                TextField("95014", text: .constant("950"))
                    .textFieldStyle(.roundedBorder)
                    .fieldAccessibility()
            }
            .fieldRequirement(.required)
            .fieldValidation(.invalid("Enter a 5-digit postal code."))
        }
        .formFieldLabelColumn()
    }
    .padding()
    .frame(width: 360)
    .background(Color.surfaceCanvas)
}

#Preview("Descriptions") {
    Descriptions(header: "Order") {
        LabeledContent("Status") { Text("Active") }
        LabeledContent("Total") { Text("$42.00") }
        LabeledContent("Placed") { Text("2026-07-20") }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Pressable Button Styles") {
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        InsetGroupedSection(header: ".pressableRow") {
            Button {} label: {
                SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                    SettingsRowChevron()
                }
            }
            .buttonStyle(.pressableRow)
        }
        Button {} label: {
            Card { Text("Weekly report") }
        }
        .buttonStyle(.pressableCard)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Float Button") {
    // 有界画布：FAB 需要深色背景才能看清玻璃质感，但不应像早期版本那样用
    // `.ignoresSafeArea()` 铺满整屏——那会让快照按设备全屏尺寸渲染，PNG 压缩率
    // 极差（4.6MB vs 其它组件的几百 KB）。改为固定尺寸卡片 + clipShape，与
    // ComponentData.swift 里 app 内 FloatButtonPreview 的有界卡片形态一致；
    // 背景改纯色（而非渐变）——平滑渐变本身也是 PNG 压缩率差的主因，纯色块
    // 几乎无损压缩，同时仍能反衬出玻璃按钮的通透质感。
    ZStack {
        Color.indigo

        VStack(spacing: CoreSpacing.xl) {
            Button {} label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.extendedFloat)
            .foregroundStyle(.white)

            Button {} label: {
                Image(systemName: "paperplane")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
            }
            .buttonStyle(.circularGlass)
            .foregroundStyle(.white)
        }
        .padding(CoreSpacing.xxxl)
    }
    .frame(width: 320, height: 280)
    .clipShape(CoreShape.rounded(CoreRadius.large))
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Carousel") {
    CarouselPreviewsPreviewGallery()
        .frame(height: 160)
        .padding()
        .background(Color.surfaceCanvas)
}

private struct CarouselPreviewsPreviewGalleryItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreviewsPreviewGallery: View {
    private let cards: [CarouselPreviewsPreviewGalleryItem] = [
        CarouselPreviewsPreviewGalleryItem(id: 0, title: "第一页", color: .blue),
        CarouselPreviewsPreviewGalleryItem(id: 1, title: "第二页", color: .purple),
        CarouselPreviewsPreviewGalleryItem(id: 2, title: "第三页", color: .orange),
    ]

    var body: some View {
        Carousel(self.cards, autoAdvance: false) { item in
            CoreShape.rounded(CoreRadius.large)
                .fill(item.color.gradient)
                .overlay {
                    Text(item.title)
                        .coreFont(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, CoreSpacing.xs)
        }
    }
}

#Preview("AnchoredBadge") {
    VStack(alignment: .leading, spacing: CoreSpacing.xxl) {
        HStack(spacing: CoreSpacing.xl) {
            Avatar(name: "Evan", size: .fixed(CoreSpacing.xxxxl)).clipShape(Circle())
                .anchoredBadge(.dot, hostShape: .circle)
            Avatar(name: "Aurora", size: .fixed(CoreSpacing.xxxxl)).clipShape(Circle())
                .anchoredBadge(.count(120, max: 99), hostShape: .circle)
            Avatar(name: "OhMyDesign", size: .fixed(CoreSpacing.huge)).clipShape(Circle())
                .anchoredBadge(.text("NEW"), hostShape: .circle)
        }
        HStack(spacing: CoreSpacing.xxl) {
            Image(systemName: "bell.fill").font(.title).anchoredBadge(.dot)
            Image(systemName: "envelope.fill").font(.title).anchoredBadge(.count(7))
            Image(systemName: "gift.fill").font(.title).anchoredBadge(.text("NEW"), placement: .topLeading)
        }
    }
    .padding(CoreSpacing.xl)
    .background(Color.surfaceCanvas)
}

#Preview("Spinning") {
    VStack(spacing: CoreSpacing.lg) {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
        .spinning(true, text: "Refreshing…")
    }
    .padding()
    .background(Color.surfaceCanvas)
}
