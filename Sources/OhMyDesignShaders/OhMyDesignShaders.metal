//
//  OhMyDesignShaders.metal
//  OhMyDesignShaders
//
//  全部 `[[stitchable]]` 入口 + 共用的噪声原语。
//
//  ⚠️ **为什么所有 shader 在同一个文件里**：Metal 的 helper 函数跨 `.metal` 文件复用
//  需要头文件声明，而 SwiftPM 的资源处理对 `.h` 的支持不明确。噪声原语确实是多个
//  shader 共用的，放同一编译单元既避开该不确定性、又不需要重复实现。
//  各入口之间用 `// MARK: -` 分节，与本仓 Swift 侧的分节惯例一致。
//
//  ⚠️ **本文件零硬编码色**（FR-8）。所有颜色由 Swift 侧经 `.color(...)` 传入——
//  这既是色彩纪律，也是「自研实现」差异化的一条（见 `docs/shader-provenance.md`）。
//
//  ⚠️ **不要为了"更像某个参考效果"去增补参数**——那会把形参面推向上游的 uniform 列表，
//  正是 provenance 表用来指认来源的那条链。
//

#include <metal_stdlib>
// ⚠️ **`layerEffect` 用到的 `SwiftUI::Layer` 需要这个 include**，否则
// `error: use of undeclared identifier 'SwiftUI'`。只写 `<metal_stdlib>` 不够。
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - 共用原语 / Shared primitives

namespace cd {

// ⚠️ **本节的原语是重写过的，不是第一版**（#261 终审 C-1）。
//
// 第一版用的是 `fract(p * float2(123.34, 456.21)); p += dot(p, p + 45.32)` 那组常量
// ——它与 ShipSwift 的 `swInkSmokeHash21` / `swLiquidChromeHash` / `swHt_hash21`
// **逐字节相同**，而那组常量出自 The Art of Code 的 Shadertoy 教程（Shadertoy 默认许可
// CC BY-NC-SA）。
//
// ⇒ 本 PR 曾声称的「下一个 reviewer 用形参比对反查会落空」**是假的**：只要多做一步
// `grep 123.34` 就命中。**形参不匹配不证明函数体独立**——函数体才是受保护的表达。
//
// ⚠️⚠️ **第二版（改用位运算整数 hash）重蹈了同一失败模式，只是换了被复制的对象**
//（PR #261 第 2 轮终审 C-1）。第二版的注释写「Wang hash 家族的**公开构造**」——
// 那正是 #249 裁定明令不接受的「provenance 未知」型**否定断言**，裁定要求正向拿到
// 三种判决之一。按本文件自己上面那条判据复核第二版：
//   · `grep 0x27d4eb2d`  → 命中 **Thomas Wang** 整数 hash，经 **Nathan Reed**
//     《Quick And Easy GPU Random Numbers In D3D11》(2013) 传播的 GPU 版本，逐字符一致；
//   · `grep 73856093`    → 命中 **Teschner et al. 2003**《Optimized Spatial Hashing for
//     Collision Detection of Deformable Objects》的素数三元组
//     `73856093 / 19349663 / 83492791`。
//
// ⇒ **本版不再声称原创，改为正向署名**。这两项都是**公开发表的算法与常数**
//（Wang 的页面无许可声明；Teschner 是论文里的数字），法律风险低于 Shadertoy 的
// CC BY-NC-SA——但**低风险 ≠ 已裁定**，本仓的门是正向裁定，故逐项写明出处。
// 逐项条目已落地在 `docs/shader-provenance.md`（task #249）的《共享原语的逐项出处》与
// 《清偿条款》两节 —— 本文件涉及的两项在那里各有一行（`wangHash` / Teschner 素数三元组）。
// ⚠️ **承接 issue 编号已填实：#281**（原为 `TBD`；该文档的规则是「`TBD` 视为未清偿，
// 合入 `main` 前必须填实」）。
//
// ⚠️⚠️ **#281 做完许可实查后，上面这段的两处「无许可 / 风险低」需要更正**：
//   · **Teschner 的三个素数是事实性常数**（已读 VMV 2003 原文 §4.1），义务是学术引用，
//     不是许可义务 —— 这一半原文说对了；
//   · ⚠️ **Wang 那一半说错了**。「Wang 的页面无许可声明」属实，但**本文件复制的不是
//     Wang 的写法**：Wang 与 Bob Jenkins 写的都是 `a = a + (a << 3)`，
//     而 **Nathan Reed 把它改写成 `seed *= 9`——本文件写的正是后者**。
//     Reed 的站点页脚逐字：「© 2007–2025 by Nathan Reed. Licensed **CC-BY-4.0**」。
//     ⇒ **署名 Reed 是许可条件，不是礼节**；另据 Jenkins「So are the ones on
//     Thomas Wang's page」，算法层本身是公有领域。
//     ⇒ 本项**已离开 `待追溯`，改判 `已追到兼容许可`**。
// ⚠️ 此处刻意只写小节名、不写行号 —— 该文档仍在改，行号引用必然失真（前几轮已因此返工两次）。

/// 32-bit 整数雪崩混合。
///
/// ⚠️ **出处：Thomas Wang 的整数 hash，GPU 版本经 Nathan Reed (2013) 传播。**
/// 逐字符一致，**不是本仓原创**。常数 `0x27d4eb2d` 是它的指纹。
///
/// ⚠️⚠️ **许可（#281 一手实查）**：下面第二行写的是 `seed *= 9u`，而
/// **Wang 与 Bob Jenkins 的原式是 `a = a + (a << 3)`——`*= 9` 是 Reed 的改写**。
/// ⇒ 本函数复制的是 **Reed 那一份**，而 `reedbeta.com` 页脚逐字
/// 「© 2007–2025 by Nathan Reed. Licensed **CC-BY-4.0**」⇒ **署名是许可条件**。
/// 算法层本身据 Jenkins 为**公有领域**（「So are the ones on Thomas Wang's page」）。
/// ⇒ 义务落在 `ACKNOWLEDGEMENTS.md`：署名 Reed + 链接 CC-BY-4.0 + 注明算法出自 Wang。
inline uint wangHash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16);
    seed *= 9u;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15);
    return seed;
}

/// 二维格点 → [0, 1)。两个整数坐标先线性组合成一个 seed，再走整数雪崩。
///
/// ⚠️ **出处：素数三元组 `73856093 / 19349663 / 83492791` 出自 Teschner et al. 2003**
///《Optimized Spatial Hashing for Collision Detection of Deformable Objects》，
/// 是图形代码里最好 grep 的常量之一，**不是本仓原创**。
///
/// ⚠️ **先转 `uint` 再乘不是风格问题**（终审 I-2）：`int × int` 在格点索引到
/// 数十量级时就溢出——`82 × 83492791 ≈ 6.8e9 > INT_MAX`。
/// ⚠️ 提这条时举的实例是 `Starfield.Density.dense`（cells 38，乘竖屏 aspect ≈ 2.16
/// ⇒ 索引 82），**该件已随 #281 撤回**；但结论不随实例走——`fbm` → `valueNoise`
/// → 本函数这条链上的坐标由调用方的 `scale` 决定，同样够得到这个量级。
/// MSL 继承 C++ 语义，有符号溢出是 **UB**——
/// 今天在 Apple GPU 上回绕、看着照样随机，但编译器有权按「不会溢出」优化。
/// 无符号回绕是良定义的。
///
/// ⚠️ **偏移必须取整数**（终审 S-2）：本函数内部先 `floor(p)`，
/// 故 `hash21(cell + 7.13)` 与 `hash21(cell + 7.0)` **完全等价**，小数部分是死值。
inline float hash21(float2 p) {
    uint2 i = uint2(int2(floor(p)));
    uint seed = (i.x * 73856093u) ^ (i.y * 19349663u);
    return float(wangHash(seed) & 0x00FFFFFFu) / float(0x01000000u);
}

/// 二维 hash → float2。第二个分量用不同的 seed 扰动，避免两轴相关。
inline float2 hash22(float2 p) {
    uint2 i = uint2(int2(floor(p)));
    uint sx = (i.x * 73856093u) ^ (i.y * 19349663u);
    // ⚠️ `50331653` 不属 Teschner 三元组，是标准哈希表素数表里的条目（第 3 轮终审 S）。
    uint sy = (i.x * 83492791u) ^ (i.y * 50331653u);
    return float2(float(wangHash(sx) & 0x00FFFFFFu),
                  float(wangHash(sy) & 0x00FFFFFFu)) / float(0x01000000u);
}

/// 值噪声：四角 hash 双线性插值。
///
/// ⚠️ 双线性插值 + `smoothstep` 权重是值噪声的**定义**（教科书）。
/// ⚠️ **初版这里写「不存在『另一种写法』」——那是一句可证伪的否定式 provenance 断言**
///（第 3 轮终审 I-2），正是本文件自己判定不接受的那一类。至少有两种在野的标准形态：
/// 嵌套 `mix(mix(a,b,u.x), mix(c,d,u.x), u.y)`（**本文件采用**，与 iq 的写法一致）
/// 与 The Book of Shaders 的展开式 `mix(a,b,u.x) + (c-a)*u.y*(1-u.x) + (d-b)*u.x*u.y`。
/// 两者等价，本文件选了前者；
/// 可替换的是**底下的 hash**，那一层已按上面的说明重写。
inline float valueNoise(float2 p) {
    float2 cell = floor(p);
    float2 frac = fract(p);
    float2 weight = frac * frac * (3.0 - 2.0 * frac);

    float c00 = hash21(cell);
    float c10 = hash21(cell + float2(1.0, 0.0));
    float c01 = hash21(cell + float2(0.0, 1.0));
    float c11 = hash21(cell + float2(1.0, 1.0));

    return mix(mix(c00, c10, weight.x), mix(c01, c11, weight.x), weight.y);
}

/// FBM：频率翻倍、幅度减半，归一化到 [0, 1]。
///
/// ⚠️ **出处（第 3 轮终审 I-1；⚠️ 第 4 轮终审 C-1 发现上一轮"已处置"实际没落地——
/// 我的替换锚点没匹配，而 commit message 却写了已加，本次补上并核对过 diff）**：
/// ⚠️⚠️ **口径已按 `docs/shader-provenance.md` 的硬前置改（#281 补做——该前置写在
/// #261 的合入清单里却没落地）**：出处指**算法谱系**，**不再引 The Book of Shaders**。
/// 理由是那本书的 LICENSE 实查为 `All rights reserved`（「You cannot use this Work in
/// any commercial or non-commercial product」），**比 Shadertoy 的默认许可还严**
/// ⇒ 把一个事实性算法绑到那个来源上，是一份没有辩护的书面自认。
/// 且实查对照后「逐行同构」这个说法**本身就过强**：本实现多了 `total` 累加与
/// `sum / total` 归一化，`octaves` 也是函数参数而非 `#define OCTAVES`。
/// `amplitude = 0.5` / `sum += noise(p) * amplitude` / `p *= 2.0` / `amplitude *= 0.5`
/// **就是 fBm 的定义**（gain 0.5、lacunarity 2.0），属 Mandelbrot–Perlin–Musgrave
/// 谱系的**事实性算法**（见 Ebert et al.《Texturing & Modeling》），不是某一份
/// 教学资源的表达 ⇒ **署名对象是算法本身**。
/// ⚠️ 本文件里其余原语都交代了出处，唯独 fbm 曾一个字没有——而三个 shader 的
/// 自述第一句都是「FBM + 域扭曲」。
inline float fbm(float2 p, int octaves) {
    float sum = 0.0;
    float amplitude = 0.5;
    float total = 0.0;
    for (int i = 0; i < octaves; ++i) {
        sum += valueNoise(p) * amplitude;
        total += amplitude;
        p *= 2.0;
        amplitude *= 0.5;
    }
    return sum / max(total, 1e-4);
}

/// 三档调色斜坡：`v ∈ [0,1]` → low → mid → high，接缝用 smoothstep 抹平。
///
/// ⚠️ **出处：未指认到具体上游**（第 5 轮终审 I-3）。按 #249 的判据，
/// 「指认不到」**不能写成空白**——空白等于默认原创，而本 PR 已因这个默认吃了四次亏。
///
/// ⚠️ **#281 又追了一轮，仍未指认到**（四种 code-search 措辞 + 两次 web search +
/// 查了 LYGIA 的 color-ramp 条目，无任何具名作者 / 出版物 / 库发表过这三行结构）。
/// ⇒ 裁定仍是 **`待追溯`**，分档 **低指纹**（3 行；两段 smoothstep 的分界点由「三档」
/// 这个需求唯一确定 ⇒ 功能性），承接 issue **#281**。
/// ⚠️ **「又追了一轮没找到」不等于「原创」**——不作任何原创声称。
inline half4 ramp3(float v, half4 low, half4 mid, half4 high) {
    half4 lower = mix(low, mid, half(smoothstep(0.0, 0.5, v)));
    half4 upper = mix(mid, high, half(smoothstep(0.5, 1.0, v)));
    return mix(lower, upper, half(step(0.5, v)));
}

/// 抗锯齿边宽。⚠️ **必须经此取，不要直接用 `fwidth`**：平坦区域 `fwidth` 可为 0，
/// 会让 `smoothstep(x - 0, x + 0, …)` 变成 0/0 → NaN（**第 1 轮**终审 I-5）。
///
/// ⚠️⚠️ **归属更正（#281）**：上一版写「iq 的 **distance-AA** 一族」——**该归属不成立**。
/// #281 逐页 grep 了 iq 的 `distfunctions2d/` `distfunctions/` `functions/` `distance/`
/// `filterableprocedurals/` 五篇，**`fwidth` 一次都没有出现**；那是凭印象归的属。
/// 最接近的**具名**发表是 Stefan Gustavson《2D Shape Rendering by Distance Fields》
/// (OpenGL Insights ch.12, 2011)，其代码自述 "This code is in the public domain."，
/// **但他写的是 `0.7 * length(vec2(dFdx, dFdy))`，不是同一表达**。
/// ⇒ 正确的说法是：**无可归属上游的通用惯用法**（1 行；`fwidth` 是内建函数，
/// 把它夹到 0 以上无表达余地）。裁定 `待追溯`、分档**低指纹**，承接 issue **#281**。
/// ⚠️ 交叉引用从本行起一律带**轮次**——同一 PR 内已经出现两个不同轮次的 I-5。
inline float edgeWidth(float x) {
    return max(fwidth(x), 1e-4);
}

/// 内容层里**最后一个有效像素的中心**坐标。
///
/// ⚠️ **不是 `size`**：`size` 是层的尺寸，坐标恰为 `size` 已经在最后一个像素**之外**
/// —— `layer.sample` 在那里可能返回透明，而调用方夹坐标的动机恰恰是躲开透明。
/// ⚠️ `max(..., 0)` 兜住退化尺寸（`size` 为 0 时上下界都是 0，`clamp` 仍良定义）。
inline float2 lastPixel(float2 size) {
    return max(size - 0.5, float2(0.0));
}

} // namespace cd

// MARK: - Plasma

/// 四相正弦叠加。
///
/// ⚠️ **出处（第 4 轮终审 C-1）**：`sin(x)` / `sin(y)` / `sin((x+y)/2)` / `sin(dist)`
/// 四项与 **Lode Vandevenne《Lode's Computer Graphics Tutorial — Plasma》**里被无数
/// demoscene / Shadertoy 版本转抄的公式
/// `sin(dist(x,y,cx,cy)/8) + sin(x/16) + sin(y/8) + sin((x+y)/16)` **逐项对应**，
/// 差别只是把除数参数化成 `frequency`、每项加了不同时间相位。
/// ⚠️ 上一版这里写「**经典配方**」——那是**没有出处的肯定式借用声明**，正是 #249
/// 裁定要求转成正向判决的那一类。而 Vandevenne 当时只写进了 `Plasma.swift`，
/// **函数体所在的文件仍是无出处的**，与本文件确立的「函数体才是受保护的表达」相悖。
///
/// ⚠️⚠️ **许可（#281 一手实查）**：plasma 页页脚是 `All rights reserved`，**但那只管散文**。
/// `https://lodev.org/cgtutor/legal.html` 逐字：「**The source code of QuickCG and all the
/// source code of the examples given in this tutorial and all its articles is released
/// under the following license:** … Redistributions of source code must retain the above
/// copyright notice, this list of conditions and the following disclaimer.」
/// ⇒ **BSD-2-Clause**，与本仓 MIT 分发兼容。
/// ⚠️ **义务：`ACKNOWLEDGEMENTS.md` 须保留版权通知 + 两条条件 + 免责声明全文**，
/// 一句「参考自 Lode 的教程」**不满足**第 1 条。
/// ⚠️ 同时记下有利的一半：他那组具体取值（中心 `(128,128)`/`(64,64)`/`(192,64)`/`(192,100)`、
/// 除数 `/8 /8 /7 /8`）**本函数一个都没用**——四项全部参数化、各带不同时间相位
/// ⇒ 取的是思路层。**通知照给**，成本为零。
[[stitchable]] half4 ohMyDesignPlasma(float2 position, half4 currentColor,
                                      float2 size, float time,
                                      float frequency, float octaves,
                                      half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float value = 0.0, amplitude = 1.0, total = 0.0, f = frequency;

    for (int i = 0; i < int(octaves); ++i) {
        float2 p = uv * f;
        float axial = sin(p.x + time) + sin(p.y + time * 1.13);
        float diagonal = sin((p.x + p.y) * 0.5 + time * 0.87);
        float radial = sin(length(p - f * 0.5) + time * 1.31);
        value += (axial + diagonal + radial) * 0.25 * amplitude;
        total += amplitude;
        amplitude *= 0.5;
        f *= 2.0;
    }
    return cd::ramp3(saturate(value / max(total, 1e-4) * 0.5 + 0.5), low, mid, high);
}

// MARK: - DotGrid

/// 规则点阵。`spacing` 决定格数，`radius` 决定点的相对半径，
/// `pulse` 让点按到中心的距离做呼吸（0 = 完全静态）。
[[stitchable]] half4 ohMyDesignDotGrid(float2 position, half4 currentColor,
                                       float2 size, float time,
                                       float spacing, float radius, float pulse,
                                       half4 background, half4 dotColor) {
    float2 s = max(size, float2(1.0));
    float2 uv = position / s;
    float aspect = s.x / s.y;
    float2 grid = float2(spacing * aspect, spacing);

    float2 cell = floor(uv * grid);
    float2 local = fract(uv * grid) - 0.5;

    // 呼吸：以画面中心为源的同心波，相位随格子到中心的距离推进。
    float2 centred = (cell + 0.5) / grid - 0.5;
    float wave = sin(length(centred) * 12.0 - time * 2.0) * 0.5 + 0.5;
    float r = radius * (1.0 - pulse + pulse * wave);

    // 抗锯齿边：用屏幕空间导数推边宽，避免固定值在不同分辨率下粗细不一。
    float d = length(local);
    float edge = cd::edgeWidth(d) * 1.5;
    float mask = 1.0 - smoothstep(r - edge, r + edge, d);

    return mix(background, dotColor, half(saturate(mask)));
}

// MARK: - FractalClouds

/// FBM 云层。两次域扭曲：先用一层 FBM 扰动采样坐标，再对扰动后的坐标取 FBM。
[[stitchable]] half4 ohMyDesignFractalClouds(float2 position, half4 currentColor,
                                             float2 size, float time,
                                             float scale, float octaves, float warp,
                                             half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;
    p.x += time * 0.35;

    // ⚠️ 偏移常量是本仓自定的（3.11 / 6.47），**不是** iq domain-warping 文章那组
    // `(1.7, 9.2) / (8.3, 2.8)`——第一版沿用了那组，见本文件头的说明。
    float2 offset = float2(cd::fbm(p + 3.11, int(octaves)),
                           cd::fbm(p + 6.47, int(octaves)));
    float v = cd::fbm(p + warp * (offset - 0.5), int(octaves));

    return cd::ramp3(saturate(v), low, mid, high);
}

// MARK: - InkSmoke

/// 墨烟：比 `FractalClouds` 更强的域扭曲 + 更陡的对比，形成丝缕感而非团块感。
[[stitchable]] half4 ohMyDesignInkSmoke(float2 position, half4 currentColor,
                                        float2 size, float time,
                                        float scale, float octaves, float wisp,
                                        half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;
    p.y -= time * 0.5;   // 烟向上飘

    // 两级域扭曲：第二级用第一级的结果再扰动一次，丝缕由此而来。
    //
    // ⚠️⚠️ **本段的结构派生自 Inigo Quilez《Domain Warping》一文的公开片段**
    //（终审 C-2）。原文：`vec2 q = vec2(fbm(p+(0,0)), fbm(p+(5.2,1.3)));`
    // `vec2 r = vec2(fbm(p+4*q+(1.7,9.2)), fbm(p+4*q+(8.3,2.8))); return fbm(p+4*r);`
    // 与下面三行**一一对应**：同样的三级级联、同样的 `p + k*q + offset` 形状，
    // **连变量名 `q` / `r` 都保留**。差别只是把 `4.0` 参数化成 `wisp`、把 vec2 偏移
    // 换成标量。
    // ⇒ 初版注释「偏移常量本仓自定，不沿用 iq 那组」**说的是实话，但不构成独立**
    //   ——本文件上面已写死「改常量不构成独立」。本版不再声称原创。
    //
    // ⚠️⚠️ **许可（#281 一手实查）**：`iquilezles.org/articles/warp/` 页面本身无许可声明，
    // **但它的父页 `https://iquilezles.org/articles/` 有站点级授权**，逐字：
    // 「**all technical code snippets you'll find are under the MIT license** so you can
    // easily reuse them, but the mathematical/shader art is protected and requires a
    // license for use.」⇒ 本段 **`已追到兼容许可 · MIT`**。
    // ⇒ **本段曾被判「待追溯（强指纹 · 阻断）」，该阻断已解除**——强档的义务是
    // 「追完前不得合入 `main`」，现在既追到、许可又兼容 ⇒ **义务已兑现，不是被绕过**。
    // ⚠️ **指纹强不等于不能用，等于必须署名**：`ACKNOWLEDGEMENTS.md` 须转载 MIT 通知并具名 iq。
    // ⚠️ iq 自述那几个偏移「don't have any special meaning」——**恰恰因此它们是表达而非事实**。
    // ⚠️ 同一问题的弱化版在 `ohMyDesignFractalClouds` 与 `ohMyDesignLiquidChrome`（均单级 warp，指纹较弱）。
    float2 q = float2(cd::fbm(p, int(octaves)), cd::fbm(p + 2.73, int(octaves)));
    float2 r = float2(cd::fbm(p + wisp * q + 4.19, int(octaves)),
                      cd::fbm(p + wisp * q + 7.61, int(octaves)));
    float v = cd::fbm(p + wisp * r, int(octaves));

    // 陡对比：把中段拉开，两端压平，读起来像烟而不像云。
    v = smoothstep(0.28, 0.72, v);
    return cd::ramp3(saturate(v), low, mid, high);
}

// MARK: - LiquidChrome

/// 液态铬：域扭曲后的坐标喂给正弦带，带边用 `fwidth` 抗锯齿，
/// 形成金属反射那种"窄而亮的高光带 + 宽而暗的过渡"。
[[stitchable]] half4 ohMyDesignLiquidChrome(float2 position, half4 currentColor,
                                            float2 size, float time,
                                            float scale, float bands, float flow,
                                            half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;

    float2 warp = float2(cd::fbm(p + time * 0.15, 3),
                         cd::fbm(p + 5.83 - time * 0.11, 3)) - 0.5;
    float2 q = p + flow * warp;

    // 正弦带 → [0,1]，再用导数做边缘抗锯齿，避免高频带出现摩尔纹。
    float raw = sin((q.x + q.y) * bands) * 0.5 + 0.5;
    float aa = cd::edgeWidth(raw);
    float v = smoothstep(0.5 - aa, 0.5 + aa, raw);

    // 金属感：把带边处的亮度再抬一档，模拟高光收窄。
    float sheen = pow(saturate(1.0 - abs(raw - 0.5) * 2.0), 3.0);
    return cd::ramp3(saturate(v * 0.75 + sheen * 0.25), low, mid, high);
}

// MARK: - paper-design/shaders 移植件的共用原语

namespace cd {

// 以视图中心为原点、按短边归一化到 [-0.5, 0.5] 的坐标。
// paper 的 `v_objectUV` / `v_patternUV` 由其顶点着色器按 fit / scale / rotation 算出；
// `colorEffect` 没有这一层，统一换成本函数（逐件列为修改）。
inline float2 centeredUV(float2 position, float2 size) {
    float2 s = max(size, float2(1.0));
    return (position - 0.5 * s) / min(s.x, s.y);
}

inline float2 rotate(float2 uv, float angle) {
    return float2x2(float2(cos(angle), sin(angle)), float2(-sin(angle), cos(angle))) * uv;
}

// paper 两色阶梯渐变（`colorsCount == 2` 时的展开）：`shape` ∈ [0, 1]，`steps` 为每段台阶数；与上游一样先预乘再混合。
inline half4 steppedGradient2(float shape, half4 firstColor, half4 secondColor, float steps) {
    half4 first = half4(firstColor.rgb * firstColor.a, firstColor.a);
    half4 second = half4(secondColor.rgb * secondColor.a, secondColor.a);
    float mixer = (shape - 0.25) * 2.0;
    float s = max(1.0, steps);
    if (mixer < 0.0 || mixer > 1.0) {
        float localT = mixer < 0.0 ? mixer + 1.0 : mixer - 1.0;
        localT = round(localT * s) / s;
        return mix(second, first, half(localT));
    }
    float localT = round(saturate(mixer) * s) / s;
    return mix(first, second, half(localT));
}

// 预乘颜色在底色上做「over」合成。
inline half4 overBackground(float3 color, float opacity, half4 back) {
    float3 bg = float3(back.rgb) * float(back.a);
    float3 rgb = color + bg * (1.0 - opacity);
    float a = opacity + float(back.a) * (1.0 - opacity);
    return half4(half3(rgb), half(a));
}

} // namespace cd

// MARK: - Metaballs

/// paper `packages/shaders/src/shaders/metaballs.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：`textureRandomizerR` 的 1D 噪声改用 `cd::hash21`；`fwidth` 经 `cd::edgeWidth` 加下限；
/// 颜色数组收成两色交替 + 底色；丢弃 `colorBandingFix`；UV 改为 `cd::centeredUV`；时间按本仓 `ShaderMotion` 换算。
namespace cd {
inline float metaballsNoise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash21(float2(i, 0.0)), hash21(float2(i + 1.0, 0.0)), u);
}
} // namespace cd

[[stitchable]] half4 ohMyDesignMetaballs(float2 position, half4 currentColor,
                                         float2 size, float time,
                                         float count, float ballSize,
                                         half4 back, half4 colorA, half4 colorB) {
    float2 uv = cd::centeredUV(position, size) + 0.5;
    float t = 0.2 * (time * 3.6 + 2503.4);

    float3 totalColor = float3(0.0);
    float totalShape = 0.0;
    float totalOpacity = 0.0;

    for (int i = 0; i < 20; ++i) {
        if (i >= int(ceil(count))) break;
        float idxFract = float(i) / 20.0;
        float angle = 6.28318530718 * idxFract;
        float speed = 1.0 - 0.2 * idxFract;
        float nx = cd::metaballsNoise(angle * 10.0 + float(i) + t * speed);
        float ny = cd::metaballsNoise(angle * 20.0 + float(i) - t * speed);
        float2 pos = float2(0.5) + 1e-4 + 0.9 * (float2(nx, ny) - 0.5);

        half4 c = (i % 2 == 0) ? colorA : colorB;
        float3 ballColor = float3(c.rgb) * float(c.a);

        float sizeFrac = float(i) > floor(count - 1.0) ? fract(count) : 1.0;
        float s = 1.0 - saturate(0.5 * length(uv - pos));
        float shape = pow(s, 45.0 - 30.0 * ballSize * sizeFrac) * pow(ballSize, 0.2);
        shape = smoothstep(0.0, 1.0, shape);

        totalColor += ballColor * shape;
        totalShape += shape;
        totalOpacity += float(c.a) * shape;
    }

    totalColor /= max(totalShape, 1e-4);
    totalOpacity /= max(totalShape, 1e-4);
    float edge = cd::edgeWidth(totalShape);
    float finalShape = smoothstep(0.4, 0.4 + edge, totalShape);
    return cd::overBackground(totalColor * finalShape, totalOpacity * finalShape, back);
}

// MARK: - DotOrbit

/// paper `packages/shaders/src/shaders/dot-orbit.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：`textureRandomizerR/GB` 改用 `cd::hash21/22`（同为 `floor` 语义；上游
/// `randomR(vec2(rand.x, rand.y))` 在 `rand ∈ [0, 1)` 时恒为同一个值，照搬）；`fwidth` 经 `cd::edgeWidth` 加下限；
/// 颜色数组收成两色阶梯渐变 + 底色，`u_stepsPerColor` 固定为 2；UV 改为 `cd::centeredUV` × 格数；时间按本仓 `ShaderMotion` 换算。
[[stitchable]] half4 ohMyDesignDotOrbit(float2 position, half4 currentColor,
                                        float2 size, float time,
                                        float cells, float dotSize, float sizeRange, float spreading,
                                        half4 back, half4 colorA, half4 colorB) {
    float2 uv = cd::centeredUV(position, size) * cells * 1.5;
    float t = time * 3.6 - 10.0;

    float2 iuv = floor(uv);
    float2 fuv = fract(uv);
    float spread = 0.25 * saturate(spreading);
    float minDist = 1.0;
    float2 randomizer = float2(0.0);
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float2 tile = float2(float(x), float(y));
            float2 rand = cd::hash22(iuv + tile);
            float2 centre = float2(0.5 + 1e-4) + spread * cos(t + 6.28318530718 * rand) - 0.5;
            centre = cd::rotate(centre, cd::hash21(rand) + 0.1 * t) + 0.5;
            float dist = length(tile + centre - fuv);
            if (dist < minDist) {
                minDist = dist;
                randomizer = rand;
            }
        }
    }
    float3 voronoi = float3(minDist, randomizer) + 1e-4;

    float radius = 0.25 * saturate(dotSize) - 0.5 * saturate(sizeRange) * voronoi.z;
    float e = cd::edgeWidth(voronoi.x);
    float dots = 1.0 - smoothstep(radius - e, radius + e, voronoi.x);

    half4 gradient = cd::steppedGradient2(voronoi.y, colorA, colorB, 2.0);
    float3 color = float3(gradient.rgb) * dots;
    return cd::overBackground(color, float(gradient.a) * dots, back);
}

// MARK: - Voronoi

/// paper `packages/shaders/src/shaders/voronoi.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）。
/// 上游原注：Original algorithm: https://www.shadertoy.com/view/ldl3W8（Inigo Quilez，MIT，见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：`textureRandomizerGB` 改用 `cd::hash22`；颜色数组收成「间隙 / 细胞 / 光晕」三档，细胞的第二色合成为
/// `mix(cellColor, glowColor, 0.5)`、`u_stepsPerColor` 固定为 1；
/// 边缘平滑宽度按上游 `u_scale == 1` 取常数；UV 改为 `cd::centeredUV` × 格数；时间按本仓 `ShaderMotion` 换算。
[[stitchable]] half4 ohMyDesignVoronoi(float2 position, half4 currentColor,
                                       float2 size, float time,
                                       float cells, float distortion, float gap, float glow,
                                       half4 gapColor, half4 cellColor, half4 glowColor) {
    float2 x = cd::centeredUV(position, size) * cells * 1.25;
    float t = time * 3.6;

    float2 ip = floor(x);
    float2 fp = fract(x);
    float2 mg = float2(0.0);
    float2 mr = float2(0.0);
    float md = 8.0;
    float rand = 0.0;
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            float2 g = float2(float(i), float(j));
            float2 o = cd::hash22(ip + g);
            float rawHash = o.x;
            o = 0.5 + distortion * sin(t + 6.28318530718 * o);
            float2 r = g + o - fp;
            float d = dot(r, r);
            if (d < md) {
                md = d;
                mr = r;
                mg = g;
                rand = rawHash;
            }
        }
    }
    md = 8.0;
    for (int j = -2; j <= 2; ++j) {
        for (int i = -2; i <= 2; ++i) {
            float2 g = mg + float2(float(i), float(j));
            float2 o = cd::hash22(ip + g);
            o = 0.5 + distortion * sin(t + 6.28318530718 * o);
            float2 r = g + o - fp;
            if (dot(mr - r, mr - r) > 0.00001) {
                md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
            }
        }
    }

    half4 cell = cd::steppedGradient2(saturate(rand), cellColor, mix(cellColor, glowColor, half(0.5)), 1.0);
    float3 color = float3(cell.rgb);
    float opacity = float(cell.a);

    float glows = pow(length(mr * glow), 1.5);
    color = mix(color, float3(glowColor.rgb) * float(glowColor.a), float(glowColor.a) * glows);
    opacity += float(glowColor.a) * glows;

    float smoothEdge = 0.02 / 2.0 * (1.0 + 0.5 * gap);
    float edge = smoothstep(gap - smoothEdge, gap + smoothEdge, md);
    color = mix(float3(gapColor.rgb) * float(gapColor.a), color, edge);
    opacity = mix(float(gapColor.a), opacity, edge);
    return half4(half3(color), half(saturate(opacity)));
}

// MARK: - SmokeRing

/// paper `packages/shaders/src/shaders/smoke-ring.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：`valueNoise` 复用 `cd::valueNoise`（上游经 `textureRandomizerR`，同为 `floor` 语义的双线性值噪声）；
/// 颜色数组收成两色 + 底色（两色时上游的倒序循环等价于 `mix(colors[1], colors[0], ring²)`）；丢弃 `colorBandingFix`；
/// UV 改为 `cd::centeredUV`；时间按本仓 `ShaderMotion` 换算。
namespace cd {
inline float2 smokeRingFbm(float2 n0, float2 n1, int iterations) {
    float2 total = float2(0.0);
    float amplitude = 0.4;
    for (int i = 0; i < 8; ++i) {
        if (i >= iterations) break;
        total.x += valueNoise(n0) * amplitude;
        total.y += valueNoise(n1) * amplitude;
        n0 *= 1.99;
        n1 *= 1.99;
        amplitude *= 0.65;
    }
    return total;
}

inline float smokeRingNoise(float2 uv, float2 pUv, float t, float noiseScale, int iterations) {
    float2 left = pUv + 0.03 * t;
    float period = max(abs(noiseScale * 6.28318530718), 1e-6);
    float2 right = float2(fract(pUv.x / period) * period, pUv.y) + 0.03 * t;
    float2 n = smokeRingFbm(left, right, iterations);
    return mix(n.y, n.x, smoothstep(-0.25, 0.25, uv.x));
}
} // namespace cd

[[stitchable]] half4 ohMyDesignSmokeRing(float2 position, half4 currentColor,
                                         float2 size, float time,
                                         float thickness, float radius, float innerShape,
                                         float noiseScale, float iterations,
                                         half4 back, half4 inner, half4 outer) {
    float2 uv = cd::centeredUV(position, size);
    float t = time * 3.6;
    int steps = int(iterations);

    float cycle = 3.0;
    float period2 = 2.0 * cycle;
    float local1 = fract((0.1 * t + cycle) / period2) * period2;
    float local2 = fract((0.1 * t) / period2) * period2;
    float blend = 0.5 + 0.5 * sin(0.1 * t * 3.14159265358979 / cycle - 0.5 * 3.14159265358979);

    float atg = atan2(uv.y, uv.x) + 0.001;
    float l = length(uv);
    float radialOffset = 0.5 * l - rsqrt(max(1e-4, l));
    float2 polar1 = float2(atg, local1 - radialOffset) * noiseScale;
    float2 polar2 = float2(atg, local2 - radialOffset) * noiseScale;
    float noise = mix(cd::smokeRingNoise(uv, polar1, t, noiseScale, steps),
                      cd::smokeRingNoise(uv, polar2, t, noiseScale, steps), blend);

    uv *= 0.8 + 1.2 * noise;
    float distance = length(uv);
    float ring = 1.0 - smoothstep(radius, radius + thickness, distance);
    ring *= smoothstep(radius - pow(innerShape, 3.0) * thickness, radius, distance);

    half4 gradient = mix(half4(outer.rgb * outer.a, outer.a), half4(inner.rgb * inner.a, inner.a), half(saturate(ring * ring)));
    float3 color = float3(gradient.rgb) * ring;
    return cd::overBackground(color, float(gradient.a) * ring, back);
}

// MARK: - Ashima 2D simplex noise（`Swirl` / `SimplexNoise` 共用）

/// Copyright (C) 2011 by Ashima Arts (Simplex noise)；Copyright (C) 2011-2016 by Stefan Gustavson（MIT，许可全文见 `ACKNOWLEDGEMENTS.md`）。
/// 经 paper `packages/shaders/src/shader-utils.ts` 的 `simplexNoise` 转手（paper 删去了原许可头，本仓按原作者署名）；
/// 逐行移植为 MSL，`mod` 改为 `x - y * floor(x / y)`（GLSL `mod` 语义）。
namespace cd {
inline float3 ashimaMod289(float3 x) {
    return x - 289.0 * floor(x / 289.0);
}

inline float2 ashimaMod289(float2 x) {
    return x - 289.0 * floor(x / 289.0);
}

inline float3 ashimaPermute(float3 x) {
    return ashimaMod289((x * 34.0 + 1.0) * x);
}

inline float snoise(float2 v) {
    const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = ashimaMod289(i);
    float3 p = ashimaPermute(ashimaPermute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}
} // namespace cd

// MARK: - Swirl

/// paper `packages/shaders/src/shaders/swirl.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）；
/// 噪声为 Ashima `snoise`（MIT，见上）。
/// 修改：`fwidth` 经 `cd::edgeWidth` 加下限；颜色数组收成两色 + 底色；丢弃 `colorBandingFix`；
/// 加噪声后的 `shape` 取 `pow` 前夹到 ≥ 0（上游负数取 `pow` 未定义）；UV 改为 `cd::centeredUV`；时间按本仓 `ShaderMotion` 换算。
[[stitchable]] half4 ohMyDesignSwirl(float2 position, half4 currentColor,
                                     float2 size, float time,
                                     float bandCount, float twistAmount, float centre, float proportion,
                                     float softness, float noiseAmount, float noiseFrequency,
                                     half4 back, half4 colorA, half4 colorB) {
    float2 uv = cd::centeredUV(position, size);
    float l = max(1e-4, length(uv));
    float t = time * 3.6;

    float angle = ceil(bandCount) * atan2(uv.y, uv.x) + t;
    float twist = 3.0 * saturate(twistAmount);
    float offset = pow(l, -twist) + angle / 6.28318530718;

    float shape = fract(offset);
    shape = 1.0 - abs(2.0 * shape - 1.0);
    if (noiseAmount > 0.0) {
        shape += noiseAmount * cd::snoise(15.0 * pow(noiseFrequency, 2.0) * uv);
    }
    shape = mix(0.0, shape, smoothstep(0.2, 0.2 + 0.8 * centre, pow(l, twist)));

    float prop = saturate(proportion);
    float exponent = mix(0.25, 1.0, prop * 2.0);
    exponent = mix(exponent, 10.0, max(0.0, prop * 2.0 - 1.0));
    shape = pow(max(shape, 0.0), exponent);

    float mixer = shape * 2.0;
    half4 colors[2] = { colorA, colorB };
    half4 gradient = half4(half3(colorA.rgb) * colorA.a, colorA.a);
    float outerShape = 0.0;
    for (int i = 1; i <= 2; ++i) {
        float m = saturate(mixer - float(i - 1));
        float aa = cd::edgeWidth(m);
        m = smoothstep(0.5 - 0.5 * softness - aa, 0.5 + 0.5 * softness + aa, m);
        if (i == 1) {
            outerShape = m;
        }
        half4 c = colors[i - 1];
        gradient = mix(gradient, half4(c.rgb * c.a, c.a), half(m));
    }

    float midAA = 0.1 * cd::edgeWidth(pow(l, -twist));
    outerShape = mix(0.0, outerShape, smoothstep(0.2, 0.2 + midAA, pow(l, twist)));
    return cd::overBackground(float3(gradient.rgb) * outerShape, float(gradient.a) * outerShape, back);
}

// MARK: - SimplexNoise

/// paper `packages/shaders/src/shaders/simplex-noise.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）；
/// 噪声为 Ashima `snoise`（MIT，见上）。
/// 修改：`fwidth` 经 `cd::edgeWidth` 加下限；颜色数组收成三档（`low` / `mid` / `high`）；去掉超出两端时从末色绕回首色的那段
/// （单色斜坡下它在深色块里冒出浅色斑），改为两端钳住；丢弃 `colorBandingFix`；UV 改为 `cd::centeredUV` × 缩放；时间按本仓 `ShaderMotion` 换算。
namespace cd {
inline float simplexSteppedSmooth(float m, float steps, float softness) {
    float stepT = floor(m * steps) / steps;
    float f = m * steps - floor(m * steps);
    float fw = steps * edgeWidth(m);
    float smoothed = smoothstep(0.5 - softness, min(1.0, 0.5 + softness + fw), f);
    return stepT + smoothed / steps;
}
} // namespace cd

[[stitchable]] half4 ohMyDesignSimplexNoise(float2 position, half4 currentColor,
                                            float2 size, float time,
                                            float scale, float stepsPerColor, float softness,
                                            half4 low, half4 mid, half4 high) {
    float2 uv = cd::centeredUV(position, size) * scale;
    float t = 0.2 * time * 3.6;

    float noise = 0.5 * cd::snoise(uv - float2(0.0, 0.3 * t)) + 0.5 * cd::snoise(2.0 * uv + float2(0.0, 0.32 * t));
    float shape = 0.5 + 0.5 * noise;

    const float count = 3.0;
    half4 colors[3] = { half4(low.rgb * low.a, low.a), half4(mid.rgb * mid.a, mid.a), half4(high.rgb * high.a, high.a) };
    float mixer = (shape - 0.5 / count) * count;
    float steps = max(1.0, stepsPerColor);

    half4 gradient = colors[0];
    for (int i = 1; i < 3; ++i) {
        float localM = cd::simplexSteppedSmooth(saturate(mixer - float(i - 1)), steps, 0.5 * softness);
        gradient = mix(gradient, colors[i], half(localM));
    }
    return gradient;
}

// MARK: - ColorPanels

/// paper `packages/shaders/src/shaders/color-panels.ts` @ `43cd68d`（Apache-2.0，见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：`u_edges`（bool）改为 0 / 1 浮点，由 Swift 侧的档位枚举给出；颜色数组收成两色 + 底色
/// （两色时 `panelsNumber` 恒为 12、`densityNormalizer` 恒为 1）；`u_scale` 取 1（抗锯齿宽度取常数）；
/// 丢弃 `colorBandingFix`；UV 改为 `cd::centeredUV`；时间按本仓 `ShaderMotion` 换算。
namespace cd {
inline float2 colorPanel(float angle, float2 uv, float invLength, float aa,
                         float angle1, float angle2, float blur, float edges) {
    const float zLimit = 0.5;
    float sinA = sin(angle);
    float cosA = cos(angle);
    float denom = sinA - uv.y * cosA;
    if (abs(denom) < 0.01) return float2(0.0);
    float z = uv.y / denom;
    if (z <= 0.0 || z > zLimit) return float2(0.0);

    float zRatio = z / zLimit;
    float panelMap = 1.0 - zRatio;
    float x = uv.x * (cosA * z + 1.0) * invLength;
    float zOffset = zRatio - 0.5;
    float left = -0.5 + zOffset * angle1;
    float right = 0.5 - zOffset * angle2;
    float blurX = aa + 2.0 * panelMap * blur;

    float panel = smoothstep(left - blurX, left + 0.25 * blurX, x) * (1.0 - smoothstep(right - 0.25 * blurX, right + blurX, x));
    panel *= mix(0.0, panel, smoothstep(0.0, 0.01, panelMap));

    float midScreen = abs(sinA);
    if (edges > 0.5) {
        panelMap = mix(0.99, panelMap, panel * saturate(panelMap / (0.15 * (1.0 - pow(midScreen, 0.1)))));
    } else if (midScreen < 0.07) {
        panel *= midScreen * 15.0;
    }
    return float2(panel, panelMap);
}

inline half4 colorPanelBlend(half4 color, float mask, float panelMap, float fadeIn, float fadeOut) {
    float fade = 1.0 - smoothstep(0.97 - 0.97 * fadeIn, 1.0, panelMap);
    fade *= smoothstep(-0.2 * (1.0 - fadeOut), fadeOut, panelMap);
    return half4(mix(half3(0.0), color.rgb, half(fade)), mix(half(0.0), color.a, half(fade))) * half(mask);
}
} // namespace cd

[[stitchable]] half4 ohMyDesignColorPanels(float2 position, half4 currentColor,
                                           float2 size, float time,
                                           float density, float angle1, float angle2, float panelLength,
                                           float edges, float blur, float fadeIn, float fadeOut, float gradientAmount,
                                           half4 back, half4 colorA, half4 colorB) {
    float2 uv = cd::centeredUV(position, size) * 1.25;
    float t = fract(0.02 * time * 3.6);
    bool reverseTime = t < 0.5;

    half4 colors[2] = { half4(colorA.rgb * colorA.a, colorA.a), half4(colorB.rgb * colorB.a, colorB.a) };
    const int colorsCount = 2;
    const int panelsNumber = 12;
    const float fPanels = 12.0;
    float aa = 0.005;
    float invLength = 1.5 / max(panelLength, 0.001);
    float panelGrad = 1.0 - saturate(gradientAmount);

    float3 color = float3(0.0);
    float opacity = 0.0;

    for (int set = 0; set < 2; ++set) {
        bool isForward = (set == 0 && !reverseTime) || (set == 1 && reverseTime);
        if (!isForward) continue;

        for (int i = 0; i < panelsNumber; ++i) {
            int idx = panelsNumber - 1 - i;
            float offset = float(idx) / fPanels + (set == 1 ? 0.5 : 0.0);
            float densityFract = fract(t + offset);
            float angleNorm = densityFract / density;
            if (densityFract >= 0.5 || angleNorm >= 0.3) continue;
            float smoothDensity = saturate((0.5 - densityFract) / 0.1) * saturate(densityFract / 0.01);
            float smoothAngle = saturate((0.3 - angleNorm) / 0.05);
            if (smoothDensity * smoothAngle < 0.001) continue;
            angleNorm = min(angleNorm, 0.5);
            float2 panel = cd::colorPanel(angleNorm * 6.28318530718 + 3.14159265358979, uv, invLength, aa, angle1, angle2, blur, edges);
            if (panel.x <= 0.001) continue;
            float mask = panel.x * smoothDensity * smoothAngle;
            half4 a = colors[idx % colorsCount];
            half4 b = colors[(idx + 1) % colorsCount];
            a = mix(a, b, half(max(0.0, smoothstep(0.0, 0.45, panel.y) - panelGrad)));
            half4 blended = cd::colorPanelBlend(a, mask, panel.y, fadeIn, fadeOut);
            color = float3(blended.rgb) + color * (1.0 - float(blended.a));
            opacity = float(blended.a) + opacity * (1.0 - float(blended.a));
        }

        for (int i = 0; i < panelsNumber; ++i) {
            int idx = panelsNumber - 1 - i;
            float offset = float(idx) / fPanels + (set == 0 ? 0.5 : 0.0);
            float densityFract = fract(-t + offset);
            float angleNorm = -densityFract / density;
            if (densityFract >= 0.5 || angleNorm < -0.3) continue;
            float smoothDensity = saturate((0.5 - densityFract) / 0.1) * saturate(densityFract / 0.01);
            float smoothAngle = saturate((angleNorm + 0.3) / 0.05);
            if (smoothDensity * smoothAngle < 0.001) continue;
            float2 panel = cd::colorPanel(angleNorm * 6.28318530718 + 3.14159265358979, uv, invLength, aa, angle1, angle2, blur, edges);
            float mask = panel.x * smoothDensity * smoothAngle;
            if (mask <= 0.001) continue;
            int colorIdx = (colorsCount - (idx % colorsCount)) % colorsCount;
            half4 a = colors[colorIdx];
            half4 b = colors[(colorIdx + 1) % colorsCount];
            a = mix(a, b, half(max(0.0, smoothstep(0.0, 0.45, panel.y) - panelGrad)));
            half4 blended = cd::colorPanelBlend(a, mask, panel.y, fadeIn, fadeOut);
            color = float3(blended.rgb) + color * (1.0 - float(blended.a));
            opacity = float(blended.a) + opacity * (1.0 - float(blended.a));
        }
    }
    return cd::overBackground(color, opacity, back);
}

// MARK: - StarNest

/// 「Star Nest」by Pablo Roman Andrioli（Kali），Shadertoy `XlfGRj`，源码头声明 MIT（见 `ACKNOWLEDGEMENTS.md`）。
/// 修改：上游的配色（`vec3(s, s*s, s*s*s*s)` 距离着色 + `saturation`）是 `.metal` 内的硬编码色调，按 FR-8 改为
/// 取结果的亮度标量压缩到 [0, 0.5) 后经 `cd::ramp3` 映射（星点最深到 `mid`，密集星团不饱和成实心块；丢掉按距离的冷暖色调）；去掉鼠标旋转（取上游鼠标在原点时的角度）；
/// `volsteps` / `iterations` 改为参数，由 Swift 侧的档位给出（上游固定 20 × 17，成本随全屏像素线性增长）；
/// 坐标改为 `cd::centeredUV`；时间按本仓 `ShaderMotion` 换算。
[[stitchable]] half4 ohMyDesignStarNest(float2 position, half4 currentColor,
                                        float2 size, float time,
                                        float volsteps, float iterations,
                                        half4 low, half4 mid, half4 high) {
    const float formuparam = 0.53;
    const float stepsize = 0.1;
    const float zoom = 0.8;
    const float tile = 0.85;
    const float brightness = 0.0015;
    const float darkmatter = 0.3;
    const float distfading = 0.73;

    float2 uv = cd::centeredUV(position, size);
    float3 dir = float3(uv * zoom, 1.0);
    float t = time * 3.6 * 0.01 + 0.25;

    float a1 = 0.5;
    float a2 = 0.8;
    float2x2 rot1 = float2x2(float2(cos(a1), sin(a1)), float2(-sin(a1), cos(a1)));
    float2x2 rot2 = float2x2(float2(cos(a2), sin(a2)), float2(-sin(a2), cos(a2)));
    dir.xz = dir.xz * rot1;
    dir.xy = dir.xy * rot2;
    float3 from = float3(1.0, 0.5, 0.5) + float3(t * 2.0, t, -2.0);
    from.xz = from.xz * rot1;
    from.xy = from.xy * rot2;

    float s = 0.1;
    float fade = 1.0;
    float3 v = float3(0.0);
    int steps = int(volsteps);
    int iters = int(iterations);
    for (int r = 0; r < 20; ++r) {
        if (r >= steps) break;
        float3 p = from + s * dir * 0.5;
        p = abs(float3(tile) - (p - 2.0 * tile * floor(p / (2.0 * tile))));
        float pa = 0.0;
        float a = 0.0;
        for (int i = 0; i < 17; ++i) {
            if (i >= iters) break;
            p = abs(p) / dot(p, p) - formuparam;
            a += abs(length(p) - pa);
            pa = length(p);
        }
        float dm = max(0.0, darkmatter - a * a * 0.001);
        a *= a * a;
        if (r > 6) fade *= 1.0 - dm;
        v += fade;
        v += float3(s, s * s, s * s * s * s) * a * brightness * fade;
        fade *= distfading;
        s += stepsize;
    }
    float raw = length(v) * 0.01 / 1.7320508;
    float intensity = 0.5 * (1.0 - exp(-2.0 * raw));
    return cd::ramp3(intensity, low, mid, high);
}

// MARK: - RefractiveGlass（layerEffect）

namespace cd {

/// 圆角矩形 SDF：内部为负、外部为正、边界为 0。
///
/// ⚠️⚠️ **许可已追到（#281）：iq 站点级 MIT** —— `https://iquilezles.org/articles/` 逐字
/// 「**all technical code snippets you'll find are under the MIT license**」。
/// ⚠️ 且**精确来源是 3D 页的单半径 `sdRoundBox`**（`vec3 q = abs(p) - b + r; return
/// length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;`），本函数是它的 2D 降维；
/// 2D 页上的 `sdRoundedBox` 是**四半径 `vec4` 变体**，不是这一份。
/// ⇒ 裁定 **`已追到兼容许可 · MIT`**，义务是转载 MIT 通知 + 具名 iq。
/// ⚠️ 下面「该页无许可声明」那句是**旧结论，已被上面这条推翻**，保留是为了记住
/// 教训本身：许可常常不在那篇文章上，而在站点的 `/articles/` 或 `legal.html`。
///
/// ⚠️ 这是 iq 2D distance functions 里圆角矩形 SDF 的**标准闭式解**
/// （`length(max(q,0)) + min(max(q.x,q.y),0) - r`）。
/// ⚠️ **上一版写「无第二种写法」——与 `valueNoise` 上一轮被判掉的是同一种
/// 可证伪的否定式断言**（第 5 轮终审 C-2）：iq 自己还有**四半径变体**
/// （`r.xy = p.x>0 ? r.xy : r.zw`，函数体不同），另有「先 `sdBox` 再减 r」的教学写法。
/// 公开出处为 Inigo Quilez 的 2D distance functions 文章——⚠️ **该页无许可声明**
/// （`docs/shader-provenance.md` §C #24 已就此把 `Glass` 判 `待追溯`）。
/// ⇒ **本函数按同一标准处理：在 `RefractiveGlass` 的 provenance 追溯完成前不得对外宣称原创。**
inline float roundedBoxSDF(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

} // namespace cd

/// 折射玻璃：把内容层当作**被折射的背景**，在圆角矩形区域内做透镜位移 + 边缘高光。
///
/// ⚠️ 这是 `layerEffect` 不是 `colorEffect`——它读的是**内容层本身**（`layer.sample`），
/// 因此不能当 `.background { }` 用，只能作用在内容上。
///
/// ⚠️⚠️ **本函数主体（透镜位移 + 通道色散）零署名**（第 5 轮终审 I-3）：
/// `dir = normalize(centred)` + `edgeness² · refraction` 位移 +「R 通道向内偏、
/// B 通道向外偏」的色散，是 2025 年 SwiftUI `layerEffect` "liquid glass" 一族里
/// 被转抄最广的形态，**指纹强度不低于 `InkSmoke` 的 q/r 级联**。
/// 上一版只给 `roundedBoxSDF` 署了 iq，主体留白 ⇒ **空白等于默认原创**，
/// 而本 PR 已经因为这个默认吃了四次亏。
/// ⇒ 登记为**待 #249 正向裁定**，不作原创声称；#249 的输入清单必须含本函数。
///
/// ⚠️⚠️ **#281 做完了这次追溯，结论有三条，别合并读**：
/// ① **上面那句「被转抄最广的形态」是没有证据的断言，已被证伪**——逐个读完具名的
///    SwiftUI-Metal 玻璃库（Inferno / GlassEffect / SwiftUIShaders / LiquidGlass /
///    LiquidGlassKit / victorBaro/TryMetal / ShipSwift）后，**没有找到这样一族**；
/// ② **仍未指认到具名上游**。可具名的只有 `cd::roundedBoxSDF`（⇒ iq，MIT）。
///    ⚠️ **「追不到」不等于「原创」**——裁定仍是 `待追溯`，**不是「自研」**；
/// ③ **分档由强指纹改判低指纹**：强档判据是「级联结构 / 变量命名保留 / 审美性的参数组合」，
///    本函数**三条全不成立**——无级联；`edgeness`/`rimBand` 追不到任何来源；
///    常量只有 `0.5`/`1e-5`/`3.0`/`0.99`，**全部功能性**，逐常量 grep 无物可 grep。
/// ⚠️ 该改判须在 `epic → main` 的评审上显式确认；不确认则按兜底回落 `不落地`
/// （撤回范围见 `docs/shader-provenance.md` 的专节）。承接 issue **#281**。
///
/// ⚠️ **不吃时间**：折射由几何驱动，不是动画。按 FR-12，`layerEffect` 类效果冻结时间
/// 输入、保留空间输入——这里干脆没有时间输入，从根上避开 `Float` 精度坑。
[[stitchable]] half4 ohMyDesignRefractiveGlass(float2 position, SwiftUI::Layer layer,
                                               float2 size, float cornerRadius,
                                               float refraction, float dispersion,
                                               half4 rim) {
    float2 s = max(size, float2(1.0));
    float2 centred = position - s * 0.5;
    float d = cd::roundedBoxSDF(centred, s * 0.5, min(cornerRadius, min(s.x, s.y) * 0.5));

    // 区域外原样透过——玻璃只在自己的形状里起作用。
    float aa = cd::edgeWidth(d);
    // `inside` 是**抗锯齿覆盖度**（0…1），不是布尔量。
    //
    // ⚠️⚠️ **第 4 轮 I-1 / 第 5 轮 C-1**：上一版把它算出来却**只当阈值用、
    // 从不参与混合**，于是有两条硬缝：
    //   · rim 覆盖到 `|d| < 3·aa`，而早退在 `d ≈ 0.955·aa` 就返回 ⇒ rim 从 0.76
    //     一步掉到 0 ⇒ **四个圆角的高光弧外缘是硬边、直边侧是柔边**；
    //   · 更大的一条：`edgeness = saturate(1 + d/halfmin)` 在 `d ≈ 0` 取**最大值 1**
    //     ⇒ 边界内侧一像素位移是满档（pronounced = 26px）、外侧一像素是 0
    //     ⇒ **整圈边界（不只圆角）有一条 26px 位移的阶跃**。
    // 抗锯齿代码自己制造锯齿，正是它要消除的东西。
    //
    // ⇒ ① 早退推到 rim 带之外（`d > 3·aa`）；② 位移与色散**乘上 `inside`**，
    //   让它随覆盖度淡出。两条缝一次消掉，且 `rimBand` 下面仍只算一次。
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (d > aa * 3.0) {
        return layer.sample(position);
    }

    // 透镜位移：越靠近边缘弯折越强（`d` 为负且接近 0 处最强），中心几乎不动。
    float edgeness = saturate(1.0 + d / max(min(s.x, s.y) * 0.5, 1.0));
    float2 dir = normalize(centred + 1e-5);
    float2 bend = dir * edgeness * edgeness * refraction * inside;

    // ⚠️⚠️ **两个输入都是预乘 alpha**，下面两段的正确性全挂在这一条上：
    // · `layer.sample` —— `SwiftUI_Metal.h` 的 `Layer::sample` 文档逐字写明；
    // · **`rim`（来自 `.color(...)`）** —— `SwiftUICore.swiftdoc` 里
    //   `Shader.Argument.color(_:)` 逐字写明「converts to a `half4` value,
    //   **as a premultiplied color in the target color space**」。
    //   ⚠️ 这一半上一版没写，而 `rim * rimBand` 的合法性完全挂在它上面。
    // ⚠️ **`layer.sample` 返回的是预乘 alpha 值**（`[R*A, G*A, B*A, A]`）——
    // 依据是 SwiftUI 自己的 `SwiftUI_Metal.h` 里 `Layer::sample` 的文档注释。
    // 下面两段的正确性全都挂在这一条上，改动前务必先读它。
    half4 sample = layer.sample(position - bend);

    // 色散：三通道各偏一点，只在边缘明显。
    //
    // ⚠️ **限制在近乎不透明的区域**（第 3 轮终审 I-6）：预乘语义下三个通道各自被
    // **不同位置的 alpha** 预乘过，把它们拼在一起再配中心采样的 `a`，在半透明区域
    // 会产出 `rgb > a` 的**非法预乘值**。`GlassSymbol` 的符号边缘（抗锯齿像素
    // alpha ∈ (0,1)）最容易暴露。半透明处的色散本就没有良定义 ⇒ 直接不做。
    if (dispersion > 0.0 && sample.a > 0.99h) {
        float2 spread = dir * edgeness * edgeness * refraction * dispersion * inside;
        sample.r = layer.sample(position - bend - spread).r;
        sample.b = layer.sample(position - bend + spread).b;
    }

    // 边缘高光：贴边一圈亮线，宽度用导数推，分辨率无关。
    float rimBand = 1.0 - smoothstep(0.0, aa * 3.0, abs(d));

    // ⚠️⚠️ **预乘空间里的 source-over，两个失效一次消掉**（第 3 轮终审 C-2）。
    // 这一行改过两次，两次都错，原因都是没读上面那条预乘约定：
    //   · 第 1 版 `mix(sample, rim, rimBand * rim.a)` —— `mix` 把 **alpha 一起插值**，
    //     贴边处 `alpha_out ≈ 0.75` ⇒ 不透明内容的边缘被打出约 25% 的**透明环**；
    //   · 第 2 版 `mix(sample, half4(rim.rgb, sample.a), k)` —— 保住了 `sample.a`，
    //     但 `sample.a == 0` 时输出 alpha 恒为 0 ⇒ **透明内容上 rim 整条消失**。
    //     而本仓唯一内建的 rim 使用者 `GlassSymbol` 正是把它施加在 SF Symbol 上，
    //     圆角矩形边框那一圈像素的符号 alpha 基本就是 0 ⇒ **默认路径直接失效**。
    //     （旧版在这一点上反而是对的——这是"用新失效换掉旧失效"。）
    // 正确写法是预乘的 source-over：`out = src + dst × (1 - src.a)`。
    // `alpha_out = src.a + sample.a × (1 - src.a) ≥ sample.a` ⇒ 不透明内容 alpha 不降
    //（无透明环），透明内容上 rim 照常显影，且输出恒为合法预乘值。
    half4 src = rim * half(rimBand);
    return src + sample * (1.0h - src.a);
}

// MARK: - GlassOrb（layerEffect）

/// 玻璃珠放大镜：在一个圆形区域内做**随距离衰减**的放大，中心放得最大、边缘回落到 1。
///
/// ## Provenance —— ⚠️ 这是一次**移植**，不是自研，别把它读成后者
///
/// **上游：[Inferno](https://github.com/twostraws/Inferno) 的
/// `Sources/Inferno/Shaders/Transformation/WarpingLoupe.metal`（Paul Hudson 等，MIT）。**
/// 本函数保留了它的**算法结构与表达**：
/// `totalZoom = 1` → 区域内 `totalZoom /= zoomFactor` → `totalZoom += smoothstep(…)/2`
/// → `newPosition = delta * totalZoom + center` → `layer.sample(newPosition)`。
/// ⇒ 档位按 `ACKNOWLEDGEMENTS.md` 的《归属分档》记 **较大段落移植**，
/// MIT 通知全文已转载在 `ACKNOWLEDGEMENTS.md` 的《Inferno》一节。
///
/// ⚠️ **我们做了三处修改，逐条列出（不列 = 默认原样，那是本仓栽过的坑）**：
/// ① **坐标空间**：上游在 UV（0…1）空间里算，并用 `dx² + dy²/aspect` 近似圆；
///    本函数直接在**点空间**里算 `dot(delta, delta)`，圆是真圆，
///    `radius` 是**点**而不是"归一化距离的平方"。参数含义因此不同，别照抄上游的调参建议。
/// ② **`softness`**：上游把 `smoothstep` 的那半档写死；本函数把它乘上一个 0…1 的系数，
///    供 Swift 侧在 Reduce Transparency 下取 0 —— 那时放大倍率在整个圆内是常数、
///    边界是硬边，观感从"玻璃珠"退化成"硬边镜片"（材质暗示消失，放大功能保留）。
///    ⚠️ 这一条是**本仓的增补**，不是上游的东西。
/// ③ ⚠️⚠️ **衰减项从 `+= smoothstep(…) / 2` 改成「向 1.0 插值」**
///    `+= (1 - totalZoom) * smoothstep(…)`。**这一条最重要，上一版漏了它**（#303 终审 C-1）。
///    上游那个 `/2` 与它自己 `zoomFactor` 的默认值 **2** 是**配套**的：
///    `1/2 + 1/2 = 1`，边界恰好回到 1。本函数**同时**改了坐标空间**并且**自选了
///    1.6 / 2.4 / 4.0 三个倍率档（`GlassOrbMagnification.factor`），**没有一档是 2**
///    ⇒ 照抄那个常数，边界处的 `totalZoom` 分别落在 **1.125 / 0.917 / 0.750**：
///    gentle 档 > 1（近边一圈**反向缩小**），另两档仍在放大 ⇒ 三档各留一道
///    约 **4.5 / 6 / 15 px** 源位移的接缝（200×200 灰阶渐变上实测）。
///    ⇒ 「越靠边放得越少、边界处回到 1」这句注释在照抄版下是**假的**。
///    插值形式让它对**任何**倍率都成立，代价是与上游那一行不再逐字相同。
///    判据：`RenderProofTests.glassOrbSofteningClosesTheSeam`（三档参数化，
///    带 `softness == 0` 的反向对照）。
///
/// ⚠️ **零硬编码色**（FR-8）：本函数一个颜色都不产生，只重采样内容层。
/// ⚠️ **不吃时间**：放大位置由手势（空间输入）驱动，不是动画。
/// 按 FR-12，`layerEffect` 类冻结时间输入、保留空间输入 —— 这里根本没有时间输入。
///
/// - Parameter position: 当前像素的用户空间坐标。
/// - Parameter layer: 被读取的内容层。
/// - Parameter size: 内容层尺寸（点）。⚠️ 目前仅用于把采样点夹回层内，
///   不参与距离计算 —— 与上游用它做 UV 归一化不同。
/// - Parameter focus: 放大中心（点），由手势给出。
/// - Parameter radius: 放大区域半径（点）。
/// - Parameter magnification: 中心处的放大倍率（> 1）。
/// - Parameter softness: 0…1。1 = 上游的衰减放大（玻璃珠），0 = 常数放大（硬边镜片）。
[[stitchable]] half4 ohMyDesignGlassOrb(float2 position, SwiftUI::Layer layer,
                                        float2 size, float2 focus,
                                        float radius, float magnification,
                                        float softness) {
    float2 delta = position - focus;
    float distanceSquared = dot(delta, delta);
    float radiusSquared = max(radius * radius, 1e-4);

    // 默认原样透过——1 个像素占 1 个像素的位置。
    float totalZoom = 1.0;

    if (distanceSquared < radiusSquared) {
        // 缩小采样步长 ⇒ 同样的屏幕面积里塞进更少的内容 ⇒ 放大。
        totalZoom /= max(magnification, 1e-3);
        // 把 `totalZoom` **向 1.0 插值**：越靠边放得越少，边界处（`smoothstep == 1`）
        // **恰好**回到 1，于是与圆外严丝合缝、没有硬边。
        // ⚠️⚠️ **这里不是上游的 `+= smoothstep(...) / 2`**（见文档注释的修改标注 ③）：
        // 那个 `0.5` 只在 `zoomFactor == 2` 时让边界回到 1，而本仓的三档是 1.6 / 2.4 / 4.0，
        // **没有一档是 2**，照抄会在三档上各留一道接缝（gentle 档甚至反向缩小）。
        // ⚠️ `softness == 0` 时这一项整个消失 ⇒ 圆内是常数放大 + 硬边（Reduce Transparency 档）。
        totalZoom += (1.0 - totalZoom) * smoothstep(0.0, radiusSquared, distanceSquared) * saturate(softness);
    }

    // ⚠️ 采样点夹回层内：`layer.sample` 越界返回透明，放大镜贴边时会咬出一圈空洞。
    // ⚠️ 上界是 `size - 0.5` 而不是 `size`：坐标恰为 `size` 已落在**最后一个有效像素之外**
    // （像素中心在 `size - 0.5`），夹到那里仍可能取到透明 —— 那正是本行想堵的失效形态。
    float2 sampled = clamp(delta * totalZoom + focus, float2(0.0), cd::lastPixel(size));
    return layer.sample(sampled);
}

// MARK: - Halftone（layerEffect）

namespace cd {

/// 二维旋转矩阵。⚠️ 事实性构造（`mat2(cos, ±sin, ∓sin, cos)`），
/// `docs/shader-provenance.md` 的《⑤-bis》已就 paper 的同款内联写法记明
/// 「旋转矩阵是事实性构造，**不产生通知义务**」——本仓这一份同理。
inline float2x2 rotate2(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

/// 预乘 alpha 的内容层采样 → 相对亮度。
///
/// ⚠️ **两步都不能省**：
/// ① `layer.sample` 是**预乘**值（`SwiftUI_Metal.h` 的 `Layer::sample` 文档逐字），
///    直接对 `rgb` 取亮度会把半透明处算暗；先除回去。
/// ② 透明处按**纸白**处理（`mix(1, lum, a)`）——这一步是 paper `halftone-dots.ts`
///    `getLumAtPx()` 的做法（`lum = mix(1., lum, tex.a)`），随该件一并署名。
///
/// ⚠️ 亮度权重 `0.2126 / 0.7152 / 0.0722` 是 **Rec. 709 的 luma 系数**（ITU-R BT.709），
/// 标准里的数字、不是谁的表达；paper 用的也是这一组。
inline float layerLuminance(half4 premultiplied) {
    float alpha = float(premultiplied.a);
    float3 straight = float3(premultiplied.rgb) / max(alpha, 1e-4);
    float luminance = dot(float3(0.2126, 0.7152, 0.0722), saturate(straight));
    return mix(1.0, luminance, saturate(alpha));
}

} // namespace cd

/// 半调网屏：把内容层按网格取样，用**点的大小**表示明暗，输出油墨色 + 纸色两色。
///
/// ## Provenance —— ⚠️ 这是一次**移植**
///
/// **上游：[paper-design/shaders](https://github.com/paper-design/shaders) 的
/// `packages/shaders/src/shaders/halftone-dots.ts`，Apache-2.0。**
/// 保留的结构：网格取样点 = `floor(p) + .5`、由**格心亮度**决定点半径
/// （`r = mix(baseR, 0, lum)`）、`length(uv - .5)` 的圆 + `fwidth` 抗锯齿边
/// （其 `getCircle()`）、透明处按纸白处理（其 `getLumAtPx()` 的 `mix(1., lum, tex.a)`）。
/// ⇒ Apache-2.0 的四条义务（LICENSE 全文 / `NOTICE` / 修改标注 / `.ts` 路径）
/// 见 `ACKNOWLEDGEMENTS.md` 的《paper-design/shaders》一节，**本行即第 4 条**。
///
/// ⚠️ **§4(b) 要求的「修改标注」—— 逐条列出本函数与上游的差异**：
/// ① **只移植了 `classic` 一种点形**；上游的 `gooey` / `holes` / `soft` 三种、
///    `u_grid == 1` 的六边形网格、`u_inverted`、`u_contrast` 的 sigmoid 对比度、
///    `grainMixer` / `grainOverlay` / `grainSize` 三档颗粒，**都没有移植**。
/// ② **只移植了 `halftone-dots.ts`，没有移植 `halftone-cmyk.ts`**（四色分色版）。
///    ⚠️⚠️ 这一条不是省事：`halftone-cmyk.ts:80` 声明 `uniform sampler2D u_noiseTexture`、
///    `:98` 本地定义 `randomRG()` 从该纹理取随机、`:171` 真的调用它
///    （`docs/shader-provenance.md` 的《⑤-bis》第 6 轮终审新发现的第 5 件）。
///    移植它必须先决定"随包发一张预计算噪声纹理"还是"换程序化 hash"，
///    **本次选择的是把该入口整个划出范围**，理由与代价写在
///    `docs/shader-provenance.md` 的《`Halftone` 的落地记录（#283）》。
///    ⚠️ `halftone-dots.ts` 自身**不依赖** `u_noiseTexture`（它 import 的是
///    `proceduralHash21`，程序化的），所以本次移植不携带那条依赖。
/// ③ **网屏角度参数化**：上游没有整体旋转，本函数把网格整体旋转 `angle`
///    （印刷业的单色网屏惯例角度由 Swift 侧给出）。
/// ④ **两色输出由 Swift 侧传入**（FR-8：`.metal` 零硬编码色）；上游的
///    `u_originalColors` 保留原图色那一档没有移植。
///
/// ⚠️ **本函数不含 paper 的任何 hash**：paper 的 `proceduralHash21` /
/// `halftone-cmyk.hash23` 追到 **Dave Hoskins**（`19.19`）与 **iq**（`0.3183099`），
/// 两位的 MIT 通知义务由本仓在 `ACKNOWLEDGEMENTS.md` 补齐（paper 的 `NOTICE` 只字未提）。
/// 本次移植**没有复制那些 hash**（本函数一个 hash 都不调用），
/// 通知照给 —— 宁可多给，成本为零。
///
/// ⚠️ **不吃时间**：半调是对内容层的**空间**重排，没有时间输入。
///
/// - Parameter position: 当前像素的用户空间坐标。
/// - Parameter layer: 被读取的内容层。
/// - Parameter size: 内容层尺寸（点）。
/// - Parameter cell: 网格边长（点）。
/// - Parameter angle: 网屏角度（弧度）。
/// - Parameter dotScale: 最黑处的点半径（格宽的倍数）。
/// - Parameter ink: 油墨色（预乘）。
/// - Parameter paper: 纸色（预乘）。传全透明即"印在透明背景上"。
[[stitchable]] half4 ohMyDesignHalftone(float2 position, SwiftUI::Layer layer,
                                        float2 size, float cell, float angle,
                                        float dotScale, half4 ink, half4 paper) {
    float cellSize = max(cell, 1.0);
    float2x2 screen = cd::rotate2(angle);
    // ⚠️ 旋转矩阵是正交的 ⇒ 逆 = 转置。别再算一次 `rotate2(-angle)`。
    float2x2 unscreen = transpose(screen);

    float2 gridSpace = (screen * position) / cellSize;
    float2 cellIndex = floor(gridSpace);
    float2 inCell = gridSpace - cellIndex;

    // 格心 → 回到用户空间，作为该格的取样点。
    float2 samplePoint = unscreen * ((cellIndex + 0.5) * cellSize);
    samplePoint = clamp(samplePoint, float2(0.0), cd::lastPixel(size));

    float luminance = cd::layerLuminance(layer.sample(samplePoint));

    // 越暗点越大；纸白（luminance == 1）处半径为 0，一个点都不落。
    float radius = mix(max(dotScale, 0.0), 0.0, luminance);
    float distanceToCentre = length(inCell - 0.5);
    float aa = cd::edgeWidth(distanceToCentre);
    // ⚠️ `step` 那一项不是冗余：`radius == 0` 时 `smoothstep(-aa, aa, 0)` 在**格心那一像素**
    // 仍返回 0 ⇒ `coverage == 1` ⇒ **纯白区域每一格的中心都会落一个 1px 的墨点**。
    // 抗锯齿把半径为 0 的点画成了可见的点，实测（`RenderProofTests` 的白底一条）才暴露。
    float coverage = step(1e-4, radius) * (1.0 - smoothstep(radius - aa, radius + aa, distanceToCentre));

    // ⚠️ 两个输入都是**预乘**色（`.color(...)` 的文档逐字），预乘空间里做线性插值合法。
    return mix(paper, ink, half(saturate(coverage)));
}
