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

  func getWindowDimensions(window: AXUIElement) -> (width: CGFloat, height: CGFloat)? {
    var sizeValue: AnyObject?
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
    var size = CGSize.zero
    guard
      let sizeAX = sizeValue as! AXValue?,
      AXValueGetValue(sizeAX, .cgSize, &size)
    else { return nil }

    return (width: size.width, height: size.height)
  }

  func getWindowPoint(window: AXUIElement) -> CGPoint? {
    var positionValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
      == .success,
      let pos = positionValue as! AXValue?
    {
      var point = CGPoint.zero
      if AXValueGetType(pos) == .cgPoint && AXValueGetValue(pos, .cgPoint, &point) {
        return CGPoint(x: point.x, y: point.y)
      }
    }

    return nil
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
    var pid: pid_t = 0
    if AXUIElementGetPid(window, &pid) == .success,
      let app = NSRunningApplication(processIdentifier: pid)
    {
      let axApp = AXUIElementCreateApplication(pid)
      AXUIElementSetAttributeValue(axApp, kAXHiddenAttribute as CFString, kCFBooleanFalse)
      AXUIElementPerformAction(axApp, kAXRaiseAction as CFString)

      app.unhide()
      app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
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

  func transform(window: AXUIElement, position: inout CGPoint, size: inout CGSize) {
    let posValue = AXValueCreate(.cgPoint, &position)!
    let sizeValue = AXValueCreate(.cgSize, &size)!
    var pid: pid_t = 0
    guard AXUIElementGetPid(window, &pid) == .success else {
      return
    }
    let app = AXUIElementCreateApplication(pid)

    // Some undocumented magic
    // References: https://github.com/nikitabobko/AeroSpace/blob/6323355a7e3358bc47e416c94fb9532def26f944/Sources/AppBundle/tree/MacApp.swift
    //             https://github.com/koekeishiya/yabai/commit/3fe4c77b001e1a4f613c26f01ea68c0f09327f3a
    //             https://github.com/rxhanson/Rectangle/pull/285
    let attr = "AXEnhancedUserInterface" as CFString

    var currentValue: CFTypeRef?
    let wasEnabled =
      AXUIElementCopyAttributeValue(app, attr, &currentValue) == .success
      && (currentValue as? Bool == true)

    if wasEnabled {
      let disabled = kCFBooleanFalse as CFTypeRef
      AXUIElementSetAttributeValue(app, attr, disabled)
    }

    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

    if wasEnabled {
      let enabled = kCFBooleanTrue as CFTypeRef
      AXUIElementSetAttributeValue(app, attr, enabled)
    }
  }
}
