import Cocoa

class CliApp: AnyObject {
  func getCliArgs() -> [String] {
    return CommandLine.arguments
  }
  func getCliArg(at pos: Int) -> String? {
    let args = getCliArgs()
    guard args.count > pos else { return nil }
    return args[pos]
  }
}

@MainActor
class AppModule: CliApp {
  func setup(_ app: NSApplication) {}
  func onLaunch(_ app: NSApplication) {}
  func onWillTerminate(_ app: NSApplication) {}
}

private class AppDelegate: NSObject, NSApplicationDelegate {
  private var launchListener: (() -> Void)? = nil
  private var willTerminateListener: (() -> Void)? = nil

  override init() { super.init() }

  func with(
    launchListener: @escaping () -> Void,
    willTerminateListener: @escaping () -> Void,
  ) {
    self.launchListener = launchListener
    self.willTerminateListener = willTerminateListener
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if let listener = self.launchListener {
      listener()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let listener = self.willTerminateListener {
      listener()
    }
  }
}

@MainActor
final class App: CliApp {
  static let shared = App()
  private let delegate = AppDelegate()
  private var modules: [AppModule] = []
  private let app = NSApplication.shared

  private func onDelegateLaunch() {
    for module in self.modules {
      module.onLaunch(app)
    }
  }

  private func onDelegateWillTerminate() {
    for module in self.modules {
      module.onWillTerminate(app)
    }
  }

  func with(modules: [AppModule]) -> App {
    self.modules = modules
    return self
  }

  func get<T: AnyObject>(_ moduleType: T.Type) -> T {
    for module in self.modules {
      if let matched = module as? T {
        return matched
      }
    }
    fatalError("Unused module is requested")
  }

  private func quitWithGuide(app: NSApplication, arg: String) {
    print(
      """

        What do you mean by '\(arg)'?

        May be you want to:

            winpin daemon - Run in daemon mode
            winpin kill - Kill process running daemon mode
            winpin - Run in foreground

      """)
    app.terminate(nil)
  }

  func run() {
    let app = NSApplication.shared
    for module in self.modules {
      module.setup(app)
    }
    delegate.with(
      launchListener: self.onDelegateLaunch,
      willTerminateListener: self.onDelegateLaunch
    )
    app.delegate = delegate
    app.setActivationPolicy(.accessory)

    guard let arg = getCliArg(at: 1) else {

      return app.run()
    }

    guard
      let daemonCommand = DaemonModule.DaemonCommand.allCases.first(where: { cmd in
        cmd.rawValue == arg
      })
    else {
      return quitWithGuide(app: app, arg: arg)
    }

    App.shared.get(DaemonModule.self).runCommand(command: daemonCommand)
  }
}
