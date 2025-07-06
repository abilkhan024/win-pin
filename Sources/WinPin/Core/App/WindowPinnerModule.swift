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
  private var worspaceWindows: [String: CGWindowID?] = [:]

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
      worspaceWindows[entry.key] = CGWindowID(entry.value)
    }
  }

  private func saveWindowIds(_: CGEvent) {
    var worspaceIds: [String: Int] = [:]
    for entry in worspaceWindows {
      if let id = entry.value {
        worspaceIds[entry.key] = Int(id)
      }
    }
    let _ = App.shared.get(AxModule.self).getFrontmostWindowId()
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
      self.worspaceWindows[workspace] = App.shared.get(AxModule.self).getFrontmostWindowId()
    }
  }

  private func getOpenBinding(workspace: String) -> (_: CGEvent) -> Void {
    return { _ in
      if let windowAtKey = self.worspaceWindows[workspace], let windowId = windowAtKey {
        App.shared.get(AxModule.self).focusWindow(with: windowId)
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
