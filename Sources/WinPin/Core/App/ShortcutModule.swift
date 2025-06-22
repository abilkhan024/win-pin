import Cocoa
import CoreGraphics

struct KeyboardShortcut {
  let bind: KeyboardMapping
  let exec: (_ event: CGEvent) -> Void
}

@MainActor
class ShortcutsModule: AppModule {
  static let shared = ShortcutsModule()
  private override init() {}

  private var eventTap: CFMachPort?
  private var shortcuts: [KeyboardShortcut] = []

  func listeningTo(shortcuts: [KeyboardShortcut]) -> ShortcutsModule {
    self.shortcuts = shortcuts
    return self
  }

  func getShortcuts() -> [KeyboardShortcut] {
    return self.shortcuts
  }

  override func setup(_ app: NSApplication) {
    let eventMask = (1 << CGEventType.keyDown.rawValue)
    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: { _, type, event, _ in

        let preserve = Unmanaged.passRetained(event)
        if type != .keyDown {
          return preserve
        }

        for shortcut in ShortcutsModule.shared.shortcuts {
          if shortcut.bind.matches(event: event) {
            DispatchQueue.main.async { shortcut.exec(event) }
            return nil
          }
        }

        return preserve
      },
      userInfo: nil
    )

    if let eventTap = eventTap {
      let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
      CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      CGEvent.tapEnable(tap: eventTap, enable: true)
    }

  }

  // static func stop() {
  //   if let eventTap = eventTap {
  //     CGEvent.tapEnable(tap: eventTap, enable: false)
  //     self.listeners.removeAll()
  //   }
  // }
}
