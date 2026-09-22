# 参考实现取证报告

取证时间：2026-09-23。本报告只做取证（源码 + 文档摘录 + 行为描述），不做设计判断、不做移植建议。

抓取方法说明：`reui.io` 与 `ui.aceternity.com` 的组件页面是 RSC 流页面，`WebFetch` 对 `/components/...` 页面本身部分可读（用于 docs 摘要），但完整源码来自 shadcn 兼容的注册表 JSON 端点 `https://<origin>/r/<slug>.json`（对 reui 需要 `-L` 跟随 307 重定向到 `https://reui.io/r/styles/base-nova/<slug>.json`）。两个站点该端点均可用，逐字返回组件源码。

---

## 一、reui.io Timeline 组件

- 文档页：https://reui.io/docs/components/base/timeline
- 组件页（12 个示例变体）：https://reui.io/components/timeline
- 源码取自：`https://reui.io/r/timeline.json`（基础组件）与 `https://reui.io/r/c-timeline-<1..12>.json`（示例变体，均 200，逐字返回）

### 1.1 完整源码（基础组件 `timeline.tsx`）

依赖：`@base-ui/react`（`merge-props`、`use-render`）、内部 `cn` 工具。无 `registryDependencies`。

```tsx
"use client"

import { createContext, useCallback, useContext, useState } from "react"
import { mergeProps } from "@base-ui/react/merge-props"
import { useRender } from "@base-ui/react/use-render"

import { cn } from "cn"

// Types
type TimelineContextValue = {
  activeStep: number
  setActiveStep: (step: number) => void
}

// Context
const TimelineContext = createContext<TimelineContextValue | undefined>(
  undefined
)

const useTimeline = () => {
  const context = useContext(TimelineContext)
  if (!context) {
    throw new Error("useTimeline must be used within a Timeline")
  }
  return context
}

// Components
interface TimelineProps extends useRender.ComponentProps<"div"> {
  defaultValue?: number
  value?: number
  onValueChange?: (value: number) => void
  orientation?: "horizontal" | "vertical"
}

function Timeline({
  defaultValue = 1,
  value,
  onValueChange,
  orientation = "vertical",
  className,
  render,
  children,
  ...props
}: TimelineProps) {
  const [activeStep, setInternalStep] = useState(defaultValue)

  const setActiveStep = useCallback(
    (step: number) => {
      if (value === undefined) {
        setInternalStep(step)
      }
      onValueChange?.(step)
    },
    [value, onValueChange]
  )

  const currentStep = value ?? activeStep

  const defaultProps = {
    className: cn(
      "group/timeline flex data-[orientation=horizontal]:w-full data-[orientation=horizontal]:flex-row data-[orientation=vertical]:flex-col",
      className
    ),
    "data-orientation": orientation,
    "data-slot": "timeline",
    children,
  }

  return (
    <TimelineContext.Provider
      value={{ activeStep: currentStep, setActiveStep }}
    >
      {useRender({
        defaultTagName: "div",
        render,
        props: mergeProps<"div">(defaultProps, props),
      })}
    </TimelineContext.Provider>
  )
}

// TimelineContent
function TimelineContent({
  className,
  render,
  children,
  ...props
}: useRender.ComponentProps<"div">) {
  const defaultProps = {
    className: cn("text-muted-foreground text-sm", className),
    "data-slot": "timeline-content",
    children,
  }

  return useRender({
    defaultTagName: "div",
    render,
    props: mergeProps<"div">(defaultProps, props),
  })
}

// TimelineDate
type TimelineDateProps = useRender.ComponentProps<"time">

function TimelineDate({
  className,
  render,
  children,
  ...props
}: TimelineDateProps) {
  const defaultProps = {
    className: cn(
      "mb-1 block font-medium text-muted-foreground text-xs group-data-[orientation=vertical]/timeline:max-sm:h-4",
      className
    ),
    "data-slot": "timeline-date",
    children,
  }

  return useRender({
    defaultTagName: "time",
    render,
    props: mergeProps<"time">(defaultProps, props),
  })
}

// TimelineHeader
function TimelineHeader({
  className,
  render,
  children,
  ...props
}: useRender.ComponentProps<"div">) {
  const defaultProps = {
    className: cn(className),
    "data-slot": "timeline-header",
    children,
  }

  return useRender({
    defaultTagName: "div",
    render,
    props: mergeProps<"div">(defaultProps, props),
  })
}

// TimelineIndicator
type TimelineIndicatorProps = useRender.ComponentProps<"div">

function TimelineIndicator({
  className,
  children,
  render,
  ...props
}: TimelineIndicatorProps) {
  const defaultProps = {
    "aria-hidden": true,
    className: cn(
      "group-data-[orientation=horizontal]/timeline:-top-6 group-data-[orientation=horizontal]/timeline:-translate-y-1/2 group-data-[orientation=vertical]/timeline:-left-6 group-data-[orientation=vertical]/timeline:-translate-x-1/2 absolute size-4 rounded-full border-2 border-primary/20 group-data-[orientation=vertical]/timeline:top-0 group-data-[orientation=horizontal]/timeline:left-0 group-data-completed/timeline-item:border-primary",
      className
    ),
    "data-slot": "timeline-indicator",
    children,
  }

  return useRender({
    defaultTagName: "div",
    render,
    props: mergeProps<"div">(defaultProps, props),
  })
}

// TimelineItem
interface TimelineItemProps extends useRender.ComponentProps<"div"> {
  step: number
}

function TimelineItem({
  step,
  className,
  render,
  children,
  ...props
}: TimelineItemProps) {
  const { activeStep } = useTimeline()

  const defaultProps = {
    className: cn(
      "group/timeline-item relative flex flex-1 flex-col gap-0.5 group-data-[orientation=vertical]/timeline:ms-8 group-data-[orientation=horizontal]/timeline:mt-8 group-data-[orientation=horizontal]/timeline:not-last:pe-8 group-data-[orientation=vertical]/timeline:not-last:pb-6 has-[+[data-completed]]:**:data-[slot=timeline-separator]:bg-primary",
      className
    ),
    "data-completed": step <= activeStep || undefined,
    "data-slot": "timeline-item",
    children,
  }

  return useRender({
    defaultTagName: "div",
    render,
    props: mergeProps<"div">(defaultProps, props),
  })
}

// TimelineSeparator
function TimelineSeparator({
  className,
  render,
  children,
  ...props
}: useRender.ComponentProps<"div">) {
  const defaultProps = {
    "aria-hidden": true,
    className: cn(
      "group-data-[orientation=horizontal]/timeline:-top-6 group-data-[orientation=horizontal]/timeline:-translate-y-1/2 group-data-[orientation=vertical]/timeline:-left-6 group-data-[orientation=vertical]/timeline:-translate-x-1/2 absolute self-start bg-primary/10 group-last/timeline-item:hidden group-data-[orientation=horizontal]/timeline:h-0.5 group-data-[orientation=vertical]/timeline:h-[calc(100%-1rem-0.25rem)] group-data-[orientation=horizontal]/timeline:w-[calc(100%-1rem-0.25rem)] group-data-[orientation=vertical]/timeline:w-0.5 group-data-[orientation=horizontal]/timeline:translate-x-4.5 group-data-[orientation=vertical]/timeline:translate-y-4.5",
      className
    ),
    "data-slot": "timeline-separator",
    children,
  }

  return useRender({
    defaultTagName: "div",
    render,
    props: mergeProps<"div">(defaultProps, props),
  })
}

// TimelineTitle
function TimelineTitle({
  className,
  render,
  children,
  ...props
}: useRender.ComponentProps<"h3">) {
  const defaultProps = {
    className: cn("font-medium text-sm", className),
    "data-slot": "timeline-title",
    children,
  }

  return useRender({
    defaultTagName: "h3",
    render,
    props: mergeProps<"h3">(defaultProps, props),
  })
}

export {
  Timeline,
  TimelineContent,
  TimelineDate,
  TimelineHeader,
  TimelineIndicator,
  TimelineItem,
  TimelineSeparator,
  TimelineTitle,
}
```

### 1.2 API 表面（来自文档页 prop 表，WebFetch 提取）

| 组件 | Prop | 类型 | 默认值 | 说明 |
|---|---|---|---|---|
| `Timeline` | `defaultValue` | `number` | `1` | 初始激活步骤（非受控） |
| `Timeline` | `value` | `number` | — | 当前激活步骤（受控） |
| `Timeline` | `onValueChange` | `(value: number) => void` | — | 激活步骤变化回调 |
| `Timeline` | `orientation` | `"horizontal" \| "vertical"` | `"vertical"` | 布局方向 |
| `TimelineItem` | `step` | `number` | — | **必填**，该 item 的步骤号 |
| `TimelineDate` / `TimelineTitle` / `TimelineIndicator` / `TimelineSeparator` / `TimelineHeader` / `TimelineContent` | `className` | `string` | — | 额外 CSS class（其余透传 `useRender.ComponentProps`） |

子组件构成：`Timeline` 提供 Context（`activeStep`/`setActiveStep`）→ `TimelineItem`（读取 `activeStep`，判定 `data-completed`）→ 内部再拆 `TimelineHeader`（容器）/`TimelineIndicator`（圆点，`aria-hidden`）/`TimelineSeparator`（连接线，`aria-hidden`）/`TimelineTitle`/`TimelineDate`/`TimelineContent`。所有子组件都基于 `@base-ui/react` 的 `useRender` + `mergeProps`，即支持 `render` prop 做多态渲染（类似 Radix `asChild`）。

### 1.3 交互与动效行为

- **状态机**：单一状态 `activeStep`（`number`），受控/非受控二选一（`value` 存在则受控，否则用内部 `useState`）。`TimelineItem` 通过 `step <= activeStep` 计算 `data-completed`，再靠 Tailwind 的 `group-data-completed/timeline-item:` 变体和 `has-[+[data-completed]]:**:data-[slot=timeline-separator]:bg-primary` 选择器把"已完成"样式（描边高亮、连接线变实心）级联到指示点和分隔线上——**没有 JS 动画/过渡时长**，纯 CSS 状态样式切换，没有 `transition`/`animation` class。
- **方向**：`orientation` 通过 `data-orientation` 属性驱动一整套 `group-data-[orientation=horizontal]/timeline:` 前缀的 Tailwind 变体，横纵向切换的是指示点/分隔线的绝对定位方向（`top`/`left`）与尺寸计算（`calc(100%-...)`），组件本身不处理任何手势或键盘事件。
- **无内建的"点击切换步骤"交互**：`setActiveStep` 只在 context 里暴露，基础组件的 12 个示例都没有调用它去做点击跳转——纯展示型时间线，`activeStep` 只由 `defaultValue`/`value` 静态设定。

### 1.4 可访问性

- `TimelineIndicator` 与 `TimelineSeparator` 都显式 `"aria-hidden": true`——纯装饰性视觉元素，不进无障碍树。
- `TimelineTitle` 渲染为 `<h3>`（默认 tag），`TimelineDate` 渲染为 `<time>`。
- **文档页没有专门的 Accessibility / Keyboard 章节**（WebFetch 核实：页面无相关文字）。组件本身不含任何键盘事件处理，因为它是纯展示组件，没有可交互的焦点元素。

### 1.5 官方文档示例用法（12 个变体，来自组件页与 registry 标题）

1. Basic timeline — 竖直基础用法（见 1.6 完整源码）
2. Timeline with roadmap
3. Timeline with order status
4. **Timeline with git activity** — icon 化指示点，见 1.6 完整源码
5. Timeline with milestones
6. Timeline with pipeline steps
7. Timeline with roadmap items
8. Vertical timeline（左对齐日期变体）
9. Horizontal timeline with leading labels
10. **Deployment log timeline** — 状态徽章（success/failed）+ 彩色指示点，见 1.6 完整源码
11. **Activity feed timeline with user avatars** — 指示点替换为头像，见 1.6 完整源码
12. Compact horizontal milestone timeline

文档页里另给出的分类描述（面向用户的营销文案）：左对齐日期、自定义指示点、图标集成、交替布局（左右穿插）、横向排列、横向+顶部指示点、彩色定制、紧凑路线图、活动流、部署历史（成功/失败可视化）、CI/CD 多步骤（含用户头像与可折叠详情）、Git 操作专用图标。

### 1.6 四个代表性示例的完整源码

**Basic timeline（`c-timeline-1`）**
```tsx
import {
  Timeline,
  TimelineContent,
  TimelineDate,
  TimelineHeader,
  TimelineIndicator,
  TimelineItem,
  TimelineSeparator,
  TimelineTitle,
} from "@/components/reui/timeline"

export function Pattern() {
  return (
    <Timeline defaultValue={2} className="w-full max-w-md">
      <TimelineItem step={1}>
        <TimelineHeader>
          <TimelineDate>March 2024</TimelineDate>
          <TimelineTitle>Project Initialized</TimelineTitle>
        </TimelineHeader>
        <TimelineIndicator />
        <TimelineSeparator />
        <TimelineContent>
          Successfully set up the project repository and initial architecture.
        </TimelineContent>
      </TimelineItem>

      <TimelineItem step={2}>
        <TimelineHeader>
          <TimelineDate>April 2024</TimelineDate>
          <TimelineTitle>Beta Release</TimelineTitle>
        </TimelineHeader>
        <TimelineIndicator />
        <TimelineSeparator />
        <TimelineContent>
          Launched the beta version for early testers and feedback.
        </TimelineContent>
      </TimelineItem>

      <TimelineItem step={3}>
        <TimelineHeader>
          <TimelineDate>June 2024</TimelineDate>
          <TimelineTitle>Official Launch</TimelineTitle>
        </TimelineHeader>
        <TimelineIndicator />
        <TimelineSeparator />
        <TimelineContent>
          The platform is now live for all users worldwide.
        </TimelineContent>
      </TimelineItem>
    </Timeline>
  )
}
```

**Timeline with git activity（`c-timeline-4`，节选到 icon 化指示点部分）**
```tsx
import {
  Timeline,
  TimelineContent,
  TimelineDate,
  TimelineHeader,
  TimelineIndicator,
  TimelineItem,
  TimelineSeparator,
  TimelineTitle,
} from "@/components/reui/timeline"

import { IconPlaceholder } from "@/app/(create)/components/icon-placeholder"

const gitActivity = [
  {
    id: 1,
    date: "15 minutes ago",
    title: "Forked Repository",
    description:
      "Forked the repository to create a new branch for development.",
    icon: <IconPlaceholder lucide="GitForkIcon" tabler="IconGitFork" hugeicons="GitForkIcon" phosphor="GitForkIcon" remixicon="RiGitForkLine" className="size-4" />,
  },
  // ...省略同构的 3 项（PR submitted / comparing branches / merged branch）
]

export function Pattern() {
  return (
    <Timeline defaultValue={3} className="w-full max-w-md">
      {gitActivity.map((item) => (
        <TimelineItem key={item.id} step={item.id} className="group-data-[orientation=vertical]/timeline:ms-10">
          <TimelineHeader>
            <TimelineSeparator className="group-data-[orientation=vertical]/timeline:-left-7 group-data-[orientation=vertical]/timeline:h-[calc(100%-1.5rem-0.25rem)] group-data-[orientation=vertical]/timeline:translate-y-6.5" />
            <TimelineTitle className="mt-0.5">{item.title}</TimelineTitle>
            <TimelineIndicator className="bg-primary/10 group-data-completed/timeline-item:bg-primary group-data-completed/timeline-item:text-primary-foreground flex size-6 items-center justify-center border-none group-data-[orientation=vertical]/timeline:-left-7">
              {item.icon}
            </TimelineIndicator>
          </TimelineHeader>
          <TimelineContent>
            {item.description}
            <TimelineDate className="mt-2 mb-0">{item.date}</TimelineDate>
          </TimelineContent>
        </TimelineItem>
      ))}
    </Timeline>
  )
}
```

**Deployment log timeline（`c-timeline-10`，状态徽章模式，节选）**
```tsx
import { Badge } from "@/components/reui/badge"
import {
  Timeline, TimelineContent, TimelineDate, TimelineHeader,
  TimelineIndicator, TimelineItem, TimelineSeparator, TimelineTitle,
} from "@/components/reui/timeline"
import { cn } from "cn"
import { IconPlaceholder } from "@/app/(create)/components/icon-placeholder"

const deployments = [
  { id: 1, title: "Production Deploy", date: "2 minutes ago", commit: "a1b2c3d", branch: "main", status: "success", duration: "42s" },
  // ...省略 3 项（staging success / preview failed / production success）
]

export function Pattern() {
  return (
    <div className="w-full max-w-xs">
      <Timeline defaultValue={4}>
        {deployments.map((deploy) => (
          <TimelineItem key={deploy.id} step={deploy.id} className="group-data-[orientation=vertical]/timeline:ms-10">
            <TimelineHeader>
              <TimelineSeparator className="bg-input! group-data-[orientation=vertical]/timeline:-left-7 group-data-[orientation=vertical]/timeline:h-[calc(100%-1.5rem-0.25rem)] group-data-[orientation=vertical]/timeline:translate-y-6.5" />
              <div className="flex items-center gap-2">
                <TimelineTitle className="text-sm">{deploy.title}</TimelineTitle>
                <Badge variant={deploy.status === "success" ? "success-light" : "destructive-light"} size="sm">
                  {deploy.status}
                </Badge>
              </div>
              <TimelineIndicator className={cn(
                "flex size-6 items-center justify-center border-none group-data-[orientation=vertical]/timeline:-left-7",
                deploy.status === "success" ? "bg-emerald-500 text-white" : "bg-destructive text-white"
              )}>
                {deploy.status === "success" ? <IconPlaceholder lucide="CheckIcon" tabler="IconCheck" hugeicons="Tick02Icon" phosphor="CheckIcon" remixicon="RiCheckLine" className="size-3.5" /> : <IconPlaceholder lucide="XIcon" tabler="IconX" hugeicons="MultiplicationSignIcon" phosphor="XIcon" remixicon="RiCloseLine" className="size-3.5" />}
              </TimelineIndicator>
            </TimelineHeader>
            <TimelineContent>
              <div className="text-muted-foreground flex items-center gap-3 text-xs">
                <span className="font-mono">{deploy.commit}</span><span>&middot;</span><span>{deploy.branch}</span><span>&middot;</span><span>{deploy.duration}</span>
              </div>
              <TimelineDate className="mt-1 mb-0">{deploy.date}</TimelineDate>
            </TimelineContent>
          </TimelineItem>
        ))}
      </Timeline>
    </div>
  )
}
```

**Activity feed timeline with user avatars（`c-timeline-11`，头像替代指示点，节选）**
```tsx
import {
  Timeline, TimelineContent, TimelineDate, TimelineHeader,
  TimelineIndicator, TimelineItem, TimelineSeparator,
} from "@/components/reui/timeline"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"

const activities = [
  { id: 1, user: "Alex Johnson", avatar: "...", action: "pushed 3 commits to", target: "main", date: "5 minutes ago" },
  // ...省略 4 项
]

export function Pattern() {
  return (
    <div className="w-full max-w-md">
      <Timeline defaultValue={5}>
        {activities.map((activity) => (
          <TimelineItem key={activity.id} step={activity.id} className="group-data-[orientation=vertical]/timeline:ms-10">
            <TimelineHeader>
              <TimelineSeparator className="bg-input! group-data-[orientation=vertical]/timeline:top-2 group-data-[orientation=vertical]/timeline:-left-8 group-data-[orientation=vertical]/timeline:h-[calc(100%-2.5rem)] group-data-[orientation=vertical]/timeline:translate-y-7" />
              <TimelineIndicator className="size-8 overflow-hidden rounded-full border-none group-data-[orientation=vertical]/timeline:-left-8">
                <Avatar className="size-8">
                  <AvatarImage src={activity.avatar} alt={activity.user} />
                  <AvatarFallback className="text-[10px]">{activity.user.split(" ").map((n) => n[0]).join("")}</AvatarFallback>
                </Avatar>
              </TimelineIndicator>
            </TimelineHeader>
            <TimelineContent>
              <p className="text-sm">
                <span className="font-medium">{activity.user}</span>{" "}
                <span className="text-muted-foreground">{activity.action}</span>{" "}
                <span className="font-medium">{activity.target}</span>
              </p>
              <TimelineDate className="mt-0.5 mb-0">{activity.date}</TimelineDate>
            </TimelineContent>
          </TimelineItem>
        ))}
      </Timeline>
    </div>
  )
}
```

---

## 二、reui.io Tree 组件

- 文档页：https://reui.io/docs/components/base/tree
- 组件页（7 个示例变体）：https://reui.io/components/tree
- 源码取自：`https://reui.io/r/tree.json`（基础组件）与 `https://reui.io/r/c-tree-<1..7>.json`（示例变体）
- **底层引擎**：`@headless-tree/core` + `@headless-tree/react`（Lukas Bach 的 headless tree 库）—— reui 的 `Tree`/`TreeItem`/`TreeItemLabel` 只是给 headless-tree 的无头状态套上 `data-slot` + Tailwind 样式，真正的树状态机、键盘导航、拖拽逻辑都在 headless-tree 里，reui 本身不实现。

### 2.1 完整源码（基础组件 `tree.tsx`）

依赖：`@base-ui/react`、`@headless-tree/core`（仅类型 `ItemInstance`）、`cn`。

```tsx
/* eslint-disable @typescript-eslint/no-explicit-any */
"use client"

import { createContext, useContext } from "react"
import { mergeProps } from "@base-ui/react/merge-props"
import { useRender } from "@base-ui/react/use-render"
import type { ItemInstance } from "@headless-tree/core"

import { cn } from "cn"
import { IconPlaceholder } from "@/app/(create)/components/icon-placeholder"

type ToggleIconType = "chevron" | "plus-minus"

interface TreeContextValue<T = any> {
  indent: number
  currentItem?: ItemInstance<T>
  tree?: any
  toggleIconType?: ToggleIconType
}

const TreeContext = createContext<TreeContextValue>({
  indent: 20,
  currentItem: undefined,
  tree: undefined,
  toggleIconType: "plus-minus",
})

function useTreeContext<T = any>() {
  return useContext(TreeContext) as TreeContextValue<T>
}

interface TreeProps extends React.HTMLAttributes<HTMLDivElement> {
  indent?: number
  tree?: any
  toggleIconType?: ToggleIconType
}

function Tree({
  indent = 20,
  tree,
  className,
  toggleIconType = "chevron",
  ...props
}: TreeProps) {
  const containerProps =
    tree && typeof tree.getContainerProps === "function"
      ? tree.getContainerProps()
      : {}
  const mergedProps = { ...props, ...containerProps }

  const { style: propStyle, ...otherProps } = mergedProps

  const mergedStyle = {
    ...propStyle,
    "--tree-indent": `${indent}px`,
  } as React.CSSProperties

  return (
    <TreeContext.Provider value={{ indent, tree, toggleIconType }}>
      <div
        data-slot="tree"
        style={mergedStyle}
        className={cn("flex flex-col", className)}
        {...otherProps}
      />
    </TreeContext.Provider>
  )
}

interface TreeItemProps<T = any> extends Omit<
  useRender.ComponentProps<"button">,
  "indent"
> {
  item: ItemInstance<T>
  indent?: number
}

function TreeItem<T = any>({
  item,
  className,
  render,
  children,
  ...props
}: TreeItemProps<T>) {
  const parentContext = useTreeContext<T>()
  const { indent } = parentContext

  const itemProps = typeof item.getProps === "function" ? item.getProps() : {}
  const mergedProps = { ...props, children, ...itemProps }

  const { style: propStyle, ...otherProps } = mergedProps

  const mergedStyle = {
    ...propStyle,
    "--tree-padding": `${item.getItemMeta().level * indent}px`,
  } as React.CSSProperties

  const defaultProps = {
    "data-slot": "tree-item",
    style: mergedStyle,
    className: cn(
      "z-10 ps-(--tree-padding) outline-hidden select-none not-last:pb-0.5 focus:z-20 data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      className
    ),
    "data-focus":
      typeof item.isFocused === "function" ? item.isFocused() || false : undefined,
    "data-folder":
      typeof item.isFolder === "function" ? item.isFolder() || false : undefined,
    "data-selected":
      typeof item.isSelected === "function" ? item.isSelected() || false : undefined,
    "data-drag-target":
      typeof item.isDragTarget === "function" ? item.isDragTarget() || false : undefined,
    "data-search-match":
      typeof item.isMatchingSearch === "function" ? item.isMatchingSearch() || false : undefined,
    "aria-expanded": item.isExpanded(),
  }

  return (
    <TreeContext.Provider value={{ ...parentContext, currentItem: item }}>
      {useRender({
        defaultTagName: "button",
        render,
        props: mergeProps<"button">(defaultProps, otherProps),
      })}
    </TreeContext.Provider>
  )
}

interface TreeItemLabelProps<T = any> extends React.HTMLAttributes<HTMLSpanElement> {
  item?: ItemInstance<T>
}

function TreeItemLabel<T = any>({
  item: propItem,
  children,
  className,
  ...props
}: TreeItemLabelProps<T>) {
  const { currentItem, toggleIconType } = useTreeContext<T>()
  const item = propItem || currentItem

  if (!item) {
    console.warn("TreeItemLabel: No item provided via props or context")
    return null
  }

  return (
    <span
      data-slot="tree-item-label"
      className={cn(
        "in-focus-visible:ring-ring/50 bg-background hover:bg-accent in-data-[selected=true]:bg-accent in-data-[selected=true]:text-accent-foreground in-data-[drag-target=true]:bg-accent flex items-center gap-1 transition-colors not-in-data-[folder=true]:ps-7 in-focus-visible:ring-[3px] in-data-[search-match=true]:bg-blue-50! [&_svg]:pointer-events-none [&_svg]:shrink-0",
        "rounded-md",
        "py-1.5",
        "px-2",
        "text-sm",
        className
      )}
      {...props}
    >
      {item.isFolder() &&
        (toggleIconType === "plus-minus" ? (
          item.isExpanded() ? (
            <IconPlaceholder lucide="MinusIcon" tabler="IconMinus" hugeicons="MinusSignIcon" phosphor="MinusIcon" remixicon="RiSubtractLine" className="text-muted-foreground size-3.5" stroke="currentColor" strokeWidth="1" />
          ) : (
            <IconPlaceholder lucide="PlusIcon" tabler="IconPlus" hugeicons="PlusSignIcon" phosphor="PlusIcon" remixicon="RiAddLine" className="text-muted-foreground size-3.5" stroke="currentColor" strokeWidth="1" />
          )
        ) : (
          <IconPlaceholder lucide="ChevronDownIcon" tabler="IconChevronDown" hugeicons="ArrowDown01Icon" phosphor="CaretDownIcon" remixicon="RiArrowDownSLine" className="text-muted-foreground size-4 in-aria-[expanded=false]:-rotate-90" />
        ))}
      {children ||
        (typeof item.getItemName === "function" ? item.getItemName() : null)}
    </span>
  )
}

function TreeDragLine({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  const { tree } = useTreeContext()

  if (!tree || typeof tree.getDragLineStyle !== "function") {
    console.warn(
      "TreeDragLine: No tree provided via context or tree does not have getDragLineStyle method"
    )
    return null
  }

  const dragLine = tree.getDragLineStyle()
  return (
    <div
      style={dragLine}
      className={cn(
        "bg-primary before:bg-background before:border-primary absolute z-30 -mt-px h-0.5 w-[unset] before:absolute before:-top-[3px] before:left-0 before:size-2 before:border-2",
        "before:rounded-full",
        className
      )}
      {...props}
    />
  )
}

export { Tree, TreeItem, TreeItemLabel, TreeDragLine }
```

### 2.2 API 表面（来自文档页 prop 表 + 源码交叉核对）

| 组件 | Prop | 类型 | 默认值 | 说明 |
|---|---|---|---|---|
| `Tree` | `tree` | `any`（headless-tree 的 `useTree()` 返回值） | — | 必填，树实例 |
| `Tree` | `indent` | `number` | `20` | 每级缩进像素，写入 CSS 变量 `--tree-indent` |
| `Tree` | `toggleIconType` | `"chevron" \| "plus-minus"` | 源码默认 `"chevron"`；文档页表格写的也是 `"chevron"`（此前一版报告草稿误记为 `"plus-minus"`，已订正——源码 `Tree` 组件的解构默认值明确是 `toggleIconType = "chevron"`；`TreeContext` 的初始值虽是 `"plus-minus"`，但只在没有 `Tree.Provider` 包裹时才会用到，实际渲染路径不会触发） | 折叠图标样式：chevron 旋转 or 加减号 |
| `TreeItem` | `item` | `ItemInstance<T>` | — | 必填，headless-tree 的 item 实例 |
| `TreeItem` | `indent` | `number` | — | 类型声明存在，但源码函数体内**未使用**该局部 prop（缩进实际取自 context 里的 `indent`，通过 `item.getItemMeta().level * indent` 计算）——文档页称其可覆盖单项缩进，与源码行为不符，以源码为准登记为文档与实现不一致 |
| `TreeItemLabel` | `item` | `ItemInstance<T>`（可选） | — | 不传则从 context 取 `currentItem` |
| `TreeDragLine` | `className` | `string` | — | 拖拽指示线，样式来自 `tree.getDragLineStyle()` |

子组件构成：`Tree`（容器 + `TreeContext.Provider`，注入 `indent`/`tree`/`toggleIconType`）→ `TreeItem`（每一行，`data-slot="tree-item"`，把 `item.isFocused/isFolder/isSelected/isDragTarget/isMatchingSearch` 映射成 `data-*` 属性驱动样式，`aria-expanded` 显式设置）→ `TreeItemLabel`（视觉行内容，folder 展开图标 + 名称，靠 `in-data-[selected=true]:` 等 Tailwind "in-*" 变体读父级 `data-*`）→ `TreeDragLine`（拖拽时的插入位置指示线，是否渲染取决于业务代码是否在拖拽 feature 打开时挂载它）。

### 2.3 交互与状态机 / 键盘导航

reui 自己的组件层**不含任何事件处理代码**（没有 `onKeyDown`、没有 `onClick`）——`TreeItem` 通过 `item.getProps()` 把 headless-tree 生成的全部事件处理器展开合并进 DOM 属性（`mergedProps = { ...props, children, ...itemProps }`），键盘/点击/拖拽行为完全由 `@headless-tree/core` 的 feature 模块提供。示例代码里统一引入两个 feature：

```ts
import { hotkeysCoreFeature, syncDataLoaderFeature } from "@headless-tree/core"
// ...
features: [syncDataLoaderFeature, hotkeysCoreFeature],
```

`hotkeysCoreFeature` 即键盘导航的开关。**键盘行为文档不在 reui.io 上**，取自 headless-tree 官方文档 `https://headless-tree.lukasbach.com/guides/accessibility/`（WebFetch 摘录，原文引用）：

- "All relevant aria attributes are provided to the tree and its items automatically."（遵循 W3C ARIA "Navigation Treeview Pattern"）
- 方向键：标准上下移动焦点；"Pressing `Left` will collapse the currently focused item if it is open, or move the focus to the parent item if it is closed"；"Pressing `Right` will expand the currently focused item if it is closed, or move the focus to the first child"
- 多选：`Shift` + 方向键扩展选区；`Ctrl+Space` 切换当前焦点项选中；`Ctrl+A` 全选
- `Home`/`End`：跳到第一项/最后一项
- 重命名：`F2` 进入重命名，`Escape` 取消、`Enter` 确认
- 类型提前搜索（type-ahead）：聚焦树内直接打字会打开搜索输入框，上下键在搜索结果间移动
- 另据 WebSearch 摘要（未逐字核实原文，标注为二手来源）：`expandAllFeature` 提供 `Ctrl+Shift+Plus`（展开所选及其所有后代）/`Ctrl+Shift+Minus`（折叠）等额外 hotkey；hotkey 绑定可在 `useTree` 配置里覆盖；有 `ignoreHotkeysOnInput` 选项在输入框聚焦时屏蔽热键。

⚠️ 以上键盘细节属于 headless-tree 库文档，不是 reui.io 的 Tree 文档页内容——WebFetch 已确认 reui.io 该页**没有**任何键盘/无障碍说明文字，只在示例代码里能看到 `hotkeysCoreFeature` 的引用。

### 2.4 可访问性（reui 层面能实测到的部分）

- `TreeItem` 渲染为 `<button>`（`defaultTagName: "button"`），天然可聚焦、可用 Enter/Space 激活。
- 显式 `aria-expanded={item.isExpanded()}`。
- 视觉状态（选中/焦点/拖拽目标/搜索命中）全部走 `data-*` 属性 + CSS，不额外设置 `aria-selected` 等——选中态的无障碍语义依赖 headless-tree 内部是否自动补充（reui 组件源码本身未见 `aria-selected`/`role="treeitem"`/`role="tree"` 字样，这些很可能由 `item.getProps()`/`tree.getContainerProps()` 注入，但**这部分内部实现不在 reui 的注册表源码里**，无法从本次抓到的文件确认）。

### 2.5 官方文档示例用法（7 个变体）

1. Basic tree — 标准可展开/折叠层级结构
2. Tree with indented lines — 用 CSS 渐变画竖直连接线表示层级
3. Tree with custom indent（×2，registry 标题重复，两个不同的自定义缩进示例）
4. **File explorer tree with type icons** — 按文件类型显示不同图标，见 2.6 完整源码
5. Organization chart tree with avatars
6. **Permissions tree with checkboxes** — 叶子节点带受控 `Checkbox`，见 2.6 完整源码

（文档页 WebFetch 摘要只列出 4 个"演示变体"：Basic / With line / With Icon / With Plus and Minus Icons——与 registry 里 7 个 block 标题对不齐，可能是页面只挑了代表性的几个做视觉演示，registry 里还有 org chart / permissions 两个未在页面正文单独强调的变体。两者并存记录，不强行统一。）

**没有找到官方的"拖拽重排"或"多选"完整示例**——`TreeDragLine` 组件存在，`tree.getDragLineStyle()` 接口存在，但 7 个 registry 示例里没有一个引入拖拽 feature（`dragAndDropFeature` 之类）或渲染 `<TreeDragLine />`，也没有一个示例展示多选（`Ctrl+Space`/`Shift+方向键`）的视觉反馈。列入下方"取不到的部分"。

### 2.6 两个代表性示例的完整源码

**Basic tree（`c-tree-1`）**
```tsx
"use client"

import {
  Tree,
  TreeItem,
  TreeItemLabel,
} from "@/components/reui/tree"
import { hotkeysCoreFeature, syncDataLoaderFeature } from "@headless-tree/core"
import { useTree } from "@headless-tree/react"

interface Item {
  name: string
  children?: string[]
}

const items: Record<string, Item> = {
  crm: { name: "CRM", children: ["leads", "accounts", "activities", "support"] },
  leads: { name: "Leads", children: ["new-lead", "contacted-lead", "qualified-lead"] },
  "new-lead": { name: "New Lead" },
  // ...省略其余 18 个节点定义（accounts/globex/activities/support 子树）
}

const indent = 20

export function Pattern() {
  const tree = useTree<Item>({
    initialState: { expandedItems: ["leads", "accounts", "activities"] },
    indent,
    rootItemId: "crm",
    getItemName: (item) => item.getItemData().name,
    isItemFolder: (item) => (item.getItemData()?.children?.length ?? 0) > 0,
    dataLoader: {
      getItem: (itemId) => items[itemId],
      getChildren: (itemId) => items[itemId].children ?? [],
    },
    features: [syncDataLoaderFeature, hotkeysCoreFeature],
  })

  return (
    <div className="mx-auto w-full grow place-self-start lg:w-xs">
      <Tree indent={indent} tree={tree}>
        {tree.getItems().map((item) => (
          <TreeItem key={item.getId()} item={item}>
            <TreeItemLabel />
          </TreeItem>
        ))}
      </Tree>
    </div>
  )
}
```

**Permissions tree with checkboxes（`c-tree-7`，受控多选状态，完整）**
```tsx
import { hotkeysCoreFeature, syncDataLoaderFeature } from "@headless-tree/core"
import { useTree } from "@headless-tree/react"
import { Checkbox } from "@/components/ui/checkbox"

interface PermissionItem {
  name: string
  children?: string[]
}

const items: Record<string, PermissionItem> = {
  permissions: { name: "All Permissions", children: ["users", "content", "billing", "api"] },
  users: { name: "User Management", children: ["users-view", "users-create", "users-edit", "users-delete"] },
  "users-view": { name: "View users" },
  // ...省略其余 14 个叶子/分组节点
}

const indent = 24

export function Pattern() {
  const [checked, setChecked] = useState<Set<string>>(
    new Set(["users-view", "content-view", "content-publish", "billing-view", "api-read"])
  )

  const togglePermission = (id: string) => {
    setChecked((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const tree = useTree<PermissionItem>({
    initialState: { expandedItems: ["users", "content"] },
    indent,
    rootItemId: "permissions",
    getItemName: (item) => item.getItemData().name,
    isItemFolder: (item) => (item.getItemData()?.children?.length ?? 0) > 0,
    dataLoader: {
      getItem: (itemId) => items[itemId],
      getChildren: (itemId) => items[itemId].children ?? [],
    },
    features: [syncDataLoaderFeature, hotkeysCoreFeature],
  })

  return (
    <div className="mx-auto w-full grow place-self-start lg:w-xs">
      <Tree indent={indent} tree={tree} toggleIconType="plus-minus" className="">
        {tree.getItems().map((item) => {
          const id = item.getId()
          const isLeaf = !item.isFolder()
          return (
            <TreeItem key={id} item={item}>
              <TreeItemLabel className="not-in-data-[folder=true]:ps-5">
                <span className="flex items-center gap-2">
                  {isLeaf && (
                    <Checkbox
                      checked={checked.has(id)}
                      onCheckedChange={() => togglePermission(id)}
                      className="size-3.5"
                      onClick={(e) => e.stopPropagation()}
                    />
                  )}
                  {item.getItemName()}
                </span>
              </TreeItemLabel>
            </TreeItem>
          )
        })}
      </Tree>
    </div>
  )
}
```
（关键细节：`Checkbox` 的 `onClick` 显式 `e.stopPropagation()`，防止点击复选框时把点击事件冒泡触发到 `TreeItem` 的 button——即勾选与展开/选中是两套独立的点击目标，checkbox 状态由业务代码用 `Set<string>` 自行管理，不是 headless-tree 内建的选择状态。）

**File explorer tree with type icons（`c-tree-5`，按文件类型切图标，节选）**
```tsx
const getFileIcon = (type?: string, isExpanded?: boolean) => {
  if (!type || type === "folder") {
    return isExpanded
      ? <IconPlaceholder lucide="FolderOpenIcon" ... />
      : <IconPlaceholder lucide="FolderIcon" ... />
  }
  if (type === "tsx" || type === "ts") return <IconPlaceholder lucide="FileCodeIcon" ... />
  if (type === "css") return <IconPlaceholder lucide="PaletteIcon" ... />
  if (type === "json") return <IconPlaceholder lucide="BracesIcon" ... />
  if (type === "md") return <IconPlaceholder lucide="FileTextIcon" ... />
  return <IconPlaceholder lucide="FileIcon" ... />
}
// Tree 渲染部分与 Basic tree 相同结构，TreeItemLabel 内手动拼 getFileIcon(...) + item.getItemName()
```

---

## 三、Aceternity UI Stateful Button

- 文档页：https://ui.aceternity.com/components/stateful-button
- 源码取自：`https://ui.aceternity.com/registry/stateful-button.json`（组件）与 `https://ui.aceternity.com/registry/stateful-button-demo.json`（用法示例，均含完整 `content` 字段，200）
- 安装方式（文档页给出）：`npx shadcn@latest add @aceternity/stateful-button`

### 3.1 完整源码（`components/ui/stateful-button.tsx`）

依赖：`motion/react`（Framer Motion 的新包名）、内部 `cn`。

```tsx
"use client";
import { cn } from "@/lib/utils";
import React from "react";
import { motion, AnimatePresence, useAnimate } from "motion/react";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  className?: string;
  children: React.ReactNode;
}

export const Button = ({ className, children, ...props }: ButtonProps) => {
  const [scope, animate] = useAnimate();

  const animateLoading = async () => {
    await animate(
      ".loader",
      { width: "20px", scale: 1, display: "block" },
      { duration: 0.2 },
    );
  };

  const animateSuccess = async () => {
    await animate(
      ".loader",
      { width: "0px", scale: 0, display: "none" },
      { duration: 0.2 },
    );
    await animate(
      ".check",
      { width: "20px", scale: 1, display: "block" },
      { duration: 0.2 },
    );

    await animate(
      ".check",
      { width: "0px", scale: 0, display: "none" },
      { delay: 2, duration: 0.2 },
    );
  };

  const handleClick = async (event: React.MouseEvent<HTMLButtonElement>) => {
    await animateLoading();
    await props.onClick?.(event);
    await animateSuccess();
  };

  const {
    onClick,
    onDrag,
    onDragStart,
    onDragEnd,
    onAnimationStart,
    onAnimationEnd,
    ...buttonProps
  } = props;

  return (
    <motion.button
      layout
      layoutId="button"
      ref={scope}
      className={cn(
        "flex min-w-[120px] cursor-pointer items-center justify-center gap-2 rounded-full bg-green-500 px-4 py-2 font-medium text-white ring-offset-2 transition duration-200 hover:ring-2 hover:ring-green-500 dark:ring-offset-black",
        className,
      )}
      {...buttonProps}
      onClick={handleClick}
    >
      <motion.div layout className="flex items-center gap-2">
        <Loader />
        <CheckIcon />
        <motion.span layout>{children}</motion.span>
      </motion.div>
    </motion.button>
  );
};

const Loader = () => {
  return (
    <motion.svg
      animate={{ rotate: [0, 360] }}
      initial={{ scale: 0, width: 0, display: "none" }}
      style={{ scale: 0.5, display: "none" }}
      transition={{ duration: 0.3, repeat: Infinity, ease: "linear" }}
      xmlns="http://www.w3.org/2000/svg"
      width="24" height="24" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      className="loader text-white"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path d="M12 3a9 9 0 1 0 9 9" />
    </motion.svg>
  );
};

const CheckIcon = () => {
  return (
    <motion.svg
      initial={{ scale: 0, width: 0, display: "none" }}
      style={{ scale: 0.5, display: "none" }}
      xmlns="http://www.w3.org/2000/svg"
      width="24" height="24" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      className="check text-white"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path d="M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0" />
      <path d="M9 12l2 2l4 -4" />
    </motion.svg>
  );
};
```

### 3.2 官方用法示例（`components/stateful-button-demo.tsx`，完整）

```tsx
"use client";

import React from "react";
import { Button } from "@/components/ui/stateful-button";

export default function StatefulButtonDemo() {
  // dummy API call
  const handleClick = () => {
    return new Promise((resolve) => {
      setTimeout(resolve, 4000);
    });
  };
  return (
    <div className="flex h-40 w-full items-center justify-center">
      <Button onClick={handleClick}>Send message</Button>
    </div>
  );
}
```

### 3.3 API 表面

| Prop | 类型 | 默认 | 说明 |
|---|---|---|---|
| `className` | `string` | — | 与默认样式合并（`cn`），默认样式含 `bg-green-500`/`rounded-full`/`hover:ring-2` |
| `children` | `React.ReactNode` | — | 按钮文案/内容，用 `motion.span layout` 包裹，随宽度变化自动 layout 动画 |
| `onClick` | `(event) => void \| Promise<void>` | — | 可以是 async，`handleClick` 内部会 `await props.onClick?.(event)` |
| 其余 | `React.ButtonHTMLAttributes<HTMLButtonElement>` | — | 标准 button 属性透传，但**显式排除**接管 `onDrag`/`onDragStart`/`onDragEnd`/`onAnimationStart`/`onAnimationEnd`（因为 `motion.button` 自己要用这些事件名，和原生 button 的类型冲突，源码用解构方式把这几个从 `buttonProps` 里摘掉不透传给 DOM） |

组件构成：单一 `Button`（默认导出用的是具名导出 `Button`），内部两个私有子组件 `Loader`（转圈 SVG）与 `CheckIcon`（打钩 SVG），都用 class 名 `.loader` / `.check` 作为 `animate()` 的选择器目标——**不是**通过 React state 条件渲染切换，而是用 Motion 的 `animate(selector, keyframes, options)` 直接操作这两个固定挂载的 SVG 节点的内联样式（宽度/缩放/display）。

### 3.4 状态机（重点，逐行核对源码得出，不是转述文档）

三态：`idle → loading → success → idle`，由 `handleClick` 顺序 `await` 驱动，**没有独立的 state 变量**，状态完全体现在两个 DOM 节点的动画进度上：

1. **idle**：`Loader` 与 `CheckIcon` 初始 `scale: 0, width: 0, display: "none"`——都不可见。
2. **点击 → loading**：`animateLoading()` 把 `.loader` 动画到 `width: 20px, scale: 1, display: "block"`，耗时 `duration: 0.2`（秒）。`Loader` 自身有独立的 `rotate: [0,360]` 无限循环动画（`duration: 0.3`，`repeat: Infinity`，`ease: "linear"`）——即转圈动画在整个 loading 期间自转，转速与"是否完成"无关。
3. **等待业务 Promise**：`await props.onClick?.(event)`——等真实业务回调 resolve。**demo 里是 `setTimeout(resolve, 4000)`，即 4 秒**（这是 demo 的示例值，不是组件固定延迟；组件本身对 loading 时长没有上限或超时处理，完全由调用方的 `onClick` promise 决定，若 promise 永不 resolve，按钮会永远停在 loading）。
4. **success**：`animateSuccess()` 先把 `.loader` 缩回 `width:0, scale:0, display:"none"`（`duration:0.2`），再把 `.check` 放大到 `width:20px, scale:1, display:"block"`（`duration:0.2`）——**loader 和 check 的显隐是顺序的，不是并行 crossfade**。
5. **success 展示 2 秒后自动回到 idle**：`.check` 的第二个 `animate` 调用带 `delay: 2, duration: 0.2`，把 check 缩回 `display:"none"`——**没有再手动把状态"复位"，按钮本身没有维护状态变量，所以复位其实就是"再把 check 图标隐藏"，按钮本体（`motion.button`）从头到尾都可点击、没有被禁用过**。
6. 整个过程外层 `motion.button` 有 `layout` + `layoutId="button"`，配合 `motion.div layout` 和 `motion.span layout`——按钮宽度会随 loader/check 图标的显隐自动做 layout 过渡动画（Motion 的自动布局动画，不是手写的 width transition）。

⚠️ **组件本身没有禁用态**：点击后按钮没有被设置 `disabled`，`handleClick` 也没有做"防止重复点击"的锁——如果用户在 loading 期间再次点击，会重新触发一次 `handleClick`（并发调用 `animate(".loader", ...)` 等），这是源码里能看到、文档没提及的行为，值得在评估这个组件时留意（本报告只做记录，不做设计判断）。

### 3.5 可访问性

- 源码里**没有任何 `aria-*`、`role`、`aria-busy`、`aria-live` 属性**，也没有 `disabled` 状态阻止重复触发。
- 底层是原生 `<button>`（`motion.button` 渲染为 `button` 标签），所以有默认的键盘可聚焦/可用 Enter·Space 激活，但 loading/success 状态变化对屏幕阅读器**没有任何播报**（没有 `aria-live` region，纯视觉动画）。
- 文档页本身也没有 Accessibility 章节（WebFetch 已核实）。

---

## 四、滑动确认按钮（slide-to-confirm）调研

无官方组件页，全部来自 WebSearch + WebFetch 交叉验证的第三方实现，逐条标注来源与验证方式。

### 4.1 no-comment/SlideButton（SwiftUI，**已读取完整源码文件**，最有价值的一份）

- 仓库：https://github.com/no-comment/SlideButton
- 源码文件：`Sources/SlideButton/SlideButton.swift`（经 `raw.githubusercontent.com` 直接下载，256 行，逐行核对）

**API（`init`）**：
```swift
public init(styling: Styling = .default, action: @escaping () async -> Void, @ViewBuilder label: () -> Label)
// 便捷重载：
SlideButton("Slide to Unlock") { await unlockDevice() }
```
`Styling` 结构体字段（README + 源码交叉确认）：`indicatorSize`、`indicatorSpacing`、`indicatorColor`/`backgroundColor`、`textColor`、`indicatorSystemName`/`indicatorDisabledSystemName`、`textAlignment`、`textFadesOpacity`、`textHiddenBehindIndicator`、`textShimmers`、`indicatorShape`（`.circular` 或 `.rectangular(cornerRadius:)`）。

**状态机**：内部 `private enum SwipeState { case start, swiping, end }`（**不是**布尔"锁/解锁"，是三态过程状态）。

**阈值语义（源码，逐字核对）**：
```swift
.onEnded { value in
    guard swipeState == .swiping else { return }
    swipeState = .end

    let predictedVal = value.predictedEndTranslation.width * layoutDirectionMultiplier
    let val = value.translation.width * layoutDirectionMultiplier

    if predictedVal > reading.size.width
        || val > reading.size.width - styling.indicatorSize - 2 * styling.indicatorSpacing {
        Task {
            await callback()
            swipeState = .start
        }
    } else {
        swipeState = .start
        // 触觉反馈但不触发 callback
    }
}
```
即：触发条件是**两者取或**——(a) 实际拖拽位移 `val` 超过"容器宽度 − 指示器尺寸 − 2×间距"（近似滑到底），**或** (b) `predictedEndTranslation`（SwiftUI 手势自带的、基于释放时速度外推的预测终点）超过容器整宽——**后者意味着快速甩动、还没滑到底松手也能触发**，这是速度补偿机制，和纯距离阈值的实现不同。

**取消/回弹**：条件不满足时直接 `swipeState = .start`，配合 `.animation(.interactiveSpring(), value: swipeState)` 做弹簧回弹动画，无额外延时或二次确认。拖拽中途 `state = clampValue(...)` 把偏移量夹在 `[indicatorSpacing, width - indicatorSize + indicatorSpacing]` 之间，无法过冲。

**触发后状态表达**：`.overlay` 里用一个 `ProgressView().progressViewStyle(.circular)` 在 `swipeState == .end` 时 `opacity: 1`（否则 0）替换掉原本的 SF Symbol 图标——即触发瞬间指示器内部从图标切换成转圈 loading，`callback()` 是 `async`，等它 `await` 完再把 `swipeState` 设回 `.start`（滑块弹回起点）。

**可访问性替代路径（关键发现，README 未提及，源码里确有实现）**：
```swift
.accessibilityRepresentation {
    Button(action: {
        swipeState = .end
        Task {
            await callback()
            swipeState = .start
        }
    }, label: { title })
    .disabled(swipeState != .start)
}
```
即整个滑块视图通过 `accessibilityRepresentation` 向辅助技术（VoiceOver 等）暴露成一个**普通 `Button`**，直接点击/激活即可触发同一个 `callback`，不需要真的执行拖拽手势——这是本次调研里唯一一个**源码证实**做了无障碍替代路径的实现，而它的公开 README 完全没提这一点（README 只字未提 accessibility）。

### 4.2 A-Rehman01/react-slide-button（React，README/GitHub 页面摘录，未下载源码，未做逐行验证）

- 仓库：https://github.com/A-Rehman01/react-slide-button
- 阈值语义：`minSlideWidth`（默认 `0.6`，0–1 范围，"用户需要滑动到按钮宽度的百分之多少才算变成 slide state"）**或** `minSlideVelocity`（默认 `0.6`，速度阈值——"即使滑动距离小于 minSlideWidth，只要速度超过 minSlideVelocity 也会变成 slide state"），两者取或，逻辑结构上与上面 SwiftUI 版本的"距离阈值 OR 预测终点"高度相似（同一类设计模式：距离不够但足够快也算数）。
- 取消/回弹：`reset` prop——外部改变这个整数值即可把按钮强制复位到"non-slide state"，属于受控复位，不是内部自动回弹（README 未描述松手未达阈值时是否自动回弹，只描述了外部强制 reset 的机制，存疑，标注为未核实完整）。
- 触发后状态：`onSlideDone` 回调；未见有描述 loading/success 视觉。
- 可访问性：README 未提及任何无障碍处理。
- ⚠️ 尝试直接拉取 `raw.githubusercontent.com/.../README.md` 返回 404，只能靠 WebFetch 对 GitHub 页面渲染结果做摘要，**未做逐行源码核对**，以上描述以 WebFetch 摘要转述为准。

### 4.3 Arjun Kalburgi 博客《Creating a "Swipe-to-Confirm" Component》（原生 JS/CodePen 教程，网页摘录）

- 来源：https://www.arjunkalburgi.com/writing/creating-a-swipe-to-confirm-component/
- 阈值语义：滑到容器满宽才算确认（`if (currentX < dragWidth) { 回弹 } else { 确认 }`），是最朴素的"到底才算数"实现，**没有**速度补偿（与上面两个不同）。
- 取消/回弹：`setTranslate(0, dragItem)` 把滑块位移复位到 0，作者提到额外做了"an animation on fallback"（回弹动画），未给出具体缓动参数。
- 设计动机（作者原话转述）：这类组件存在的意义是"让用户比起可能被误触的按钮更有安全感"（deliberate full-width swipe vs. 容易被误触的 tap）。
- 触发后状态：`alert("Confirmed!")`——纯教程示例，非生产级状态表达。
- 可访问性：文章完全没有涉及。

### 4.4 无障碍的通用解法（Apple Developer Forums 帖子，网页摘录）

- 来源：https://developer.apple.com/forums/thread/729098（标题 "Swipe to confirm and accessibility"）
- 问题：开发者问"滑动确认预订"这类交互，对开启 VoiceOver 的用户是否构成障碍。
- Apple Frameworks 工程师的回复（关键句，原文引用）："Assistive technologies like VoiceOver, Switch Control, and even Voice Control drastically change how people physically interact with their device... Imagine that someone with limited movement might not be able to easily perform a gesture like swipe to confirm booking."
- 推荐方案：在承载滑动手势的视图上覆盖 **`accessibilityActivate()`**（VoiceOver 双击激活时调用，跑与滑动成功同一段业务逻辑）或提供 **`accessibilityCustomActions`**（挂一个如"Confirm Booking"的自定义动作），并确保该视图 `isAccessibilityElement == true`。
- **这与 4.1 里 SwiftUI `SlideButton` 用 `.accessibilityRepresentation` 暴露一个替代 `Button` 是同一思路的两种 API 实现**——`.accessibilityRepresentation` 是更高层的 SwiftUI 便利 API，效果等价于手写 `accessibilityActivate`。

### 4.5 三条实现的横向对照

| | SlideButton (SwiftUI) | react-slide-button (React) | Kalburgi 教程 (Vanilla JS) |
|---|---|---|---|
| 阈值语义 | 距离阈值 OR 预测终点（速度补偿） | `minSlideWidth`(0.6) OR `minSlideVelocity`(0.6) | 纯距离，必须到底 |
| 取消手势 | 松手未达阈值 → 自动弹簧回弹 | 未明确自动回弹；有外部 `reset` prop 强制复位 | 松手未达阈值 → 位移复位 + 回弹动画 |
| 触发后状态 | 指示器内切换成 `ProgressView`（loading），`await` 业务 Promise 后弹回起点 | `onSlideDone` 回调，未描述视觉状态 | `alert()`，无实际状态设计 |
| 无障碍替代路径 | **有**：`.accessibilityRepresentation` 暴露等效 `Button`，源码证实 | 未文档化 | 未涉及 |
| 验证深度 | 完整源码逐行核对 | 仅 WebFetch 摘要，未读源码 | 仅 WebFetch 摘要 |

---

## 五、取不到 / 不确定的部分

1. **reui.io Timeline / Tree 文档页的 Accessibility 章节**：WebFetch 两次确认页面**没有**专门的键盘/无障碍文字说明（不是没抓到，是页面本身没写）。Tree 的键盘行为改用底层 `@headless-tree/core` 的官方文档（`https://headless-tree.lukasbach.com/guides/accessibility/`）替代补充，已在报告里明确标注这是"底层库文档，不是 reui 自己的文档"。

2. **reui Tree 组件内部对 ARIA 的处理（`role="tree"`/`role="treeitem"`/`aria-selected` 等）**：本次抓到的 `tree.tsx` 源码里**没有**看到这些属性被显式设置，但 `item.getProps()` / `tree.getContainerProps()` 会把 headless-tree 内部生成的 props 展开合并进去——**这部分内部逻辑在 `@headless-tree/core` 包内部，不在 reui 的 registry 源码范围内，本次未追进 headless-tree 的包源码去确认**。如果需要精确核实，需要另外拉取 `@headless-tree/core` 的 npm 包源码或它自己的 GitHub 仓库。

3. **reui Tree 的拖拽重排（drag-and-drop）与多选完整示例**：`TreeDragLine` 组件与 `tree.getDragLineStyle()` 接口在基础组件源码里存在，但抓到的全部 7 个官方 registry 示例（`c-tree-1` 到 `c-tree-7`）**没有一个**引入 headless-tree 的拖拽 feature 或渲染 `<TreeDragLine />`，也没有一个展示多选交互的视觉反馈。尝试过的 URL：`https://reui.io/r/c-tree-{1..7}.json`（全部 200，已逐个查看标题与 import 语句，确认均未涉及拖拽/多选）。如果 reui 有专门的拖拽示例，本次没能定位到它的 slug。

4. **reui Tree 文档页的"演示变体"列表与 registry 标题对不上**：WebFetch 摘要页面正文只提到 4 种演示（Basic / With line / With Icon / With Plus-Minus Icons），但 registry 有 7 个 block（另外 3 个是"custom indent"×2、"organization chart with avatars"、"permissions with checkboxes"）。可能是页面正文只展示了部分，或页面结构导致 WebFetch 没抓全；两份清单都已如实列在报告里，未强行合并或猜测哪份更权威。

5. **Aceternity Stateful Button 文档页的 API 表格**：文档页本身**没有**逐字的 props 表格（WebFetch 返回的"API/Props"内容是基于页面散文描述 + 组件用法推断的转述，不是页面上真实存在的表格）——报告里 3.3 节的 API 表面**以源码为准**（已逐行读取 `stateful-button.tsx`），文档页转述仅供交叉参考，不作为独立证据源单列。

6. **A-Rehman01/react-slide-button 的完整源码**：`raw.githubusercontent.com/A-Rehman01/react-slide-button/main/README.md` 返回 404（尝试过 `main` 分支路径，未尝试其他分支名如 `master`）。改用 WebFetch 抓 GitHub 页面渲染结果做摘要，**未下载到任何一行源码**，4.2 节所有描述均为二手转述，标注了未核实的具体点（尤其是"松手未达阈值是否自动回弹"这一条，README 摘要没有明确说）。

7. **滑动确认在 Android/TalkBack 侧的等效处理**：WebSearch 结果里出现了 TalkBack 相关链接，但本次没有针对 Android 侧做专门调研（任务重点是 iOS/SwiftUI 与 React），未深入，如需要可另起一轮调研。

8. **HelKyle/rn-swipe-to-confirm、react-component/swipeout 等 WebSearch 命中的其他实现**：只出现在搜索结果列表里，**没有**做 WebFetch 或源码下载，未纳入正式对照——如需要更多样本可以继续抓取，本报告只覆盖了 4.5 节列出的三个。
