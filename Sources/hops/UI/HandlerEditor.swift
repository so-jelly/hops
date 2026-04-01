import SwiftUI
import HopsCore

struct HandlerEditor: View {
    @Binding var handler: HandlerConfig
    @Environment(\.dismiss) private var dismiss

    @State private var matchEntries: [String] = []
    @State private var hostnameEntries: [String] = []
    @State private var regexpEntries: [String] = []
    @State private var queryParamEntries: [String] = []
    @State private var app: String = ""
    @State private var profile: String = ""
    @State private var chromeProfiles: [ChromeProfile.ProfileInfo] = []

    var isChrome: Bool {
        app.localizedCaseInsensitiveContains("Google Chrome")
    }

    var body: some View {
        Form {
            Section("URL Patterns") {
                EntryList(label: "Glob patterns", placeholder: "*.example.com/*", entries: $matchEntries)
                EntryList(label: "Hostnames", placeholder: "localhost", entries: $hostnameEntries)
                EntryList(label: "Hostname regexps", placeholder: #".*\.local$"#, entries: $regexpEntries)
                EntryList(label: "Query params", placeholder: "project=my-proj*", entries: $queryParamEntries)
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
        .frame(width: 500)
        .onAppear { loadFromHandler() }
    }

    private func loadFromHandler() {
        matchEntries = handler.match
        hostnameEntries = handler.hostnames
        regexpEntries = handler.hostnameRegexps
        queryParamEntries = handler.queryParams
        app = handler.app
        profile = handler.profile
        chromeProfiles = (try? ChromeProfile.listProfiles()) ?? []
    }

    private func save() {
        handler.match = matchEntries.filter { !$0.isEmpty }
        handler.hostnames = hostnameEntries.filter { !$0.isEmpty }
        handler.hostnameRegexps = regexpEntries.filter { !$0.isEmpty }
        handler.queryParams = queryParamEntries.filter { !$0.isEmpty }
        handler.app = app
        handler.profile = isChrome ? profile : ""
        dismiss()
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

/// A list of single-line text fields with add/remove controls.
struct EntryList: View {
    let label: String
    let placeholder: String
    @Binding var entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    entries.append("")
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            ForEach(entries.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    TextField(placeholder, text: $entries[index])
                        .textFieldStyle(.roundedBorder)
                    Button {
                        entries.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
        }
    }
}
