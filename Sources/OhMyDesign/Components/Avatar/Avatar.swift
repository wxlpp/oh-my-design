import SwiftUI

// MARK: - AvatarSize

/// `Avatar` 的尺寸：跟随环境 `controlSize`，或指定固定直径。
public nonisolated enum AvatarSize: Sendable, Equatable {
    /// 按环境 `\.controlSize` 取 `CoreControlMetrics.avatarDiameter(for:)`。
    case automatic
    /// 固定直径（pt）。负值与非有限值（`.infinity` / `.nan`）按 0 处理。
    case fixed(CGFloat)

    func diameter(for controlSize: ControlSize) -> CGFloat {
        switch self {
        case .automatic: CoreControlMetrics.avatarDiameter(for: controlSize)
        case .fixed(let diameter): diameter.isFinite ? Swift.max(0, diameter) : 0
        }
    }
}

// MARK: - Avatar

/// **材质层**: 内容. **表面角色**: 内容.
public struct Avatar: View {
    /// 创建首字母占位头像。
    ///
    /// - Parameters:
    ///   - name: 用户名，取首字符与背景色哈希。
    ///   - size: 尺寸，默认 `.automatic`（跟随环境 `controlSize`）；`.fixed(_:)` 指定任意直径。
    public init(name: String, size: AvatarSize = .automatic) {
        self.name = name
        self.size = size
    }

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        let diameter = self.size.diameter(for: self.controlSize)
        let canvas = CGSize(width: diameter, height: diameter)
        let firstCharacter = String(self.name.prefix(1).uppercased())
        let fontSize = CoreControlMetrics.avatarInitialFontSize(forDiameter: diameter)

        Image(size: canvas, label: Text(self.name)) { context in
            context.fill(
                Path(CGRect(origin: .zero, size: canvas)),
                with: .color(Color(text: self.name))
            )
            context.draw(
                Text(firstCharacter)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            )
        }
        .frame(width: diameter, height: diameter)
    }

    let name: String
    let size: AvatarSize
}

#Preview {
    VStack(spacing: CoreSpacing.md) {
        HStack(spacing: CoreSpacing.md) {
            Avatar(name: "A").controlSize(.mini)
            Avatar(name: "B").controlSize(.small)
            Avatar(name: "C")
            Avatar(name: "D").controlSize(.large)
            Avatar(name: "E").controlSize(.extraLarge)
        }
        Avatar(name: "A", size: .fixed(100)).clipShape(Circle())
    }
    .padding()
}
