// By Dennis Müller

import Foundation

/// Represents metadata for a URL link that can be included in prompt context.
///
/// `PromptContextLinkPreview` encapsulates information about URLs found in user input,
/// including the original URL, any final redirect destination, and extracted title metadata.
/// This data is automatically processed by ``ModelSession`` when URLs are detected in
/// conversations and can be included in AI prompts to provide additional context.
///
/// ## Integration with Prompts
///
/// When converted to prompt representation, link previews generate structured XML-like
/// tags that provide the AI with rich context about referenced URLs:
///
/// ```xml
/// <link-preview url="https://example.com/article" title="Article Title" />
/// ```
///
/// Multiple link previews are automatically wrapped in a container:
///
/// ```xml
/// <link-previews>
///   <link-preview url="https://example.com/article-1" title="First Article" />
///   <link-preview url="https://example.com/article-2" title="Second Article" />
/// </link-previews>
/// ```
public struct PromptContextLinkPreview: Sendable, Equatable {
  /// The original URL from user input before any redirects.
  ///
  /// This preserves the URL as it appeared in the original user message, which may
  /// be a shortened URL, redirect link, or the actual destination URL.
  public var originalURL: URL

  /// The final URL after following redirects.
  ///
  /// This contains the ultimate destination URL after the framework has resolved
  /// any redirects. In cases where no redirects occur, this will be identical
  /// to ``originalURL``.
  public var url: URL

  /// The title of the linked content.
  ///
  /// This optional property contains the extracted title from the linked webpage's
  /// metadata (typically from the HTML `<title>` tag or Open Graph `og:title`).
  /// May be `nil` if the title could not be extracted or the URL is inaccessible.
  public var title: String?

  /// Creates a new link preview with the specified URL information and optional title.
  ///
  /// - Parameter originalURL: The URL as it appeared in the original user input
  /// - Parameter url: The final URL after resolving any redirects
  /// - Parameter title: The extracted title of the linked content, if available
  public init(originalURL: URL, url: URL, title: String? = nil) {
    self.originalURL = originalURL
    self.url = url
    self.title = title
  }
}

/// Conformance to `PromptRepresentable` for individual link previews.
///
/// This extension enables ``PromptContextLinkPreview`` objects to be directly included
/// in ``Prompt`` structures. The link preview is rendered as a self-closing XML-like tag
/// with attributes containing the URL metadata.
///
/// ## Generated Output Format
///
/// The prompt representation generates a `<link-preview>` tag with the following attributes:
/// - `url`: The final destination URL (always included)
/// - `original_url`: The original input URL (included only when different from `url`)
/// - `title`: The extracted page title (included only when available)
///
/// Example output for a redirected URL with title:
/// ```xml
/// <link-preview url="https://example.com/article"
///               original_url="https://short.ly/abc123"
///               title="Article Title" />
/// ```
///
/// Example output for a direct URL without title:
/// ```xml
/// <link-preview url="https://example.com/direct-link" />
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension PromptContextLinkPreview: PromptRepresentable {
  /// Converts the link preview into a structured prompt representation.
  ///
  /// Creates a `<link-preview>` tag with attributes for the URL information and title.
  /// The `original_url` attribute is only included when the original URL differs from
  /// the final URL due to redirects. The `title` attribute is only included when
  /// title metadata is available.
  ///
  /// - Returns: A ``Prompt`` containing a single `<link-preview>` tag with appropriate attributes.
  public var promptRepresentation: Prompt {
    var attributes: [String: String] = [
      "url": url.absoluteString,
    ]

    if originalURL != url {
      attributes["original_url"] = originalURL.absoluteString
    }

    if let title = title {
      attributes["title"] = title
    }

    return Prompt {
      PromptTag("link-preview", attributes: attributes)
    }
  }
}

/// Conformance to `PromptRepresentable` for collections of link previews.
///
/// This extension allows arrays of ``PromptContextLinkPreview`` objects to be directly
/// included in ``Prompt`` structures. Multiple link previews are automatically wrapped
/// in a `<link-previews>` container element for better organization in the prompt.
///
/// ## Generated Output Format
///
/// Empty arrays produce no output (``Prompt/empty``), while non-empty arrays generate
/// a `<link-previews>` container with individual `<link-preview>` elements:
///
/// ```xml
/// <link-previews>
///   <link-preview url="https://example.com/article-1" title="First Article" />
///   <link-preview url="https://example.com/article-2" title="Second Article" />
///   <link-preview url="https://example.com/article-3" original_url="https://short.ly/xyz"
///                 title="Third Article" />
/// </link-previews>
/// ```
@available(iOS 26.0, macOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Array: PromptRepresentable where Element == PromptContextLinkPreview {
  /// Converts a collection of link previews into a structured prompt representation.
  ///
  /// Creates a `<link-previews>` container element containing individual `<link-preview>`
  /// tags for each element in the array. Empty arrays return ``Prompt/empty`` to avoid
  /// generating unnecessary markup.
  ///
  /// - Returns: A ``Prompt`` containing a `<link-previews>` wrapper with nested
  ///   `<link-preview>` elements, or ``Prompt/empty`` if the array is empty.
  public var promptRepresentation: Prompt {
    guard !isEmpty else {
      return Prompt.empty
    }

    return Prompt {
      PromptTag("link-previews") {
        for linkPreview in self {
          linkPreview
        }
      }
    }
  }
}
