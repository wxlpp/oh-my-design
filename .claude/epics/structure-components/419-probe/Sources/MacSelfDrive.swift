#if canImport(AppKit)
import AppKit
import SwiftUI

@MainActor
enum MacSelfDrive {
    struct Step {
        let label: String
        let keyCode: UInt16
        let flags: NSEvent.ModifierFlags
        let characters: String
        let charactersIgnoringModifiers: String
    }

    static let steps: [Step] = [
        Step(label: "downArrow-1", keyCode: 125, flags: [], characters: "\u{F701}", charactersIgnoringModifiers: "\u{F701}"),
        Step(label: "downArrow-2", keyCode: 125, flags: [], characters: "\u{F701}", charactersIgnoringModifiers: "\u{F701}"),
        Step(label: "upArrow", keyCode: 126, flags: [], characters: "\u{F700}", charactersIgnoringModifiers: "\u{F700}"),
        Step(label: "rightArrow", keyCode: 124, flags: [], characters: "\u{F703}", charactersIgnoringModifiers: "\u{F703}"),
        Step(label: "leftArrow", keyCode: 123, flags: [], characters: "\u{F702}", charactersIgnoringModifiers: "\u{F702}"),
        Step(label: "home", keyCode: 115, flags: [.function], characters: "\u{F729}", charactersIgnoringModifiers: "\u{F729}"),
        Step(label: "end", keyCode: 119, flags: [.function], characters: "\u{F72B}", charactersIgnoringModifiers: "\u{F72B}"),
        Step(label: "space", keyCode: 49, flags: [], characters: " ", charactersIgnoringModifiers: " "),
        Step(label: "return", keyCode: 36, flags: [], characters: "\r", charactersIgnoringModifiers: "\r"),
        Step(label: "shift+downArrow", keyCode: 125, flags: [.shift], characters: "\u{F701}", charactersIgnoringModifiers: "\u{F701}"),
        Step(label: "shift+upArrow", keyCode: 126, flags: [.shift], characters: "\u{F700}", charactersIgnoringModifiers: "\u{F700}"),
        Step(label: "control+a", keyCode: 0, flags: [.control], characters: "\u{01}", charactersIgnoringModifiers: "a"),
        Step(label: "command+a", keyCode: 0, flags: [.command], characters: "a", charactersIgnoringModifiers: "a"),
        Step(label: "char-g", keyCode: 5, flags: [], characters: "g", charactersIgnoringModifiers: "g"),
        Step(label: "asterisk", keyCode: 28, flags: [.shift], characters: "*", charactersIgnoringModifiers: "8"),
        Step(label: "shift+g", keyCode: 5, flags: [.shift], characters: "G", charactersIgnoringModifiers: "g"),
        Step(label: "F2", keyCode: 120, flags: [.function], characters: "\u{F705}", charactersIgnoringModifiers: "\u{F705}"),
        Step(label: "tab", keyCode: 48, flags: [], characters: "\t", charactersIgnoringModifiers: "\t"),
    ]

    static func start(state: SpikeState) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            self.reportWindowState(state: state, tag: "before")
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(window.contentView)
            }
            try? await Task.sleep(for: .milliseconds(800))
            self.reportWindowState(state: state, tag: "after-activate")

            if SpikeEnv.preludeTabs > 0 {
                let tab = Step(label: "prelude-tab", keyCode: 48, flags: [], characters: "\t", charactersIgnoringModifiers: "\t")
                for index in 1...SpikeEnv.preludeTabs {
                    state.log("PRELUDE", "tab #\(index)")
                    self.send(tab, mechanism: "NSApp.postEvent")
                    try? await Task.sleep(for: .milliseconds(300))
                    self.reportWindowState(state: state, tag: "after-tab-\(index)")
                }
            }

            let mechanisms = ProcessInfo.processInfo.environment["SPIKE_CGEVENT"] == "1"
                ? ["NSApp.postEvent", "CGEvent.postToPid"]
                : ["NSApp.postEvent"]
            for mechanism in mechanisms {
                state.log("MECHANISM", mechanism)
                for step in self.steps {
                    state.log("SEND", "\(mechanism) \(step.label)")
                    self.send(step, mechanism: mechanism)
                    try? await Task.sleep(for: .milliseconds(220))
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
            state.log("DONE", "self-drive complete")
            try? await Task.sleep(for: .milliseconds(500))
            NSApplication.shared.terminate(nil)
        }
    }

    private static func reportWindowState(state: SpikeState, tag: String) {
        let app = NSApplication.shared
        let window = app.windows.first
        let detail = "tag=\(tag) windows=\(app.windows.count) isActive=\(app.isActive) keyWindow=\(app.keyWindow != nil) w.isKey=\(window?.isKeyWindow ?? false) w.isVisible=\(window?.isVisible ?? false) firstResponder=\(String(describing: window?.firstResponder))"
        state.log("WINDOW", detail)
    }

    private static func send(_ step: Step, mechanism: String) {
        if mechanism == "NSApp.postEvent" {
            let windowNumber = NSApplication.shared.windows.first?.windowNumber ?? 0
            for type in [NSEvent.EventType.keyDown, .keyUp] {
                guard let event = NSEvent.keyEvent(
                    with: type,
                    location: .zero,
                    modifierFlags: step.flags,
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: windowNumber,
                    context: nil,
                    characters: step.characters,
                    charactersIgnoringModifiers: step.charactersIgnoringModifiers,
                    isARepeat: false,
                    keyCode: step.keyCode
                ) else { continue }
                NSApplication.shared.postEvent(event, atStart: false)
            }
        } else {
            guard let source = CGEventSource(stateID: .privateState) else { return }
            var flags: CGEventFlags = []
            if step.flags.contains(.shift) { flags.insert(.maskShift) }
            if step.flags.contains(.control) { flags.insert(.maskControl) }
            if step.flags.contains(.option) { flags.insert(.maskAlternate) }
            if step.flags.contains(.command) { flags.insert(.maskCommand) }
            if step.flags.contains(.function) { flags.insert(.maskSecondaryFn) }
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: step.keyCode, keyDown: down) else { continue }
                event.flags = flags
                event.postToPid(ProcessInfo.processInfo.processIdentifier)
            }
        }
    }
}
#endif
