import Foundation

/// Fallback artwork source: Apple's public iTunes Search API (no account or key needed).
/// Only the song title, artist and album are sent, and only when Music itself has no artwork.
enum ITunesArtwork {
    private struct Response: Decodable {
        struct Result: Decodable {
            let collectionName: String?
            let artworkUrl100: String?
        }
        let results: [Result]
    }

    static func fetch(for track: Track) async -> Data? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(track.artist) \(track.title)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let searchURL = components.url else { return nil }

        do {
            let (json, _) = try await URLSession.shared.data(from: searchURL)
            let results = try JSONDecoder().decode(Response.self, from: json).results
            // Prefer the result from the same album; otherwise take the best match.
            let match = results.first { $0.collectionName == track.album } ?? results.first
            // The API returns a 100×100 thumbnail URL; the same URL works for larger sizes.
            guard let small = match?.artworkUrl100,
                  let large = URL(string: small.replacingOccurrences(of: "100x100", with: "600x600"))
            else { return nil }
            let (image, _) = try await URLSession.shared.data(from: large)
            return image
        } catch {
            appLog.error("iTunes artwork lookup failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
