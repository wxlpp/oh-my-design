import OhMyDesign
import SwiftUI

// MARK: - GalleryCraft

@MainActor
enum GalleryCraft {
    static let entries: [ComponentMeta] = [
        ComponentMeta(id: "craft-materials", name: "材质与强调", description: "相同内容，三种清晰的表面角色。", category: .container) {
            MaterialCraftDemo()
        },
        ComponentMeta(id: "craft-selection", name: "带说明的选择", description: "文字、符号与选中状态一起表达选择。", category: .form) {
            SelectionCraftDemo()
        },
        ComponentMeta(id: "craft-compositions", name: "内容卡片组合", description: "故事、人物与创作进度的示例排版。", category: .container) {
            CompositionCraftDemo()
        },
    ]
}

// MARK: - Shared presentation

struct CraftPage<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text(self.eyebrow).font(.caption.weight(.semibold)).tracking(2)
                    .foregroundStyle(Color.contentSecondary)
                Text(self.title).font(.largeTitle.bold()).foregroundStyle(Color.contentPrimary)
                Text(self.subtitle).font(.subheadline).foregroundStyle(Color.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            self.content
        }
        .padding(CoreSpacing.xl)
        .frame(maxWidth: 700, alignment: .leading)
        .coreAccent(.blue)
        .tint(.blue)
    }
}

struct CraftBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        RoundedRectangle(cornerRadius: CoreRadius.xLarge)
            .fill(Color.surfaceRaised)
            .overlay {
                if !self.reduceTransparency {
                    LinearGradient(
                        colors: [.blue.opacity(0.16), .purple.opacity(0.12), .teal.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(.rect(cornerRadius: CoreRadius.xLarge))
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Materials

struct MaterialCraftDemo: View {
    @State private var colorful = true
    @State private var saved = false

    var body: some View {
        CraftPage(eyebrow: "01 / MATERIAL", title: "轻，有分寸。", subtitle: "内容安静承载，操作浮于其上。") {
            Toggle("彩色背景", isOn: self.$colorful)
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                self.caption("内容表面", detail: "让信息成为主角")
                Card(elevation: .none) { self.sample }
                self.caption("浮动玻璃", detail: "承载短暂的操作")
                self.sample.padding(CoreSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .floatingGlass(in: RoundedRectangle(cornerRadius: CoreRadius.large))
                self.caption("强调操作", detail: "只把颜色留给重点")
                HStack {
                    VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                        Text("片刻灵感").font(.headline)
                        Text("随手记下，不必成章").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: CoreSpacing.md)
                    Button {
                        self.saved.toggle()
                    } label: {
                        Image(systemName: self.saved ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(self.saved ? "取消收藏示例" : "收藏示例")
                }
                .padding(CoreSpacing.lg)
            }
            .padding(CoreSpacing.lg)
            .background {
                if self.colorful { CraftBackdrop() }
                else { RoundedRectangle(cornerRadius: CoreRadius.xLarge).fill(Color.surfaceCanvas) }
            }
            Text("玻璃用于操作层；正文与长内容优先保持稳定底色。")
                .font(.footnote).foregroundStyle(Color.contentSecondary)
        }
    }

    private var sample: some View {
        HStack(alignment: .center, spacing: CoreSpacing.md) {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.contentPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text("片刻灵感").font(.headline)
                Text("随手记下，不必成章").font(.subheadline).foregroundStyle(Color.contentSecondary)
            }
        }
    }

    private func caption(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption.weight(.semibold))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(Color.contentSecondary)
        }
    }
}

// MARK: - Selection

struct SelectionCraftDemo: View {
    @State private var selection = "focus"
    @State private var enabled = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let options = [
        ("inspiration", "灵感", "sparkles", "捕捉念头，慢慢展开"),
        ("focus", "专注", "circle.lefthalf.filled", "留白更多，让思路安静"),
        ("night", "夜读", "moon", "放缓节奏，回看故事"),
    ]

    var body: some View {
        CraftPage(eyebrow: "02 / SELECTION", title: "选一种节奏。", subtitle: "图标提示方向，说明帮助决定。") {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                HStack {
                    Text("创作氛围").font(.headline)
                    Spacer()
                    Text(self.options.first(where: { $0.0 == self.selection })?.1 ?? "")
                        .font(.subheadline).foregroundStyle(Color.contentSecondary)
                        .accessibilityIdentifier("craft.selection.current")
                }
                LazyVGrid(columns: [GridItem(self.dynamicTypeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: 145), spacing: CoreSpacing.md)], spacing: CoreSpacing.md) {
                    ForEach(self.options, id: \.0) { option in
                        SelectionCard(value: option.0, selection: self.$selection) {
                            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                                Image(systemName: option.2).font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                                    Text(option.1).font(.headline)
                                    Text(option.3).font(.caption).foregroundStyle(Color.contentSecondary)
                                }
                            }
                        }
                        .disabled(!self.enabled)
                        .accessibilityIdentifier("craft.selection.\(option.0)")
                    }
                }
                Toggle("允许选择", isOn: self.$enabled)
                    .font(.subheadline)
            }
            .padding(CoreSpacing.lg)
            .background(CraftBackdrop())
            Text("示例选择仅作用于本页。选中标记与说明保持可见，禁用时保留当前值。")
                .font(.footnote).foregroundStyle(Color.contentSecondary)
        }
    }
}

// MARK: - Compositions

struct CompositionCraftDemo: View {
    var body: some View {
        CraftPage(eyebrow: "03 / COMPOSITION", title: "让内容有层次。", subtitle: "同一套基础组件，三种叙事重心。") {
            self.story
            self.person
            self.progress
            Text("以上均为展示排版的示例数据。")
                .font(.footnote).foregroundStyle(Color.contentSecondary)
        }
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                HStack {
                    Text("故事 · 示例").font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: "book.closed").accessibilityHidden(true)
                }
                Text("雨停之前").font(.system(.largeTitle, design: .serif).weight(.semibold))
                Text("一座小城，一封迟到的信。")
                    .font(.subheadline).foregroundStyle(Color.contentSecondary)
            }
            .padding(CoreSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CraftBackdrop())
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text("最近编辑").font(.caption).foregroundStyle(Color.contentSecondary)
                    Text("第三章 · 渡口").font(.headline)
                }
                Spacer()
                Text("2,460 字").font(.caption.monospacedDigit()).foregroundStyle(Color.contentSecondary)
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceRaised, in: .rect(cornerRadius: CoreRadius.xLarge))
        .clipShape(.rect(cornerRadius: CoreRadius.xLarge))
    }

    private var person: some View {
        Card(kind: .grouped, elevation: .none) {
            HStack(alignment: .top, spacing: CoreSpacing.lg) {
                Text("林").font(.system(.title, design: .serif))
                    .frame(width: 56, height: 64)
                    .background(Color.surfaceInteractive, in: .rect(cornerRadius: CoreRadius.medium))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("林予安").font(.headline)
                    Text("修表师 · 27 岁").font(.caption).foregroundStyle(Color.contentSecondary)
                    Text("擅长修复旧物，却总想避开自己的往事。")
                        .font(.subheadline).foregroundStyle(Color.contentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var progress: some View {
        Card(kind: .grouped, elevation: .none) {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("本周落笔").font(.headline)
                    Spacer()
                    Text("3 / 5 天").font(.caption.monospacedDigit()).foregroundStyle(Color.contentSecondary)
                }
                Text("8,420 字").font(.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit())
                ProgressBar(value: 0.6, label: "创作天数")
                Text("故事在一点一点向前。")
                    .font(.caption).foregroundStyle(Color.contentSecondary)
            }
        }
    }
}
