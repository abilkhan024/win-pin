import SwiftUI

let workspaces = ["h", "k", "z", "x", "l", ";", "y", "u", "o", "p"]
var worspaceWindows: [String: CGWindowID?] = [:]

var shorcuts = try workspaces.map { key in
  [
    KeyboardShortcut(
      bind: try KeyboardMapping.create(from: "<D><M>\(key)"),
      exec: { _ in
        if let windowAtKey = worspaceWindows[key], let windowId = windowAtKey {
          App.shared.get(AxModule.self).focusWindow(with: windowId)
        } else {
          print("No window at \(key)")
        }
      }),
    KeyboardShortcut(
      bind: try KeyboardMapping.create(from: "<D><S><M>\(key)"),
      exec: { _ in
        worspaceWindows[key] = App.shared.get(AxModule.self).getFrontmostWindowId()
      }),
  ]
}.flatMap { shortcuts in shortcuts }

let fs = FileManager.default
let path = "/tmp/winpin.json"

shorcuts.append(
  KeyboardShortcut(
    bind: try KeyboardMapping.create(from: "<D><M>e"),
    exec: { _ in
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
        if !fs.fileExists(atPath: path) {
          fs.createFile(atPath: path, contents: nil, attributes: nil)
        }
        try jsonStr.write(toFile: path, atomically: true, encoding: .utf8)
      } catch {
      }
    }))

class WindowPinnerModule: AppModule {
  override func onLaunch(_ app: NSApplication) {
    do {
      guard let content = try String(contentsOfFile: path, encoding: .utf8).data(using: .utf8)
      else {
        return
      }
      let storedIds = try JSONDecoder().decode([String: Int].self, from: content)
      for entry in storedIds {
        worspaceWindows[entry.key] = CGWindowID(entry.value)
      }
    } catch {
    }

  }
}

App.shared
  .with(modules: [
    AxModule(),
    MenuModule(title: "📌"),
    ShortcutsModule.shared.listeningTo(shortcuts: shorcuts),
    WindowPinnerModule(),
  ])
  .run()
