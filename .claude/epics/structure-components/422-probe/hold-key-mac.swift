import CoreGraphics
import Foundation

// usage: swift hold-key-mac.swift <keycode> <seconds>
// 只发一次 keyDown、等待、再发 keyUp；不自己合成任何 repeat 事件——
// 重复与否完全由系统决定，这正是要观测的量。
let args = CommandLine.arguments
let code = CGKeyCode(UInt16(args[1])!)
let seconds = Double(args[2])!
let source = CGEventSource(stateID: .hidSystemState)
CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)!.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: seconds)
CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)!.post(tap: .cghidEventTap)
