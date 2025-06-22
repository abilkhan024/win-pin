import AppKit
import ApplicationServices
import Cocoa
import SwiftUI

class AxModule: AppModule {
  override func onLaunch(_ app: NSApplication) {
    if !AXIsProcessTrusted() {
      print(
        """

          AXIsProcessTrusted is false! App requires a11y permissions.

          Thereforce you must allow a11y permission to the 'running app' aka your terminal client e.g. iTerm2. To do that:

            1. Go to Settings -> Privacy & Security -> Accessibility
            2. Press "+"
            3. Add your terminal app
            4. Restart the app

        """)

      exit(1)
    }
  }

  func getFrontmostWindow() -> AXUIElement? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var focusedWindow: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      axApp,
      kAXFocusedWindowAttribute as CFString,
      &focusedWindow
    )

    if result == .success {
      return (focusedWindow as! AXUIElement)
    }

    return nil
  }

  func getWindowId(_ window: AXUIElement) -> CGWindowID? {
    var titleRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
      let title = titleRef as? String
    else { return nil }

    var pid: pid_t = 0
    guard AXUIElementGetPid(window, &pid) == .success else { return nil }

    guard
      let windowsList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        as? [[String: AnyObject]]
    else {
      return nil
    }

    var result: (id: CGWindowID, length: Int)? = nil

    for window in windowsList {
      guard let windowId = window[kCGWindowNumber as String] as? CGWindowID else {
        continue
      }
      let windowPid = window[kCGWindowOwnerPID as String] as? pid_t
      let windowTitle = window[kCGWindowName as String] as? String ?? ""
      let intersectionLength = maxCommonSubstringLength(windowTitle, title)
      if pid != windowPid {
        continue
      }
      guard let cur = result else {
        result = (id: windowId, length: intersectionLength)
        continue
      }
      if intersectionLength > cur.length {
        result = (id: windowId, length: intersectionLength)
      }
    }

    return result?.id
  }

  func focusWindow(_ window: AXUIElement) {
    // Set window as main
    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
    // Set window as focused
    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)

    // Also activate the owning app
    var pid: pid_t = 0
    if AXUIElementGetPid(window, &pid) == .success {
      if let app = NSRunningApplication(processIdentifier: pid) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
      }
    }
  }

  func focusWindow(with id: CGWindowID) {
    guard
      let windowsList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        as? [[String: AnyObject]]
    else {
      return
    }
    guard
      let window = windowsList.first(where: { window in
        guard let windowId = window[kCGWindowNumber as String] as? CGWindowID else {
          return false

        }

        return windowId == id
      })
    else {
      return
    }
    let title = window[kCGWindowName as String] as? String ?? ""
    guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, !title.isEmpty else { return }

    var result: (window: AXUIElement, length: Int)? = nil

    for axWindow in getWindowsOfApp(pid: pid) {
      var windowTitleRaw: CFTypeRef? = nil

      let axResult = AXUIElementCopyAttributeValue(
        axWindow, kAXTitleAttribute as CFString, &windowTitleRaw)

      guard axResult == .success else { continue }
      let windowTitle = windowTitleRaw as! String
      let intersectionLength = maxCommonSubstringLength(windowTitle, title)
      guard let cur = result else {
        result = (window: axWindow, length: intersectionLength)
        continue
      }
      if intersectionLength > cur.length {
        result = (window: axWindow, length: intersectionLength)
      }

    }

    if let window = result?.window {
      self.focusWindow(window)
    }
  }

  private func getWindowsOfApp(pid: pid_t) -> [AXUIElement] {
    let appRef = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?

    let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
    guard result == .success, let windowList = value as? [AXUIElement] else {
      return []
    }
    return windowList
  }

  func maxCommonSubstringLength(_ s1: String, _ s2: String) -> Int {
    if s1.isEmpty || s2.isEmpty {
      return 0
    }
    let a = Array(s1)
    let b = Array(s2)
    let n = a.count
    let m = b.count
    var dp = [Int](repeating: 0, count: m + 1)
    var maxLen = 0

    for i in 1...n {
      var prev = 0
      for j in 1...m {
        let temp = dp[j]
        if a[i - 1] == b[j - 1] {
          dp[j] = prev + 1
          maxLen = max(maxLen, dp[j])
        } else {
          dp[j] = 0
        }
        prev = temp
      }
    }

    return maxLen
  }

  private func focusWindow(with: AXUIElement, pid: pid_t) {
    // Focus it
    AXUIElementSetAttributeValue(with, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(with, kAXFocusedAttribute as CFString, kCFBooleanTrue)

    // Activate app too
    if let app = NSRunningApplication(processIdentifier: pid) {
      app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
    return
  }

  func getFrontmostWindowId() -> CGWindowID? {
    guard let window = self.getFrontmostWindow() else {
      return nil
    }
    return self.getWindowId(window)
  }

}
