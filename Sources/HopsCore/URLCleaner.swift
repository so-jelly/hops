import Foundation

public enum URLCleaner {
    private static let trackingPrefixes = ["utm_", "uta_"]
    private static let trackingExact: Set<String> = ["fbclid", "gclid"]

    public static func clean(_ rawURL: String) -> String {
        guard var components = URLComponents(string: rawURL),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return rawURL
        }

        let filtered = queryItems.filter { item in
            if trackingExact.contains(item.name) { return false }
            for prefix in trackingPrefixes {
                if item.name.hasPrefix(prefix) { return false }
            }
            return true
        }

        if filtered.count == queryItems.count {
            return rawURL
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? rawURL
    }
}
