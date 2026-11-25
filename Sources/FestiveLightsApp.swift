import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "ms.blackbox.festivelights")
            .filter { $0.processIdentifier != me }
        // Starten zwei Instanzen zugleich, bleibt die ältere (nach Startzeit, bei Gleichstand die mit der kleineren Prozessnummer)
        let myStart = NSRunningApplication.current.launchDate ?? .distantFuture
        let older = others.filter { ($0.launchDate ?? .distantFuture, $0.processIdentifier) < (myStart, me) }
        if !older.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("ms.blackbox.festivelights.showSettings"), object: nil, deliverImmediately: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        controller = AppController()
        controller?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
enum Main {
    static func main() {
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "--render-onboarding"), i + 1 < CommandLine.arguments.count {
            OnboardingSnapshot.run(dir: CommandLine.arguments[i + 1]); return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--render-snapshots"), i + 1 < CommandLine.arguments.count {
            Snapshot.run(dir: CommandLine.arguments[i + 1]); return
        }
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
