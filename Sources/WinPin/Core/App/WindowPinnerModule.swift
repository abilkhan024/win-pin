import SwiftUI

struct WorkspaceMapping {
  let openMapping: String
  let pinMapping: String
  let workspace: String
}

class WindowPinnerModule: AppModule {
  private let fs = FileManager.default
  private let windowIdsPath = "/tmp/winpin.json"
  private var workspaceMappings: [WorkspaceMapping] = []
  private var saveWindowsMapping: String = ""
  private var worspaceWindows: [String: AXUIElement?] = [:]

  private var config: ConfigModule {
    return App.shared.get(ConfigModule.self)
  }
  private var shortcuts: ShortcutsModule {
    return App.shared.get(ShortcutsModule.self)
  }

  private func loadWindowIds() {
    guard
      let content = try? String(contentsOfFile: windowIdsPath, encoding: .utf8).data(using: .utf8)
    else { return }
    guard let storedIds = try? JSONDecoder().decode([String: Int].self, from: content) else {
      return
    }
    for entry in storedIds {
      worspaceWindows[entry.key] = App.shared.get(AxModule.self).findWindowBy(
        id: CGWindowID(entry.value))
    }
  }

  private func saveWindowIds(_: CGEvent) {
    var worspaceIds: [String: Int] = [:]
    let axModule = App.shared.get(AxModule.self)
    for entry in worspaceWindows {
      if let window = entry.value, axModule.isAlive(element: window),
        let id = axModule.getWindowId(window)
      {
        worspaceIds[entry.key] = Int(id)
      }
    }

    do {
      let jsonData = try JSONEncoder().encode(worspaceIds)
      guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
        return
      }
      if !fs.fileExists(atPath: windowIdsPath) {
        fs.createFile(atPath: windowIdsPath, contents: nil, attributes: nil)
      }
      try jsonStr.write(toFile: windowIdsPath, atomically: true, encoding: .utf8)
    } catch let error {
      print("Failed to save windows: \(error)")
    }

  }

  private func getPinBinding(workspace: String) -> (_: CGEvent) -> Void {
    return { _ in
      let window = App.shared.get(AxModule.self).getFrontmostWindow()
      self.worspaceWindows[workspace] = window
    }
  }

  private func getOpenBinding(workspace: String) -> (_: CGEvent) -> Void {
    return { _ in
      if let windowAtKey = self.worspaceWindows[workspace], let window = windowAtKey {
        App.shared.get(AxModule.self).focusWindow(window)
      } else {
        print("No window at \(workspace)")
      }
    }
  }

  private func setupWithConfig() throws {
    saveWindowsMapping = try config.getSaveWindowsMapping()
    workspaceMappings = try config.getWorkspaceMappings()

    var appShorctcuts = try workspaceMappings.map { el in
      [
        KeyboardShortcut(
          bind: try KeyboardMapping.create(from: el.openMapping),
          exec: getOpenBinding(workspace: el.workspace)
        ),
        KeyboardShortcut(
          bind: try KeyboardMapping.create(from: el.pinMapping),
          exec: getPinBinding(workspace: el.workspace)
        ),
      ]
    }.flatMap({ shortcuts in shortcuts })

    appShorctcuts.append(
      KeyboardShortcut(
        bind: try KeyboardMapping.create(from: saveWindowsMapping),
        exec: saveWindowIds
      )
    )

    shortcuts.listenTo(shortcuts: appShorctcuts)
  }

  override func setup(_ app: NSApplication) {
    loadWindowIds()
    config.execTerminateOnFail(app: app, exec: setupWithConfig)
  }
}
