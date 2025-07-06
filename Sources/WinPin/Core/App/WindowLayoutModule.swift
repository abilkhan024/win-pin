import Cocoa

struct WindowPosition {
  let name: String
  let x: WindowPositionUnit
  let y: WindowPositionUnit
  let width: WindowPositionUnit
  let height: WindowPositionUnit
}

struct WindowPositionUnit {
  let value: Float
  let isPercentage: Bool
}

struct WindowTransform {
  let cyclePositions: [WindowPosition]
  let mapping: String
}

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
  private var windowPositions: [AXUIElement: Int] = [:]

  private func getCgFloat(from: WindowPositionUnit, maxValue: CGFloat) -> CGFloat {
    if from.isPercentage {
      return (CGFloat(from.value) * maxValue) / 100.0
    }
    return CGFloat(from.value)
  }

  private func onTransformRequested(transform: WindowTransform) -> (_: CGEvent) -> Void {
    { _ in
      let ax = self.ax
      guard let window = ax.getFrontmostWindow() else { return }
      guard let currentPoint = ax.getWindowPoint(window: window) else { return }
      guard let currentDimensions = ax.getWindowDimensions(window: window) else { return }
      guard let screen = NSScreen.main else { return }
      let screenRect = NSScreen.main?.frame ?? .zero
      let frameHeight = screenRect.height - screen.visibleFrame.height

      let matchedIdx =
        transform.cyclePositions.firstIndex(where: { position in
          let startX =
            round(self.getCgFloat(from: position.x, maxValue: screenRect.maxX))
            == round(currentPoint.x)
          let startY =
            round(self.getCgFloat(from: position.y, maxValue: screenRect.maxY) + frameHeight)
            == round(currentPoint.y)
          let width =
            round(self.getCgFloat(from: position.width, maxValue: screenRect.width))
            == round(currentDimensions.width)
          let height =
            round(self.getCgFloat(from: position.height, maxValue: screenRect.height) - frameHeight)
            == round(currentDimensions.height)

          return startX && startY && width && height
        }) ?? self.windowPositions[window] ?? 0

      let nextIdx = (matchedIdx + 1) % transform.cyclePositions.count
      self.windowPositions[window] = nextIdx
      let nextPosition = transform.cyclePositions[nextIdx]
      var position = CGPoint(
        x: self.getCgFloat(from: nextPosition.x, maxValue: screenRect.maxX),
        y: self.getCgFloat(from: nextPosition.y, maxValue: screenRect.maxY) + frameHeight
      )
      var size = CGSize(
        width: self.getCgFloat(from: nextPosition.width, maxValue: screenRect.width),
        height: self.getCgFloat(from: nextPosition.height, maxValue: screenRect.height)
          - frameHeight
      )
      ax.transform(window: window, position: &position, size: &size)
    }
  }

  private func setupWithConfig() throws {
    let positions = try config.getWindowPositions()
    let transforms = try config.getWindowTransforms(positions: positions)

    let transformShortcuts = try transforms.map { transform in
      KeyboardShortcut(
        bind: try KeyboardMapping.create(from: transform.mapping),
        exec: onTransformRequested(transform: transform)
      )
    }

    shortcuts.listenTo(shortcuts: transformShortcuts)
  }

  override func setup(_ app: NSApplication) {
    config.execTerminateOnFail(app: app, exec: setupWithConfig)
  }
}
