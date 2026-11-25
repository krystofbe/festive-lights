import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "ms.blckbox.FestiveLights")
            .filter { $0.processIdentifier != me }
        if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("ms.blckbox.FestiveLights.showSettings"), object: nil, deliverImmediately: true)
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
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
