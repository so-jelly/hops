import Cocoa
import CoreServices
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if receivedURL { return }

        let configPath = HopsConfig.configFilePath()
        if !FileManager.default.fileExists(atPath: configPath) {
            let defaultConfig = HopsConfig()
            let content = defaultConfig.serialize()
            try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
        }

        if let handler = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() {
            if (handler as String) != "dev.hops.app" {
                showDefaultBrowserPrompt()
            }
        }
    }

    private func showDefaultBrowserPrompt() {
        let alert = NSAlert()
        alert.messageText = "hops isn't your default browser"
        alert.informativeText = "Set hops as your default browser to route URLs automatically."
        alert.addButton(withTitle: "Set Default")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
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
