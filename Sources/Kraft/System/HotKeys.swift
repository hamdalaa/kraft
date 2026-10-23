import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts via Carbon `RegisterEventHotKey` (works without Accessibility permission).
@MainActor
final class HotKeys {
    enum Shortcut: UInt32, CaseIterable {
        /// ⌥Space — quick add from any app.
        case quickAdd = 1
        /// ⌃⌥D — show / hide all desktop stickies.
        case toggleDesktopStickies = 2

        var keyCode: UInt32 {
            switch self {
            case .quickAdd: UInt32(kVK_Space)
            case .toggleDesktopStickies: UInt32(kVK_ANSI_D)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .quickAdd: UInt32(optionKey)
            case .toggleDesktopStickies: UInt32(controlKey | optionKey)
            }
        }
    }

    static let shared = HotKeys()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    func register(_ shortcut: Shortcut, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        handlers[shortcut.rawValue] = action
        if let old = refs[shortcut.rawValue] { UnregisterEventHotKey(old) }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4B524654), id: shortcut.rawValue) // 'KRFT'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs[shortcut.rawValue] = ref } else { NSLog("Kraft: hotkey %u failed (%d)", shortcut.rawValue, status) }
    }

    fileprivate func fire(_ id: UInt32) { handlers[id]?() }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            MainActor.assumeIsolated { HotKeys.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
