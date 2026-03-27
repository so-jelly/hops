import Cocoa
import HopsCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var receivedURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }
        receivedURL = true
        routeURL(urlString)
    }

    private func routeURL(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [rawURL]
            try? process.run()
            NSApp.terminate(nil)
            return
        }

        let configPath = HopsConfig.configFilePath()
        guard let config = try? HopsConfig.parseFile(configPath) else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [rawURL]
            try? process.run()
            NSApp.terminate(nil)
            return
        }

        let target = config.route(url)
        let cleanedURL = URLCleaner.clean(rawURL)
        Launcher.launch(target: target, cleanedURL: cleanedURL)
        NSApp.terminate(nil)
    }
}
