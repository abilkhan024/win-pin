import Cocoa

@MainActor
class AppModule: AnyObject {
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
final class App {
  static let shared = App()
  private let delegate = AppDelegate()
  private var modules: [AppModule] = []
  private let app = NSApplication.shared

  private init() {}

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
    app.run()
  }
}
