// By Dennis Müller

import Foundation
import LinkPresentation

/// Utility for fetching metadata from URLs using LPMetadataProvider
@MainActor
package final class URLMetadataProvider {
  /// Metadata information extracted from a URL
  package struct URLMetadata: Sendable, Equatable {
    /// The original URL before any redirects
    package let originalURL: URL
    /// The final URL after following redirects
    package let url: URL
    /// The title of the linked content
    package let title: String?

    package init(originalURL: URL, url: URL, title: String?) {
      self.originalURL = originalURL
      self.url = url
      self.title = title
    }
  }

  package init() {}

  /// Fetches metadata for a single URL
  package func fetchMetadata(for url: URL) async throws -> URLMetadata {
    let provider = LPMetadataProvider()
    let metadata = try await provider.startFetchingMetadata(for: url)
    return URLMetadata(
      originalURL: url,
      url: metadata.originalURL ?? url,
      title: metadata.title,
    )
  }

  /// Fetches metadata for multiple URLs concurrently
  package func fetchMetadata(for urls: [URL]) async -> [URLMetadata] {
    await withTaskGroup(of: URLMetadata?.self) { group in
      for url in urls {
        group.addTask { [weak self] in
          do {
            return try await self?.fetchMetadata(for: url)
          } catch {
            // Return nil for failed requests, we'll filter them out
            return nil
          }
        }
      }

      var results: [URLMetadata] = []
      for await metadata in group {
        if let metadata {
          results.append(metadata)
        }
      }
      return results
    }
  }

  /// Extracts URLs from a text string
  package static func extractURLs(from text: String) -> [URL] {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

    return matches?.compactMap { match in
      guard let range = Range(match.range, in: text),
            let url = URL(string: String(text[range])) else {
        return nil
      }

      return url
    } ?? []
  }
}
