import CoreMotion
import Foundation
import OhMyDesign

// 同一文件同时 import Apple 的 CoreMotion 框架与 OhMyDesign 时，`CoreMotion.press` 仍解析到本库 token；
// 框架类型须写不带模块前缀的形式（`CoreMotion.CMHeadphoneMotionManager` 会解析到本库类型而编译失败）。
nonisolated func coreMotionTokenCoexistsWithFramework() -> (TimeInterval, Any.Type) {
    (CoreMotion.press.duration, CMHeadphoneMotionManager.self)
}
