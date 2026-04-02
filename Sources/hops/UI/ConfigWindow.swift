import SwiftUI
import HopsCore

struct ConfigWindow: View {
    @State private var config = HopsConfig()
    @State private var editingHandler: HandlerConfig?
    @State private var isAddingHandler = false
    @State private var showSaveConfirmation = false
    @State private var chromeProfiles: [ChromeProfile.ProfileInfo] = []
    @State private var updateStatus: String?
    @State private var isCheckingUpdate = false
    @State private var testURL: String = ""

    var isChrome: Bool {
        config.defaultBrowser.app.localizedCaseInsensitiveContains("Google Chrome")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("hops")
                .font(.largeTitle.bold())

            DefaultBrowserStatus()

            HStack {
                Button("Check for Updates") {
                    checkForUpdate()
                }
                .disabled(isCheckingUpdate)
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let updateStatus {
                    Text(updateStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            GroupBox("Default Browser") {
                VStack(alignment: .leading) {
                    HStack {
                        TextField("App", text: $config.defaultBrowser.app)
                        Button("Browse...") { browseDefaultApp() }
                    }
                    if isChrome {
                        Picker("Profile", selection: $config.defaultBrowser.profile) {
                            Text("None").tag("")
                            ForEach(chromeProfiles, id: \.directory) { p in
                                Text(p.displayName).tag(p.displayName)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox {
                VStack(alignment: .leading) {
                    Text("Handlers")
                        .font(.headline)
                    Text("First match wins. Drag to reorder.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    List {
                        ForEach($config.handlers) { $handler in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(handler.summary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    editingHandler = handler
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    config.handlers.removeAll { $0.id == handler.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                        .onMove { indices, newOffset in
                            config.handlers.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .frame(minHeight: 120)

                    HStack {
                        Spacer()
                        Button("Add Handler") {
                            isAddingHandler = true
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Test URL") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Paste a URL to see where it routes", text: $testURL)
                        .textFieldStyle(.roundedBorder)
                    if let url = URL(string: testURL), !testURL.isEmpty {
                        let routeResult = config.route(url)
                        let matchedHandler = config.handlers.first { $0.matchesURL(url) }
                        HStack {
                            Image(systemName: matchedHandler != nil
                                ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .foregroundColor(matchedHandler != nil ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(routeResult.app.isEmpty ? "(no app)" : routeResult.app)
                                    .fontWeight(.medium)
                                if !routeResult.profile.isEmpty {
                                    Text("Profile: \(routeResult.profile)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(matchedHandler != nil
                                    ? "Matched: \(matchedHandler!.summary)"
                                    : "No handler matched — using default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("Save") { saveConfig() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 550)
        .frame(minHeight: 500)
        .onAppear { loadConfig() }
        .sheet(item: $editingHandler) { handler in
            let binding = Binding<HandlerConfig>(
                get: { config.handlers.first { $0.id == handler.id } ?? handler },
                set: { updated in
                    if let idx = config.handlers.firstIndex(where: { $0.id == handler.id }) {
                        config.handlers[idx] = updated
                    }
                }
            )
            HandlerEditor(handler: binding)
        }
        .sheet(isPresented: $isAddingHandler) {
            AddHandlerSheet(onSave: { created in
                config.handlers.append(created)
            })
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Configuration saved to ~/.hops.toml")
        }
    }

    private func loadConfig() {
        let path = HopsConfig.configFilePath()
        if FileManager.default.fileExists(atPath: path) {
            config = (try? HopsConfig.parseFile(path)) ?? HopsConfig()
        }
        chromeProfiles = (try? ChromeProfile.listProfiles()) ?? []
    }

    private func saveConfig() {
        let path = HopsConfig.configFilePath()
        let content = config.serialize()
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        showSaveConfirmation = true
    }

    private func browseDefaultApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            config.defaultBrowser.app = url.path
        }
    }

    private func checkForUpdate() {
        isCheckingUpdate = true
        updateStatus = "Checking..."
        Task {
            let currentVersion = Updater.currentAppVersion()
            guard let update = await Updater.checkForUpdate(currentVersion: currentVersion) else {
                updateStatus = "Up to date"
                isCheckingUpdate = false
                return
            }
            updateStatus = "Downloading version \(update.version)..."
            do {
                try await AppDelegate.downloadAndInstall(update)
            } catch {
                updateStatus = "Update failed: \(error.localizedDescription)"
                isCheckingUpdate = false
            }
        }
    }
}

/// Wrapper view that owns the new handler state so the binding works correctly.
/// The HandlerEditor writes all fields to the binding before dismissing, so we
/// check on disappear whether any matcher was populated (save vs cancel).
private struct AddHandlerSheet: View {
    let onSave: (HandlerConfig) -> Void
    @State private var handler = HandlerConfig()

    var body: some View {
        HandlerEditor(handler: $handler)
            .onDisappear {
                let hasContent = !handler.match.isEmpty || !handler.hostnames.isEmpty
                    || !handler.hostnameRegexps.isEmpty || !handler.queryParams.isEmpty
                if hasContent && !handler.app.isEmpty {
                    onSave(handler)
                }
            }
    }
}
