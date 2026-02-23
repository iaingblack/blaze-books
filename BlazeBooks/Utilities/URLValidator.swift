import Foundation

/// Validates URLs against a domain allowlist to prevent SSRF attacks from
/// compromised API responses redirecting downloads to untrusted hosts.
enum URLValidator {
    private static let allowedDomains: Set<String> = [
        "gutendex.com",
        "www.gutenberg.org",
    ]

    /// Returns true if the URL uses HTTPS and its host matches the allowlist.
    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        return allowedDomains.contains(host)
    }

    /// Returns the URL if allowed, or nil if it fails validation.
    static func validated(_ url: URL) -> URL? {
        isAllowed(url) ? url : nil
    }
}
