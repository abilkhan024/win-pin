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
    else {
      print("Failed title")
      return nil
    }

    var pid: pid_t = 0
    guard AXUIElementGetPid(window, &pid) == .success else {
      print("Failed pid")
      return nil
    }

    // Search CGWindowList for matching PID + title
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    let windowList =
      CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] ?? []

    var finalWindowNumber: CGWindowID? = nil
    for windowInfo in windowList {
      let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t
      let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

      guard let windowNumber = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
        continue
      }
      if windowPID == pid {
        finalWindowNumber = windowNumber
      }

      if windowPID == pid && windowTitle == title {
        finalWindowNumber = windowNumber
      }
    }

    return finalWindowNumber
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
      let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        as? [[String: AnyObject]]
    else { return }

    guard
      let target = windowList.first(where: { win in
        (win[kCGWindowNumber as String] as? CGWindowID) == id
      })
    else { return }

    guard let pid = target[kCGWindowOwnerPID as String] as? pid_t else { return }
    let title = target[kCGWindowName as String] as? String ?? ""

    // Find AXUIElement window with matching PID and title
    let axApp = AXUIElementCreateApplication(pid)

    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) != .success {
      return
    }

    guard let windows = value as? [AXUIElement] else { return }

    let sortedWindows = windows.map { win in
      var titleRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
        let winTitle = titleRef as? String
      {
        return (score: maxCommonSubstringLength(winTitle, title), win: Optional(win))
      }
      return (score: 0, win: nil)
    }.sorted { a, b in a.score > b.score }

    for entry in sortedWindows {
      if let win = entry.win {
        focusWindow(with: win, pid: pid)
      }
    }
  }

  func maxCommonSubstringLength(_ s1: String, _ s2: String) -> Int {
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
