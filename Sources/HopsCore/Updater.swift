import Foundation

public enum Updater {
    public struct UpdateInfo {
        public let version: Int
        public let downloadURL: URL
    }

    static let releaseURL = URL(string: "https://api.github.com/repos/so-jelly/hops/releases/latest")!

    /// Parse the GitHub latest-release JSON response. Returns UpdateInfo if the
    /// remote version is strictly greater than currentVersion, nil otherwise.
    public static func parseLatestRelease(json: Data, currentVersion: Int) -> UpdateInfo? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let tagName = root["tag_name"] as? String,
              let remoteVersion = Int(tagName),
              remoteVersion > currentVersion,
              let assets = root["assets"] as? [[String: Any]],
              let zipAsset = assets.first(where: {
                  ($0["browser_download_url"] as? String)?.hasSuffix(".zip") == true
              }),
              let urlString = zipAsset["browser_download_url"] as? String,
              let downloadURL = URL(string: urlString) else {
            return nil
        }
        return UpdateInfo(version: remoteVersion, downloadURL: downloadURL)
    }

    /// Fetch the latest release info from GitHub. Returns nil on any failure.
    public static func checkForUpdate(currentVersion: Int) async -> UpdateInfo? {
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        return parseLatestRelease(json: data, currentVersion: currentVersion)
    }

    /// Read the app's CFBundleVersion as an integer. Returns 0 if unreadable.
    public static func currentAppVersion() -> Int {
        guard let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return 0
        }
        return Int(versionString) ?? 0
    }
}
