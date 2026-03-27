import Foundation

public enum Launcher {
    public static func launch(target: BrowserTarget, cleanedURL: String) {
        if !target.profile.isEmpty {
            if let profileDir = try? ChromeProfile.resolveProfileDir(
                localStatePath: ChromeProfile.defaultLocalStatePath(),
                displayName: target.profile
            ) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-na", target.app, "--args",
                                     "--profile-directory=\(profileDir)", cleanedURL]
                try? process.run()
                process.waitUntilExit()
            } else {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-a", target.app, cleanedURL]
                try? process.run()
                process.waitUntilExit()
            }
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", target.app, cleanedURL]
            try? process.run()
            process.waitUntilExit()
        }

        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", "tell application \"\(target.app)\" to activate"]
        try? activate.run()
        activate.waitUntilExit()
    }
}
