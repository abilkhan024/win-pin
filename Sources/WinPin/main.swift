import SwiftUI

App.shared
  .with(modules: [
    AxModule(),
    MenuModule(title: "📌"),
    ShortcutsModule.shared,
    ConfigModule(),
    WindowPinnerModule(),
    DaemonModule(),
    WindowLayoutModule(),
  ])
  .run()
