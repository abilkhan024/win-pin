import Cocoa
import CoreGraphics

private enum ConfigKey: String {
  case workspacePin = "workspace_pin"
  case workspaceOpen = "workspace_open"
  case saveWindows = "save_windows"
}

private let defaultConfig =
  """
  # Default config example, can copy this to config path
  \(ConfigKey.workspaceOpen.rawValue)_j=<D><M>j
  \(ConfigKey.workspacePin.rawValue)_j=<D><M><S>j
  \(ConfigKey.workspaceOpen.rawValue)_k=<D><M>k
  \(ConfigKey.workspacePin.rawValue)_k=<D><M><S>k
  \(ConfigKey.workspaceOpen.rawValue)_l=<D><M>l
  \(ConfigKey.workspacePin.rawValue)_l=<D><M><S>l
  \(ConfigKey.workspaceOpen.rawValue)_h=<D><M>h
  \(ConfigKey.workspacePin.rawValue)_h=<D><M><S>h
  \(ConfigKey.workspaceOpen.rawValue)_u=<D><M>u
  \(ConfigKey.workspacePin.rawValue)_u=<D><M><S>u
  \(ConfigKey.workspaceOpen.rawValue)_;=<D><M>;
  \(ConfigKey.workspacePin.rawValue)_;=<D><M><S>;
  \(ConfigKey.workspaceOpen.rawValue)_o=<D><M>o
  \(ConfigKey.workspacePin.rawValue)_o=<D><M><S>o
  \(ConfigKey.workspaceOpen.rawValue)_p=<D><M>p
  \(ConfigKey.workspacePin.rawValue)_p=<D><M><S>p
  \(ConfigKey.workspaceOpen.rawValue)_y=<D><M>y
  \(ConfigKey.workspacePin.rawValue)_y=<D><M><S>y
  \(ConfigKey.workspaceOpen.rawValue)_x=<D><M>x
  \(ConfigKey.workspacePin.rawValue)_x=<D><M><S>x
  \(ConfigKey.workspaceOpen.rawValue)_z=<D><M>z
  \(ConfigKey.workspacePin.rawValue)_z=<D><M><S>z
  \(ConfigKey.saveWindows.rawValue)=<D><M>e
  """

@MainActor
class ConfigModule: AppModule {
  struct WorkspaceMapping {
    let openMapping: String
    let pinMapping: String
    let workspace: String
  }

  private let keySplit = "="
  private var config: [String] = []

  private func getConfigEntries(from: String) -> [String] {
    return from.split(separator: "\n").map(String.init)
  }

  func load(path: String) {
    var configStr = defaultConfig
    print("Loading file at path '\(path)'")
    do {
      let content = try String(contentsOfFile: path, encoding: .utf8)
      configStr = content
      print("Loaded! Using config file from '\(path)'")
    } catch {
      print("Can't load. Using default config: \n\(defaultConfig)")
    }
    config = getConfigEntries(from: configStr)
  }

  private func getKeyValue(line: String) throws -> (key: String, value: String) {
    let keyValue = line.split(separator: keySplit)
    if keyValue.count != 2 {
      // Even though technically = could be used as mapping? May be will check later
      throw ParseError(message: "Config entry must have a single =")
    }
    let (key, value) = (keyValue[0], keyValue[1])
    return (String(key), String(value))
  }

  func getWorkspaceMappings() throws -> [WorkspaceMapping] {
    var mappings: [String: (open: String, pin: String)] = [:]

    for entry in config {
      if entry.starts(with: "#") {
        continue
      }
      let (key, value) = try getKeyValue(line: entry)
      var workspaceKey = ""
      var isOpen = false
      if key.starts(with: ConfigKey.workspaceOpen.rawValue) {
        isOpen = true
        workspaceKey = String(key.replacing("\(ConfigKey.workspaceOpen.rawValue)_", with: ""))
      } else if key.starts(with: ConfigKey.workspacePin.rawValue) {
        workspaceKey = String(key.replacing("\(ConfigKey.workspacePin.rawValue)_", with: ""))
      }
      guard !workspaceKey.isEmpty else { continue }
      if mappings[workspaceKey] == nil {
        mappings[workspaceKey] = (open: "", pin: "")
      }

      if isOpen {
        mappings[workspaceKey]!.open = String(value)
      } else {
        mappings[workspaceKey]!.pin = String(value)
      }
    }

    return try mappings.map { entry in
      if entry.value.pin.isEmpty || entry.key.isEmpty {
        throw ParseError(
          message: "Both open and pin mappings must be set for workspace '\(entry.key)'"
        )
      }

      return WorkspaceMapping(
        openMapping: entry.value.open,
        pinMapping: entry.value.pin,
        workspace: entry.key
      )
    }
  }

  func getSaveWindowsMapping() throws -> String {
    guard
      var configLine = getConfigEntries(from: defaultConfig).first(where: { entry in
        entry.starts(with: ConfigKey.saveWindows.rawValue)
      })
    else {
      throw RuntimeError(
        message: "Impossible case default config must contain save windows mapping"
      )
    }

    if let currentConfigLine = config.first(where: { entry in
      entry.starts(with: ConfigKey.saveWindows.rawValue)
    }) {
      configLine = currentConfigLine
    }

    let (_, value) = try getKeyValue(line: configLine)
    return value
  }
}
