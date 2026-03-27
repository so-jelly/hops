import SwiftUI
import HopsCore

struct HandlerEditor: View {
    @Binding var handler: HandlerConfig
    @Environment(\.dismiss) private var dismiss

    @State private var matchText: String = ""
    @State private var hostnamesText: String = ""
    @State private var regexpsText: String = ""
    @State private var app: String = ""
    @State private var profile: String = ""
    @State private var chromeProfiles: [ChromeProfile.ProfileInfo] = []

    var isChrome: Bool {
        app.localizedCaseInsensitiveContains("Google Chrome")
    }

    var body: some View {
        Form {
            Section("URL Patterns") {
                TextField("Glob patterns (comma-separated)", text: $matchText, axis: .vertical)
                    .lineLimit(3)
                TextField("Hostnames (comma-separated)", text: $hostnamesText)
                TextField("Hostname regexps (comma-separated)", text: $regexpsText)
            }

            Section("Target Application") {
                HStack {
                    TextField("App", text: $app)
                    Button("Browse...") { browseForApp() }
                }
                if isChrome {
                    Picker("Profile", selection: $profile) {
                        Text("None").tag("")
                        ForEach(chromeProfiles, id: \.directory) { p in
                            Text(p.displayName).tag(p.displayName)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(app.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 450)
        .onAppear { loadFromHandler() }
    }

    private func loadFromHandler() {
        matchText = handler.match.joined(separator: ", ")
        hostnamesText = handler.hostnames.joined(separator: ", ")
        regexpsText = handler.hostnameRegexps.joined(separator: ", ")
        app = handler.app
        profile = handler.profile
        chromeProfiles = (try? ChromeProfile.listProfiles()) ?? []
    }

    private func save() {
        handler.match = splitComma(matchText)
        handler.hostnames = splitComma(hostnamesText)
        handler.hostnameRegexps = splitComma(regexpsText)
        handler.app = app
        handler.profile = isChrome ? profile : ""
        dismiss()
    }

    private func splitComma(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            app = url.path
        }
    }
}
