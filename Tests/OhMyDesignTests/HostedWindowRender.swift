import SwiftUI
#if canImport(UIKit)
import UIKit
typealias HostedPlatformView = UIView
#else
import AppKit
typealias HostedPlatformView = NSView
#endif

// MARK: - 托管窗口渲染 / Hosted window rendering

@MainActor
final class HostedWindow {
    let root: HostedPlatformView
    #if canImport(UIKit)
    private let window: UIWindow
    #else
    private let window: NSWindow
    #endif

    init(_ content: some View, size: CGSize, scheme: ColorScheme) {
        let rooted = content
            .frame(width: size.width, height: size.height)
            .background(Color.surfaceCanvas)
        #if canImport(UIKit)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let controller = UIHostingController(rootView: rooted)
        controller.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        self.root = controller.view
        #else
        let host = NSHostingView(rootView: rooted.environment(\.colorScheme, scheme))
        host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = host.appearance
        window.contentView = host
        window.orderFront(nil)
        self.window = window
        self.root = host
        #endif
        self.settle()
    }

    func settle() {
        for _ in 0..<8 {
            #if canImport(UIKit)
            self.root.layoutIfNeeded()
            #else
            self.root.layoutSubtreeIfNeeded()
            #endif
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
    }

    func close() {
        #if canImport(UIKit)
        self.window.isHidden = true
        #else
        self.window.orderOut(nil)
        #endif
    }

    #if canImport(AppKit) && !canImport(UIKit)
    func sendMouse(_ type: NSEvent.EventType, at point: CGPoint) {
        let location = CGPoint(x: point.x, y: self.root.bounds.height - point.y)
        guard let event = NSEvent.mouseEvent(
            with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: self.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ) else { return }
        self.window.sendEvent(event)
    }
    #endif

    func first<T: HostedPlatformView>(_ type: T.Type) -> T? {
        Self.first(type, in: self.root)
    }

    private static func first<T: HostedPlatformView>(_ type: T.Type, in view: HostedPlatformView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = Self.first(type, in: subview) { return match }
        }
        return nil
    }

    func frame(of view: HostedPlatformView) -> CGRect {
        #if canImport(UIKit)
        view.convert(view.bounds, to: self.root)
        #else
        let rect = view.convert(view.bounds, to: self.root)
        return self.root.isFlipped
            ? rect
            : CGRect(x: rect.minX, y: self.root.bounds.height - rect.maxY, width: rect.width, height: rect.height)
        #endif
    }

    func pixels(scale: CGFloat = 2) -> HostedPixels {
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(bounds: self.root.bounds, format: format).image {
            self.root.layer.render(in: $0.cgContext)
        }
        return HostedPixels(image.cgImage, scale: scale)
        #else
        let bounds = self.root.bounds
        guard let rep = self.root.bitmapImageRepForCachingDisplay(in: bounds) else {
            return HostedPixels(nil, scale: 1)
        }
        self.root.cacheDisplay(in: bounds, to: rep)
        return HostedPixels(rep.cgImage, scale: CGFloat(rep.pixelsWide) / max(bounds.width, 1))
        #endif
    }
}

// MARK: - 像素 / Pixels

nonisolated struct HostedPixels {
    let bytes: [UInt8]?
    let width: Int
    let height: Int
    let scale: CGFloat

    init(_ image: CGImage?, scale: CGFloat) {
        self.scale = scale
        guard let image else {
            self.bytes = nil
            self.width = 0
            self.height = 0
            return
        }
        self.width = image.width
        self.height = image.height
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        self.bytes = bytes
    }
}
