import Cocoa
import CoreServices
import HopsCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var receivedURL = false
    private var updateTimer: Timer?

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
        NSApp.setActivationPolicy(.accessory)
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

        // Start periodic update checks every 15 minutes
        performUpdateCheck()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.performUpdateCheck()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }

    func performUpdateCheck() {
        Task {
            let currentVersion = Updater.currentAppVersion()
            guard let update = await Updater.checkForUpdate(currentVersion: currentVersion) else {
                return
            }
            await installAndRelaunch(update)
        }
    }

    private func installAndRelaunch(_ update: Updater.UpdateInfo) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hops-update-\(update.version)")

        do {
            // Download the zip
            let (zipURL, _) = try await URLSession.shared.download(from: update.downloadURL)
            let zipDest = tempDir.appendingPathComponent("hops.zip")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: zipDest)
            try FileManager.default.moveItem(at: zipURL, to: zipDest)

            // Unzip
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-o", zipDest.path, "-d", tempDir.path]
            try unzip.run()
            unzip.waitUntilExit()
            guard unzip.terminationStatus == 0 else { return }

            let extractedApp = tempDir.appendingPathComponent("hops.app")
            guard FileManager.default.fileExists(atPath: extractedApp.path) else { return }

            // Replace /Applications/hops.app
            let appDest = URL(fileURLWithPath: "/Applications/hops.app")
            try? FileManager.default.removeItem(at: appDest)
            try FileManager.default.moveItem(at: extractedApp, to: appDest)

            // Cleanup temp
            try? FileManager.default.removeItem(at: tempDir)

            // Relaunch
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            relaunch.arguments = ["/Applications/hops.app"]
            try relaunch.run()

            await MainActor.run {
                NSApp.terminate(nil)
            }
        } catch {
            // Silent failure — app continues as-is
            try? FileManager.default.removeItem(at: tempDir)
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
