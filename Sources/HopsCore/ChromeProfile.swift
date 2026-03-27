import Foundation

public enum ChromeProfile {
    public struct ProfileInfo {
        public let directory: String
        public let displayName: String
    }

    enum ProfileError: LocalizedError {
        case readFailed(String)
        case parseFailed(String)
        case profileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .readFailed(let msg): return "Reading Local State: \(msg)"
            case .parseFailed(let msg): return "Parsing Local State: \(msg)"
            case .profileNotFound(let name): return "Chrome profile \"\(name)\" not found"
            }
        }
    }

    public static func resolveProfileDir(localStatePath: String, displayName: String) throws -> String {
        let profiles = try loadInfoCache(localStatePath: localStatePath)
        guard let entry = profiles.first(where: { $0.value == displayName }) else {
            throw ProfileError.profileNotFound(displayName)
        }
        return entry.key
    }

    public static func listProfiles(localStatePath: String? = nil) throws -> [ProfileInfo] {
        let path = localStatePath ?? defaultLocalStatePath()
        let cache = try loadInfoCache(localStatePath: path)
        return cache.map { ProfileInfo(directory: $0.key, displayName: $0.value) }
    }

    public static func defaultLocalStatePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Google/Chrome/Local State"
    }

    private static func loadInfoCache(localStatePath: String) throws -> [String: String] {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: localStatePath))
        } catch {
            throw ProfileError.readFailed(error.localizedDescription)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: [String: Any]] else {
            throw ProfileError.parseFailed("unexpected JSON structure")
        }

        var result: [String: String] = [:]
        for (dir, info) in infoCache {
            if let name = info["name"] as? String {
                result[dir] = name
            }
        }
        return result
    }
}
