import SwiftUI
import HopsCore

@main
struct HopsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ConfigWindow()
        }
        .handlesExternalEvents(matching: [])
    }
}
