import Cocoa
import CoreGraphics

private enum ConfigKey: String {
  case workspacePin = "workspace_pin"
  case workspaceOpen = "workspace_open"
  case saveWindows = "save_windows"
  case position = "position"
  case transform = "transform"
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
  # Position and transform definitions
  \(ConfigKey.position.rawValue)_top=0,0,100%,100%
  \(ConfigKey.position.rawValue)_left_q=0,0,50%,50%
  \(ConfigKey.position.rawValue)_right_q=50%,0,50%,50%
  \(ConfigKey.transform.rawValue)_[top,left_q,right_q]=<D><M>n
  """

@MainActor
class ConfigModule: AppModule {
  private let fs = FileManager.default
  private let keySplit = "="
  private var config: [String] = []

  private func getConfigEntries(from: String) -> [String] {
    return from.split(separator: "\n").map(String.init)
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

  private func getKeyValue(line: String) throws -> (key: String, value: String) {
    let keyValue = line.split(separator: keySplit)
    if keyValue.count != 2 {
      // Even though technically = could be used as mapping? May be will check later
      throw ParseError(message: "Config entry must have a single =")
    }
    let (key, value) = (keyValue[0], keyValue[1])
    return (String(key), String(value))
  }

  private func terminate(app: NSApplication, message: String) {
    print(message)
    app.terminate(nil)
  }

  func execTerminateOnFail(app: NSApplication, exec: () throws -> Void) {
    do {
      try exec()
    } catch let error as AppError {
      terminate(app: app, message: "ERROR: \(error.message)")
    } catch {
      terminate(app: app, message: "Unknown error")
    }
  }

  func parsePosition(value: Substring, field: String) throws -> WindowPositionUnit {
    guard let last = value.last else {
      throw ParseError(message: "\(field) can't be empty")
    }
    if last == "%" {
      let percentageStr = value.dropLast()
      guard let percentage = Float(percentageStr) else {
        throw ParseError(message: "\(field) percentage must be parsable as float")
      }
      return WindowPositionUnit(value: percentage, isPercentage: true)
    }
    if let numValue = Float(value) {
      return WindowPositionUnit(value: numValue, isPercentage: false)
    }
    throw ParseError(message: "\(field) must be parsable as float")
  }

  func getWindowPositions() throws -> [WindowPosition] {
    var positions: [WindowPosition] = []
    for entry in config {
      if entry.starts(with: ConfigKey.position.rawValue) {
        let (key, value) = try getKeyValue(line: entry)
        let name = key.replacing("\(ConfigKey.position.rawValue)_", with: "")
        let values = value.split(separator: ",")
        if values.count != 4 {
          throw ParseError(
            message:
              "Position definition must have 4 values seperated by commas (x,y,w,h) e.g. 0,0,100%,100%"
          )
        }

        let x = try parsePosition(value: values[0],  field: "x")
        let y = try parsePosition(value: values[1],  field: "y")
        let width = try parsePosition(value: values[2],  field: "width")
        let height = try parsePosition(value: values[3],  field: "height")

        let position = WindowPosition( name: name, x: x, y: y , width: width, height: height)
        positions.append(position)
      }
    }
    return positions
  }

  func getWindowTransforms(positions: [WindowPosition]) throws -> [WindowTransform] {
    var transforms: [WindowTransform] = []
    for entry in config {
      if entry.starts(with: ConfigKey.transform.rawValue) {
        let (key, value) = try getKeyValue(line: entry)
        guard let match = key.range(of: #"(?<=\[)(.*?)(?=\])"#, options: .regularExpression) else {
          throw ParseError(message: "Transform key property must follow pattern: transform_[x,y,z]")
        }
        let trasnformPositions = try String(key[match]).split(separator: ",").map { name in
          guard let position = positions.first(where: { position in position.name == name }) else {
            throw ParseError(message: "Transform key must contain defined positions")
          }
          return position
        }
        transforms.append(WindowTransform(cyclePositions: trasnformPositions, mapping: value))
      }
    }
    return transforms
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

  override func setup(_ app: NSApplication) {
    let path = getConfigPath()
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
}
