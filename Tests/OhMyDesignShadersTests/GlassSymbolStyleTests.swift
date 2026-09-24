import OhMyDesign
import SwiftUI
import Testing

@testable import OhMyDesignShaders

@MainActor
private final class StyleRecorder {
    var tints: [Color] = []
}

private struct RecordingGlassSymbolStyle: GlassSymbolStyle {
    let recorder: StyleRecorder

    func makeBody(configuration: Configuration) -> some View {
        self.recorder.tints.append(configuration.tint)
        return configuration.symbol
    }
}

@Suite("GlassSymbolStyle 扩展点")
@MainActor
struct GlassSymbolStyleTests {

    @Test("默认 style 是 PlainGlassSymbolStyle")
    func defaultStyleIsPlain() {
        #expect(EnvironmentValues().glassSymbolStyle is PlainGlassSymbolStyle)
    }

    @Test("注入的 style 真的经 makeBody 渲染，且拿到调用方的 tint")
    func injectedStyleRendersBody() {
        let recorder = StyleRecorder()
        let view = GlassSymbol("sparkles", tint: .dataAccent)
            .glassSymbolStyle(RecordingGlassSymbolStyle(recorder: recorder))
            .frame(width: 64, height: 64)
        let renderer = ImageRenderer(content: view)
        _ = renderer.cgImage
        #expect(!recorder.tints.isEmpty, "makeBody 一次都没被调用 —— GlassSymbol.body 没经 style 渲染")
        #expect(recorder.tints.allSatisfy { $0 == .dataAccent }, "实得 tint：\(recorder.tints)")
    }
}
