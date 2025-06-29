import SwiftUI

class WindowPinnerModule: AppModule {
  private let fs = FileManager.default
  private let windowIdsPath = "/tmp/winpin.json"
  private var workspaceMappings: [ConfigModule.WorkspaceMapping] = []
  private var saveWindowsMapping: String = ""
  private var worspaceWindows: [String: CGWindowID?] = [:]

  private var dependencies: (config: ConfigModule, shortcuts: ShortcutsModule) {
    return (
      config: App.shared.get(ConfigModule.self),
      shortcuts: App.shared.get(ShortcutsModule.self)
    )
  }

  private func loadWindowIds() {
    do {
      guard
        let content = try String(contentsOfFile: windowIdsPath, encoding: .utf8).data(using: .utf8)
      else { return }
      let storedIds = try JSONDecoder().decode([String: Int].self, from: content)
      for entry in storedIds {
        worspaceWindows[entry.key] = CGWindowID(entry.value)
      }
    } catch {
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
    } catch {
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

  private func terminate(app: NSApplication, message: String) {
    print(message)
    app.terminate(nil)
  }

  private func getConfigPath() -> String {
    guard let configPath = ProcessInfo.processInfo.environment["WINPIN_CONFIG_PATH"] else {
      let filename = "winpin"
      let homeDirectoryURL = fs.homeDirectoryForCurrentUser
      let configDirectoryURL = homeDirectoryURL.appendingPathComponent(".config", isDirectory: true)
      let filePath = configDirectoryURL.appendingPathComponent(filename).path
      return filePath
    }

    print("WINPIN_CONFIG_PATH is set reading from custom path '\(configPath)'")
    return configPath
  }

  override func setup(_ app: NSApplication) {
    loadWindowIds()
    do {
      let configPath = getConfigPath()
      dependencies.config.load(path: configPath)
      saveWindowsMapping = try dependencies.config.getSaveWindowsMapping()
      workspaceMappings = try dependencies.config.getWorkspaceMappings()

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

      dependencies.shortcuts.listenTo(shortcuts: appShorctcuts)
    } catch let error as AppError {
      terminate(app: app, message: "ERROR: \(error.message)")
    } catch {
      terminate(app: app, message: "Unknown error")
    }
  }
}
