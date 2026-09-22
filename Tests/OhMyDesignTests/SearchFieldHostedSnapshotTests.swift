#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import OhMyDesign

// MARK: - 托管快照 / Hosted snapshot

@MainActor
private struct HostedSnapshot {
    let pixels: [UInt8]
    let width: Int
    let height: Int
    let scale: CGFloat
    let fieldFrame: CGRect?

    init(_ root: some View, scheme: ColorScheme) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 160))
        let controller = UIHostingController(
            rootView: root.padding(8).frame(width: 360).background(Color.surfaceCanvas)
        )
        controller.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = controller
        window.makeKeyAndVisible()
        for _ in 0..<8 {
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds, format: format).image {
            controller.view.layer.render(in: $0.cgContext)
        }
        let cgImage = image.cgImage
        self.width = cgImage?.width ?? 0
        self.height = cgImage?.height ?? 0
        self.scale = 2
        self.pixels = cgImage.flatMap { Self.bytes($0) } ?? []
        self.fieldFrame = Self.searchField(in: controller.view).map { $0.convert($0.bounds, to: controller.view) }
        window.isHidden = true
    }

    private static func bytes(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private static func searchField(in view: UIView) -> UISearchTextField? {
        if let field = view as? UISearchTextField { return field }
        for subview in view.subviews {
            if let field = Self.searchField(in: subview) { return field }
        }
        return nil
    }

    func dangerPoints(scheme: ColorScheme) -> [CGPoint] {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let target = Color.statusDangerForeground.resolve(in: environment)
        let tr = Int(target.red * 255), tg = Int(target.green * 255), tb = Int(target.blue * 255)
        var points: [CGPoint] = []
        for index in stride(from: 0, to: self.pixels.count, by: 4) where self.pixels[index + 3] > 200 {
            let delta = abs(Int(self.pixels[index]) - tr) + abs(Int(self.pixels[index + 1]) - tg)
                + abs(Int(self.pixels[index + 2]) - tb)
            if delta < 30 {
                let pixel = index / 4
                points.append(CGPoint(x: CGFloat(pixel % self.width) / self.scale, y: CGFloat(pixel / self.width) / self.scale))
            }
        }
        return points
    }
}

@Suite("SearchField 托管快照：原生搜索框真实渲染下的 valid 不变与 invalid 描边位置")
@MainActor
struct SearchFieldHostedSnapshotTests {
    @Test("valid 与改动前实现（92d224b 原样拷贝）在光栅化噪声内一致（light / dark）")
    func validMatchesLegacy() {
        for scheme in [ColorScheme.light, .dark] {
            let now = HostedSnapshot(SearchField(text: .constant("release")), scheme: scheme)
            let old = HostedSnapshot(LegacySearchField(text: .constant("release")), scheme: scheme)
            #expect(now.fieldFrame != nil && now.fieldFrame == old.fieldFrame, "\(scheme)：原生框位置变了")
            expectBitmapsEquivalent(now.pixels, old.pixels, maxChannelDelta: 1, "\(scheme)")
        }
    }

    @Test(
        "invalid 描边贴合原生搜索框 bounds 的四条边；valid 与 disabled + invalid 没有描边（light / dark）",
        .enabled(
            if: assetCatalogIsCompiled,
            "跳过：bundle 里没有 Assets.car，statusDangerForeground 解析为全透明；本条在 iOS Simulator 腿上跑。"
        )
    )
    func invalidStrokeHugsNativeBounds() throws {
        for scheme in [ColorScheme.light, .dark] {
            let field = SearchField(text: .constant("release"))
            #expect(HostedSnapshot(field, scheme: scheme).dangerPoints(scheme: scheme).isEmpty, "\(scheme)：valid 出现 danger 色")
            #expect(
                HostedSnapshot(field.fieldValidation(.invalid("x")).disabled(true), scheme: scheme)
                    .dangerPoints(scheme: scheme).isEmpty,
                "\(scheme)：disabled 压不过 invalid"
            )

            let broken = HostedSnapshot(field.fieldValidation(.invalid("x")), scheme: scheme)
            let frame = try #require(broken.fieldFrame)
            let points = broken.dangerPoints(scheme: scheme)
            #expect(points.count > 200, "\(scheme)：invalid 没画出描边（\(points.count) 个 danger 像素）")
            let outside = points.filter { !frame.insetBy(dx: -0.5, dy: -0.5).contains($0) }
            #expect(outside.isEmpty, "\(scheme)：\(outside.count) 个描边像素落在原生框 \(frame) 之外")
            let edge: CGFloat = CoreBorderWidth.thin + 1
            #expect(points.contains { $0.y - frame.minY < edge }, "\(scheme)：上缘没有描边")
            #expect(points.contains { frame.maxY - $0.y < edge }, "\(scheme)：下缘没有描边")
            #expect(points.contains { $0.x - frame.minX < edge }, "\(scheme)：左缘没有描边")
            #expect(points.contains { frame.maxX - $0.x < edge }, "\(scheme)：右缘没有描边")
            #expect(points.allSatisfy { point in
                point.y - frame.minY < edge || frame.maxY - point.y < edge
                    || point.x - frame.minX < frame.height / 2 + edge || frame.maxX - point.x < frame.height / 2 + edge
            }, "\(scheme)：描边像素出现在原生框内部而不是外沿")
        }
    }
}

// MARK: - 旧实现原样拷贝（92d224b）/ Legacy copy

private struct LegacySearchField: View {
    init(text: Binding<String>, placeholder: String = "Search", onSubmit: ((String) -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        LegacyNativeSearchField(
            text: self.$text,
            placeholder: self.placeholder,
            onSubmit: self.onSubmit,
            focusRequests: self.focusRequests
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .onTapGesture { self.focusRequests += 1 }
    }

    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: ((String) -> Void)?
    @State private var focusRequests: Int = 0
}

private struct LegacyNativeSearchField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: ((String) -> Void)?
    let focusRequests: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = self.placeholder
        field.accessibilityLabel = self.placeholder.isEmpty
            ? String(localized: "Search", bundle: .module)
            : nil
        if field.text != self.text {
            field.text = self.text
        }
        if context.coordinator.lastFocusRequest != self.focusRequests {
            context.coordinator.lastFocusRequest = self.focusRequests
            if self.focusRequests > 0, !field.isFirstResponder {
                field.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LegacyNativeSearchField
        var lastFocusRequest: Int = 0

        init(_ parent: LegacyNativeSearchField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            self.parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            self.parent.onSubmit?(field.text ?? "")
            return true
        }
    }
}
#endif
