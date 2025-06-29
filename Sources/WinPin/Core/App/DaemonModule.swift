import Cocoa

@MainActor
class DaemonModule: AppModule {
  enum DaemonCommand: String, CaseIterable {
    case daemon = "daemon"
    case killDaemon = "kill"
  }

  private let daemonPath = "/tmp/winpin-daemon"
  private let daemonLogPath = "/tmp/winpin-daemon-log"
  private let fs = FileManager.default

  func runCommand(command: DaemonCommand) {
    switch command {
    case .daemon:
      let _ = killRunningDaemon()
      return runAsDaemon()
    case .killDaemon:
      if !killRunningDaemon() {
        print("Didn't find any daemons")
      }
    }
  }

  private func runAsDaemon() {
    guard let appBin = getCliArg(at: 0) else {
      fatalError("Impossible case CLI arg doesn't contain binary name")
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.standardOutput = FileHandle(forWritingAtPath: daemonLogPath)
    p.standardError = FileHandle(forWritingAtPath: daemonLogPath)
    p.arguments = [appBin]

    do {
      try p.run()
      try "\(p.processIdentifier)".write(toFile: daemonPath, atomically: true, encoding: .utf8)
      print("Started in daemon mode, PID: \(p.processIdentifier)")
    } catch let error {
      print("Failed with error \(error), terminating...")
      p.terminate()
    }
  }

  private func killRunningDaemon() -> Bool {
    do {
      let content = try String(contentsOfFile: daemonPath, encoding: .utf8)
      guard let pid = Int32(content) else {
        print("Impossible case, daemon file doesn't contain valid pid")
        exit(1)
      }
      kill(pid, SIGKILL)
      return true
    } catch {
      return false
    }
  }
}
