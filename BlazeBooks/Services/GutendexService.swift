import Foundation

@MainActor
@Observable
final class GutendexService {
    var isLoading = false
    var error: String?

    private var cache: [String: CachedResponse] = [:]
    private let baseURL = "https://gutendex.com/books/"
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    /// Dedicated URLSession with 30-second request timeout instead of the default 60s.
    /// Prevents indefinite waits when the Gutendex API is slow or unresponsive.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private struct CachedResponse {
        let response: GutendexResponse
        let timestamp: Date
    }

    func fetchBooks(topic: String, page: Int = 1) async -> GutendexResponse? {
        let cacheKey = "\(topic)-\(page)"

        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.response
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard var components = URLComponents(string: baseURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "topic", value: topic),
            URLQueryItem(name: "languages", value: "en"),
            URLQueryItem(name: "page", value: String(page)),
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(GutendexResponse.self, from: data)
            cache[cacheKey] = CachedResponse(response: response, timestamp: Date())
            return response
        } catch is CancellationError {
            // SwiftUI .task cancelled during navigation transition -- not a real error
            return nil
        } catch {
            self.error = "Could not load books. Check your connection."
            return nil
        }
    }

    func fetchNextPage(from nextURL: String) async -> GutendexResponse? {
        if let cached = cache[nextURL],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.response
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: nextURL) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(GutendexResponse.self, from: data)
            cache[nextURL] = CachedResponse(response: response, timestamp: Date())
            return response
        } catch is CancellationError {
            // SwiftUI .task cancelled during navigation transition -- not a real error
            return nil
        } catch {
            self.error = "Could not load books. Check your connection."
            return nil
        }
    }
}
