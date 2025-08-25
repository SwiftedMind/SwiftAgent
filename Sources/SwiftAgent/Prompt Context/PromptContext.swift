// By Dennis Müller

import Foundation

/// A container for contextual data that can be injected into AI prompts.
///
/// ``PromptContext`` combines custom context sources with automatically extracted link previews
/// to provide rich contextual information to AI models. This enables sophisticated RAG
/// (Retrieval-Augmented Generation) patterns and context-aware AI interactions.
///
/// The generic `Source` parameter allows you to define application-specific context types
/// that implement ``PromptContextSource``, while link previews are automatically extracted
/// from URLs found in user input.
///
/// ## Integration with ModelSession
///
/// ``PromptContext`` is automatically created and passed to your prompt builders when using
/// context-aware response methods in ``ModelSession``. The ModelSession's context type is fixed
/// at initialization, so use enum-based context sources for maximum flexibility.
///
/// ### Creating a Context-Aware ModelSession
///
/// First, define your context source and create a ModelSession with the context type:
///
/// ```swift
/// // Define a comprehensive context source that can represent different data types
/// enum AppContext: PromptContextSource {
///   case document(title: String, content: String, metadata: [String: String])
///   case userProfile(name: String, preferences: [String])
///   case searchResults([String])
/// }
///
/// // Create a ModelSession with enum-based context
/// let session = ModelSession.openAI(
///   tools: [WeatherTool()],
///   instructions: "You are a helpful assistant",
///   context: AppContext.self,
///   apiKey: "your-api-key"
/// )
///
/// // Use context in a ModelSession response
/// let contextSources: [AppContext] = [
///   .document(title: "Report", content: "...", metadata: [:]),
///   .userProfile(name: "Alice", preferences: ["tech", "science"])
/// ]
///
/// let response = try await session.respond(
///   to: "Summarize this document for me",
///   supplying: contextSources,
///   embeddingInto: { input, context in
///     Prompt {
///       "User input: \(input)"
///
///       // Context sources are available here
///       if !context.sources.isEmpty {
///         "Available context:"
///         for source in context.sources {
///           switch source {
///           case .document(let title, let content, _):
///             "- Document: \(title) - \(content.prefix(100))..."
///           case .userProfile(let name, let preferences):
///             "- User: \(name) with interests in \(preferences.joined(separator: ", "))"
///           case .searchResults(let results):
///             "- Search Results: \(results.joined(separator: "; "))"
///           }
///         }
///       }
///
///       // Link previews are automatically included
///       context.linkPreviews
///     }
///   }
/// )
/// ```
///
/// ## Context Sources and Link Previews
///
/// The context combines two types of information:
/// - **Sources**: Custom data structures you provide that implement ``PromptContextSource``
/// - **Link Previews**: Automatically extracted metadata from URLs in user input
///
/// Both are made available to your prompt building closures, allowing you to create
/// sophisticated context-aware prompts that combine application data with web content.
public struct PromptContext<Source>: Sendable, Equatable where Source: PromptContextSource {
  /// Creates a new prompt context with the specified sources and link previews.
  ///
  /// This initializer is typically called automatically by ``ModelSession`` when you use
  /// context-aware response methods, combining your provided context sources with any
  /// link previews extracted from the user's input.
  ///
  /// - Parameter sources: An array of custom context sources that implement ``PromptContextSource``
  /// - Parameter linkPreviews: An array of ``PromptContextLinkPreview`` objects containing
  ///   metadata for URLs found in the user's input
  public init(sources: [Source], linkPreviews: [PromptContextLinkPreview]) {
    self.sources = sources
    self.linkPreviews = linkPreviews
  }

  /// A context with no sources or link previews.
  ///
  /// This property provides a convenient way to create an empty context when no contextual
  /// data is available. It's equivalent to calling `PromptContext(sources: [], linkPreviews: [])`.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let emptyContext = PromptContext<MyContextSource>.empty
  /// // equivalent to: PromptContext<MyContextSource>(sources: [], linkPreviews: [])
  /// ```
  public static var empty: Self {
    Self(sources: [], linkPreviews: [])
  }

  /// The custom context sources provided for this interaction.
  ///
  /// This array contains your application-specific context data that implements
  /// ``PromptContextSource``. Sources might include user data, document content,
  /// search results, or any other contextual information relevant to the AI interaction.
  ///
  /// The sources are made available to your prompt building closures, allowing you to
  /// dynamically include relevant context in your prompts based on the specific
  /// sources provided for each interaction.
  public var sources: [Source] = []

  /// Automatically extracted link preview metadata from URLs in user input.
  ///
  /// This array contains ``PromptContextLinkPreview`` objects that represent metadata
  /// extracted from any URLs found in the user's input message. The extraction happens
  /// automatically in ``ModelSession`` before your prompt building closure is called.
  ///
  /// Link previews include information such as:
  /// - Original and final URLs (after redirect resolution)
  /// - Extracted page titles
  /// - Structured XML representation for inclusion in prompts
  ///
  /// When included in prompts, link previews provide the AI with rich context about
  /// referenced web content without requiring manual URL processing.
  public var linkPreviews: [PromptContextLinkPreview] = []
}

/// A protocol for types that can serve as context sources in AI prompts.
///
/// Implement this protocol to create custom context types that can be injected into
/// AI prompts through ``PromptContext``. Context sources represent application-specific
/// data that should be made available to AI models during generation.
///
/// ## Choosing Your Context Architecture
///
/// **Enum-based contexts are recommended** for most applications because they provide
/// flexibility to represent different types of contextual data within a single type system.
/// Since ModelSession's context type is fixed at initialization, enums allow you to:
/// - Mix different kinds of context data in the same interaction
/// - Evolve your context structure as your app grows
/// - Maintain type safety while supporting diverse data sources
///
/// **Struct-based contexts** work well for specialized use cases where you only need
/// one type of contextual data throughout your application's lifecycle.
///
/// ## Implementation Examples
///
/// ### Simple Data Context
/// ```swift
/// struct UserProfile: PromptContextSource {
///   let name: String
///   let preferences: [String]
///   let role: String
/// }
/// ```
///
/// ### Rich Content Context with PromptRepresentable
/// ```swift
/// struct DocumentContext: PromptContextSource, PromptRepresentable {
///   let title: String
///   let content: String
///   let tags: [String]
///
///   var promptRepresentation: Prompt {
///     Prompt {
///       PromptTag("document", attributes: ["title": title]) {
///         "Content: \(content)"
///         if !tags.isEmpty {
///           "Tags: \(tags.joined(separator: ", "))"
///         }
///       }
///     }
///   }
/// }
/// ```
///
/// ### Comprehensive Context with Multiple Types (Recommended)
/// ```swift
/// enum AppContext: PromptContextSource {
///   case userProfile(name: String, preferences: [String], role: String)
///   case document(title: String, content: String, tags: [String])
///   case searchResults([String])
///   case webResults([(title: String, url: URL, snippet: String)])
///   case knowledgeBase([String: String])
/// }
/// ```
///
/// ### Search Results Context (Single Purpose)
/// ```swift
/// enum SearchContext: PromptContextSource {
///   case vectorResults([String])
///   case webResults([(title: String, url: URL, snippet: String)])
///   case knowledgeBase([String: String])
/// }
/// ```
///
/// ## Usage in ModelSession
///
/// Context sources are provided when calling context-aware response methods. The ModelSession's
/// context type is fixed at initialization, so all sources must be of the same type. Use enums
/// to represent different kinds of context data in a single type:
///
/// ### Enum-Based Context (Recommended for Flexibility)
/// ```swift
/// enum AppContext: PromptContextSource {
///   case userProfile(name: String, preferences: [String], role: String)
///   case document(title: String, content: String, tags: [String])
///   case searchResults([String])
/// }
///
/// // Create session with enum-based context type
/// let session = ModelSession.openAI(
///   tools: [WeatherTool()],
///   instructions: "You are a helpful assistant",
///   context: AppContext.self,
///   apiKey: "your-api-key"
/// )
///
/// let contextSources: [AppContext] = [
///   .userProfile(name: "Alice", preferences: ["tech", "science"], role: "admin"),
///   .document(title: "User Guide", content: "...", tags: ["help"]),
///   .searchResults(["related info", "more context"])
/// ]
///
/// let response = try await session.respond(
///   to: "Help me with the user guide",
///   supplying: contextSources,
///   embeddingInto: { input, context in
///     "User: \(input)"
///     "Available context:"
///     for source in context.sources {
///       switch source {
///       case .userProfile(let name, let preferences, let role):
///         "User: \(name) (\(role)) - Interests: \(preferences.joined(separator: ", "))"
///       case .document(let title, let content, let tags):
///         "Document: \(title) - \(content.prefix(100))... Tags: \(tags.joined(separator: ", "))"
///       case .searchResults(let results):
///         "Search Results: \(results.joined(separator: "; "))"
///       }
///     }
///   }
/// )
/// ```
///
/// ### Single-Type Context (For Focused Use Cases)
/// ```swift
/// struct DocumentContext: PromptContextSource {
///   let title: String
///   let content: String
///   let tags: [String]
/// }
///
/// // Create session with struct-based context type
/// let session = ModelSession.openAI(
///   tools: [],
///   instructions: "You are a documentation assistant",
///   context: DocumentContext.self,
///   apiKey: "your-api-key"
/// )
///
/// let documentSources = [
///   DocumentContext(title: "Guide 1", content: "...", tags: ["help"]),
///   DocumentContext(title: "Guide 2", content: "...", tags: ["tutorial"])
/// ]
///
/// let response = try await session.respond(
///   to: "Help me with documentation",
///   supplying: documentSources,
///   embeddingInto: { input, context in
///     "User: \(input)"
///     "Available documents:"
///     for document in context.sources {
///       "- \(document.title): \(document.content.prefix(100))..."
///     }
///   }
/// )
/// ```
public protocol PromptContextSource: Sendable, Equatable {}

/// A placeholder context source for sessions that don't require contextual data.
///
/// `NoContext` serves as a default context type when your ``ModelSession`` doesn't need
/// to inject any contextual information into prompts. It implements ``PromptContextSource``
/// with minimal overhead, allowing you to use context-aware APIs without providing
/// actual context data.
public struct NoContext: PromptContextSource {}
