import OhMyDesignShaders

// `OhMyDesignShaders` 的 nonisolated 消费面（#284）。分流规则同 `EffectsNonisolatedUsage.swift` 文件头：
// 值类型 / 配置类型进本文件，View 与 modifier 进 `PublicVisibility.swift`。
// ⚠️ 只构造、不渲染：原生 `swift build` 下没有 metallib，见 `Package.swift` 的接线注释。
// ⚠️ 纯 case 枚举的隔离只落在协议一致性上：`allCases.count` 在枚举丢掉 `nonisolated` 后照样编译，
// 经 `Set(...)` 用到 `Hashable` 一致性才会报 `main actor-isolated conformance`。

nonisolated func readShadersModuleName() -> String {
    OhMyDesignShaders.moduleName
}

// MARK: - 背景的档位枚举 / Background tiers

nonisolated func readShaderBackgroundTiers() -> [Int] {
    [
        Set(ShaderMotion.allCases).count,
        Set(Plasma.Density.allCases).count,
        Set(FractalClouds.Density.allCases).count,
        Set(InkSmoke.Density.allCases).count,
        Set(LiquidChrome.Density.allCases).count,
        Set(DotGrid.Spacing.allCases).count,
        Set(Metaballs.Count.allCases).count,
        Set(DotOrbit.Density.allCases).count,
        Set(Voronoi.CellSize.allCases).count,
        Set(SmokeRing.Thickness.allCases).count,
        Set(Swirl.Bands.allCases).count,
        Set(SimplexNoise.Banding.allCases).count,
        Set(ColorPanels.Style.allCases).count,
        Set(StarNest.Depth.allCases).count,
    ]
}

// MARK: - 内容层效果的配置枚举 / Content-layer effect configuration

nonisolated func readShaderEffectTiers() -> [Int] {
    [
        Set(RefractiveGlassStrength.allCases).count,
        Set(GlassOrbSize.allCases).count,
        Set(GlassOrbMagnification.allCases).count,
        Set(HalftoneDot.allCases).count,
    ]
}

nonisolated func describeShaderLibraryError(_ error: OhMyDesignShaders.ShaderLibraryError) -> String {
    error.description
}
