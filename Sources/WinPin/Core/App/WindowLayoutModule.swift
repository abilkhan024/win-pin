import Cocoa

class WindowLayoutModule: AppModule {
  private var config: ConfigModule {
    return App.shared.get(ConfigModule.self)
  }
  private var ax: AxModule {
    return App.shared.get(AxModule.self)
  }
  private var shortcuts: ShortcutsModule {
    return App.shared.get(ShortcutsModule.self)
  }

  private func isSnappedRight(window: AXUIElement) -> Bool {
    guard let screenFrame = NSScreen.main?.frame else { return false }

    var posValue: AnyObject?
    var sizeValue: AnyObject?

    AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue)
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

    var size = CGSize.zero
    var pos = CGPoint.zero

    guard
      let posAX = posValue as! AXValue?,
      AXValueGetValue(posAX, .cgPoint, &pos),
      let sizeAX = sizeValue as! AXValue?,
      AXValueGetValue(sizeAX, .cgSize, &size)
    else { return false }

    let end = pos.x + size.width
    let maxEnd = screenFrame.maxX
    return maxEnd == end
  }

  private func snapToTop(window: AXUIElement) {
    let screenFrame = NSScreen.main?.frame ?? .zero
    var position = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
    var size = CGSize(width: screenFrame.width, height: screenFrame.height)
    snapTo(window: window, position: &position, size: &size)
  }

  private func snapToLeft(window: AXUIElement) {
    let screenFrame = NSScreen.main?.frame ?? .zero
    var position = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
    var size = CGSize(width: screenFrame.width / 2, height: screenFrame.height)
    snapTo(window: window, position: &position, size: &size)
  }

  private func snapTo(window: AXUIElement, position: inout CGPoint, size: inout CGSize) {
    let posValue = AXValueCreate(.cgPoint, &position)!
    let sizeValue = AXValueCreate(.cgSize, &size)!

    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
  }

  override func setup(_ app: NSApplication) {
    do {
      let shortcut = KeyboardShortcut(
        bind: try KeyboardMapping.create(from: "<D><M>n"),
        exec: { _ in
          guard let window = self.ax.getFrontmostWindow() else {
            return
          }
          if self.isSnappedRight(window: window) {
            self.snapToLeft(window: window)
          } else {
            self.snapToTop(window: window)
          }
        })
      shortcuts.listenTo(shortcuts: [shortcut])
    } catch {
      return
    }
  }
}
