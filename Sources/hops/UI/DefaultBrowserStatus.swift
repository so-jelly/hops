import SwiftUI
import CoreServices

struct DefaultBrowserStatus: View {
    @State private var isDefault = false

    var body: some View {
        HStack {
            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("hops is your default browser")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("hops is not your default browser")
                Spacer()
                Button("Set Default Browser") {
                    openDesktopDockSettings()
                }
            }
            Spacer()
        }
        .padding()
        .background(.quaternary)
        .cornerRadius(8)
        .onAppear { checkDefault() }
    }

    private func checkDefault() {
        if let handler = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() {
            isDefault = (handler as String) == "dev.hops.app"
        }
    }

    private func openDesktopDockSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
