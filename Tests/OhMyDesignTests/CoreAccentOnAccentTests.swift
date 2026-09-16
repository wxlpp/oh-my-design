import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - #357 on-accent 派生（纯函数级）

/// 判据按计划设计要点：派生函数在 (accent, scheme) 组合下的输出——
/// 墨色 × light/dark、蓝 × light/dark、黄 × light/dark 共 6 组 + 显式 `on` 覆盖。
/// ⚠️ accent 全部用系统语义色 / 静态色构造：asset catalog 那 198 个常量在 macOS
/// native 腿 `resolve(in:)` 恒为全透明（CLAUDE.md《验证边界》），进不了 `resolve(in:)`
/// 断言——它们作底色只会在渲染层出现，本 suite 不渲染。
@Suite("coreAccent on-accent 派生")
@MainActor
struct CoreAccentOnAccentTests {
    private static func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return environment
    }

    /// 与 `Color.dataAccent` 同源构造（系统蓝），两条腿都能解析。
    private static var systemBlue: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemBlue)
        #else
            Color(nsColor: .systemBlue)
        #endif
    }

    /// 验算（计划设计要点）：墨色是黑 / 白极性 ⇒ 走 `contentOnAccent` 特判
    /// （与 #356 之前的静态 token 逐字节一致）；系统蓝 → 两档白（#357 的修复点：
    /// 此前深色档是近黑字压蓝底）——L 两腿都 < 0.5：iOS ≈0.41，macOS ≈0.45
    /// （实测 0.4536 / 0.4789，两档）；黄 L≈0.93 → 两档黑。
    @Test("六组 (accent × scheme) 派生与验算一致")
    func derivationMatchesReckoning() {
        #expect(Color.onAccent(for: .inkPrimary, in: Self.environment(.light)) == Color.contentOnAccent,
                "墨色 light 应走 contentOnAccent 特判")
        #expect(Color.onAccent(for: .inkPrimary, in: Self.environment(.dark)) == Color.contentOnAccent,
                "墨色 dark 应走 contentOnAccent 特判")
        #expect(Color.onAccent(for: Self.systemBlue, in: Self.environment(.light)) == .white,
                "系统蓝 light 应派生白")
        #expect(Color.onAccent(for: Self.systemBlue, in: Self.environment(.dark)) == .white,
                "系统蓝 dark 应派生白——深色模式近黑字压蓝底正是 #357 要修的")
        #expect(Color.onAccent(for: .yellow, in: Self.environment(.light)) == .black,
                "黄 light 应派生黑")
        #expect(Color.onAccent(for: .yellow, in: Self.environment(.dark)) == .black,
                "黄 dark 应派生黑")
    }

    @Test("primary 的显式 on 覆盖派生；缺省 on 走派生")
    func explicitOnOverridesDerivation() {
        let role = ButtonRoleStyleRole.primary
        for scheme in [ColorScheme.light, .dark] {
            #expect(
                role.resolvedOnColor(
                    accent: Self.systemBlue,
                    on: .indigo,
                    environment: Self.environment(scheme)
                ) == .indigo,
                "\(scheme)：显式 on 没覆盖派生"
            )
        }
        #expect(
            role.resolvedOnColor(
                accent: Self.systemBlue,
                on: nil,
                environment: Self.environment(.dark)
            ) == .white,
            "dark：primary 缺省 on 没按蓝底派生白字"
        )
    }

    @Test("非 primary 四个 role 不吃显式 on——它们留在自有镜像色阶上")
    func nonPrimaryRolesKeepContentOnAccent() {
        let environment = Self.environment(.dark)
        for role in [
            ButtonRoleStyleRole.secondary, .tertiary, .warning, .danger,
        ] {
            #expect(
                role.resolvedOnColor(accent: .yellow, on: .indigo, environment: environment)
                    == Color.contentOnAccent,
                "\(role) 吃了显式 on——它的底色是 ColorGrade 镜像色阶，应留在 contentOnAccent"
            )
        }
    }

    @Test("coreAccentOn 环境键默认 nil（= 缺省派生）")
    func environmentKeyDefaultsToNil() {
        #expect(
            EnvironmentValues().coreAccentOn == nil,
            "\\.coreAccentOn 默认不是 nil——缺省派生的语义会被改掉"
        )
    }

    /// 墨色 accent 下派生与 contentOnAccent（systemBackground）**逐字节同值**——
    /// 「墨色 accent 行为与现状一致」这条验收的机器证据。墨色走特判（返回静态
    /// `contentOnAccent` 本身），所以本断言两腿都成立——macOS 的 systemBackground
    /// 深色档是 #1E1E1E 而非纯黑，正因如此特判才必须返回 token 而不是派生 `.black`。
    @Test("墨色 accent 派生与 contentOnAccent 逐字节同值")
    func inkDerivationReproducesContentOnAccent() {
        for scheme in [ColorScheme.light, .dark] {
            let environment = Self.environment(scheme)
            let derived = Color.onAccent(for: .inkPrimary, in: environment)
                .resolve(in: environment)
            let statusQuo = Color.contentOnAccent.resolve(in: environment)
            #expect(
                derived == statusQuo,
                "\(scheme)：墨色 accent 派生 \(derived) 与 contentOnAccent \(statusQuo) 不同值——现状被改变了"
            )
        }
    }
}
