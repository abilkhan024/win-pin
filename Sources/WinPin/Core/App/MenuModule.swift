import Cocoa

@MainActor
class MenuModule: AppModule {
  private let title: String

  init(title: String) { self.title = title }

  override func setup(_ app: NSApplication) {
    let menu = NSMenu()
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    statusItem.menu = menu
    statusItem.button?.title = title
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(app.terminate), keyEquivalent: "q"))
  }
}
