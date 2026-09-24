# Timeline

数据驱动的纵向时间线：节点（node）+ 连线（line）+ 节点右侧内容（content）/ Data-driven
vertical timeline: node + connecting line + trailing content.

节点状态色**直接复用 `StatusLevel`**（`info/success/warning/danger/neutral`），不新增公开状态语义
枚举；连线颜色复用 `Color.dividerDefault`。承接
`.claude/epics/semi-mobile-components/phase0-decisions.md` §1 的架构决定。

## API

### TimelineItem

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| id | UUID | UUID() | stable identity |
| status | StatusLevel | .info | 节点状态，决定默认圆点颜色（自定义 `node` 时仅作语义标记，不驱动颜色） |
| node | @ViewBuilder（可选） | 默认圆点 | 自定义节点视图（图标 / 头像等），完全替代默认圆点 |
| content | @ViewBuilder | - | 节点右侧内容，任意视图 |

两个 designated init：
- `TimelineItem(id:status:content:)` —— 省略 `node`，使用默认圆点。
- `TimelineItem(id:status:node:content:)` —— 显式传 `node`，自定义节点视图。

### Timeline

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [TimelineItem] | - | 时间线节点数据，按数组顺序排列 |
| layout | TimelineLayout | .vertical | 整体排布形态，见下表。默认 `.vertical` = 现状形态 ⇒ 现有调用方零影响 |

### `TimelineLayout`（`#60` 形态 D2「配置枚举」）

决定「这组节点怎么**排**」，与 `TimelineItem.node:` 外观槽（「单个节点画成什么」）**正交**
——槽管单节点画法，够不着容器级排布。

| case | 说明 | 业界来源 |
|---|---|---|
| `.vertical` | 默认：左侧节点列（列宽取最宽节点、下限 24pt）+ 右侧内容，节点间竖向连线（现状形态） | —— |
| `.alternate` | 左右交替：节点恒在**中轴**，内容按索引奇偶在两侧交替 | Ant Design Timeline `mode="alternate"` |
| `.horizontal` | 横向：节点沿水平轴排列，节点间有连线，内容在节点下方（可横向滚动） | PowerPoint SmartArt Basic Timeline / Final Cut Pro 横向事件线 |
| `.grouped` | 无连线的分组列表：删掉节点列与连线，只留内容 | Apple 邮件 / 信息的日期分组、GitHub 活动流 |

⚠️ **正交性的代价**（有意的静默，传了不生效**不报错**）：`.grouped` 不渲染节点列 ⇒
`TimelineItem.node:` 槽**不生效**。存储层原样保留 `node`，切回其余布局时不丢配置。
`.horizontal` 原写不画节点间连线，`#420` 起画（连线端点取自容器级布局算出的节点盒边沿，不再依赖纵向 padding）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
// 默认圆点节点
Timeline(items: [
    TimelineItem(status: .info) {
        Text("已创建")
    },
    TimelineItem(status: .success) {
        Text("审核通过")
    },
    TimelineItem(status: .warning) {
        Text("即将过期提醒")
    },
    TimelineItem(status: .danger) {
        Text("处理失败")
    },
])

// 自定义节点（图标替代默认圆点）+ 富内容
Timeline(items: [
    TimelineItem(status: .success) {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.statusSuccessEmphasis)
    } content: {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            Text("订单已发货")
            Text("2026-07-25 10:00").font(.footnote).foregroundStyle(.secondary)
        }
    },
])
```

> **stable identity 提示**：`TimelineItem.id` 缺省由 `UUID()` 生成。若 `Timeline` 由外部
> 可变状态驱动（增删节点），调用方应显式传入稳定 `id`，否则每次视图刷新重建
> `TimelineItem` 会产生新 identity，引发不必要的插入/删除动画。

```swift
// 左右交替：节点恒在中轴，内容按索引奇偶换边
Timeline(items: items, layout: .alternate)

// 横向：节点沿水平轴排列，节点间有连线，内容在节点下方（可横向滚动）
Timeline(items: items, layout: .horizontal)

// 分组列表：删掉节点列与连线，只留内容（node: 槽在此形态下不生效）
Timeline(items: items, layout: .grouped)
```

## 布局

`.vertical` / `.alternate` / `.horizontal` 由同一个容器级 `Layout`（`TimelineStackLayout`）单遍排版，
节点、内容、连线都是它的子视图：

- **节点盒**：节点收到 `24×24pt` 的提议（`Circle()` 这类弹性视图因此仍画成 24pt），节点盒取它
  报告的尺寸、下限 `24pt`，节点在盒内居中。≤ 24×24 的节点（默认圆点、SF Symbol、20pt 圆）与旧实现逐点相同；
  更大的节点（如 40pt 头像）不再溢出，而是撑宽整列 / 撑高本行。
- **`.vertical`**：节点列宽取所有节点盒里最宽的那个（跨行统一，内容左缘对齐）；内容从
  `列宽 + CoreSpacing.md` 起。非末行行高 `max(盒高 + CoreSpacing.sm, 内容高 + CoreSpacing.lg)`，末行
  `max(盒高, 内容高)`——内容高 ≥ 16pt 时与旧式 `max(24, 内容高 + lg)` 相同；更矮的内容行多出一小段
  （节点下方至少留 `sm` 的连线）。连线从本行节点盒**实际下沿**画到下一行节点盒**实际上沿**，不穿过高节点。
- **`.alternate`**：`弹性左槽 | 节点列 | 弹性右槽`，节点列宽同上跨行取最大、中轴恒在行宽一半处；
  内容按行序奇偶换边，行高与连线端点同 `.vertical`；固有宽度超过槽宽的内容向外（远离中轴）溢出，不压节点。
- **`.horizontal`**：外层 `ScrollView(.horizontal)`；横轴在最高节点盒的一半处，所有节点中心落在横轴上，
  内容顶统一在 `最高盒高 + CoreSpacing.sm`；列宽 `max(盒宽, 内容理想宽)`、列间距 `CoreSpacing.lg`；
  连线在横轴上，从前一盒右沿画到后一盒左沿。
- **`.grouped`**：`VStack(spacing: CoreSpacing.md)`，只摆内容，不摆节点、不画连线。
- RTL 下整体水平镜像（自定义 `Layout` 自动镜像）。

## 规模

容器级 `Layout` 必须拿到全部子视图才能算出跨行列宽 ⇒ **架构上不支持惰性**（不能放进 `LazyVStack` 按需实例化）。
粗测量级（macOS、`-O`、`ScrollView` 内，spec 探针读数，非基准）：n = 300 首次布局约 80 ms、一行内容变宽触发的重排约
17 ms；n = 1000 首次约 1 s、重排 160–355 ms（会掉帧）。带 `Text(date, style: .relative)` 这类每分钟刷新内容的
超长时间线（数百行以上）请分页或截断；惰性管线（调用方显式给列宽）不在本组件当前范围内。

## 视觉 Token

- 节点盒：提议 `24×24pt`，取节点报告尺寸、下限 `24pt`；节点列宽取最宽节点；默认圆点直径 `10pt`
- 默认圆点颜色：`StatusColors` emphasis 档，按 `StatusLevel` 映射——
  `info → statusAccentEmphasis` / `success → statusSuccessEmphasis` /
  `warning → statusAttentionEmphasis` / `danger → statusDangerEmphasis`；
  `neutral` 不取状态色，取 `contentSecondary`
- 例外：**浅色**下 `warning` 取 `statusAttentionForeground`（与浅色 Banner warning 图标同色）——
  `statusAttentionEmphasis` 的浅色金黄对分组背景只有约 2:1，达不到非文本对比度 3:1；
  改后对 `systemGroupedBackground` 4.36:1、`systemBackground` 4.87:1（iOS 解析值）。暗色仍取 emphasis，不变
- 连线：`Color.dividerDefault`（= 系统 `separator` 色），`CoreBorderWidth.thin`（1pt）宽度——
  竖向长连线用 1pt 比 separator hairline（0.5pt）观感更实，是对 phase0「连线对齐 separator」
  决策的有意偏离（与 Steps 横向连线同源，指示性连线需强于分隔线；phase0/013 统一记录）
- 行间距：内容下方 `CoreSpacing.lg`、节点下方至少 `CoreSpacing.sm`（最后一条不追加）；节点列与 content 横向间距 `CoreSpacing.md`

## Accessibility

- 默认圆点节点携带 `accessibilityLabel`，取 Phase 0 预登记键
  （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2）：
  `StatusLevel.info/success/warning/danger/neutral` → `"Info"/"Success"/"Warning"/"Error"/"Neutral"`
  （`danger` 播报为 "Error"，比 "Danger" 对 VoiceOver 更清晰），经
  `Timeline.accessibilityLabelKey(for:)` 取键、`Text(LocalizedStringKey(...), bundle:
  .module)` 消费。
- **自定义 `node` 不叠加该 label**——自定义内容可能自带其他语义（例如头像 + 姓名），由
  调用方自行决定 accessibility 表达，本组件不代为覆盖。
- **`.grouped` 下补回状态语义**：该形态不渲染节点列，默认圆点原本挂在自己身上的
  `Info`/`Success`/`Warning`/`Error` 标签会随之消失。故对**无自定义 `node`** 的项，把同一
  个已登记键挂到 content 的 `accessibilityValue` 上（`Timeline.applyGroupedStatusValue(_:item:)`）
  ——用 `accessibilityValue` 而非 `accessibilityLabel`，避免覆盖调用方 content 自身的语义。
  传了 `node:` 的项**不补**：其无障碍表达由调用方决定，本形态既然不渲染那个节点，也就不
  替调用方臆造状态播报。
- 节点右侧 `content` 的 accessibility 语义完全由调用方内容自身决定（`Timeline` 不对其
  做 `.accessibilityElement(children: .combine)` 合并），保证 content 内若含多个可交互
  元素（如按钮）时 VoiceOver 仍能逐一定位。
