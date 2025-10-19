// By Dennis Müller

import Foundation
import FoundationModels

/// Captures a single streamed update for a structured output while the agent responds.
///
/// Providers deliver partial payloads as tokens arrive, then swap in the final schema once
/// validation succeeds. Each snapshot bundles the raw `GeneratedContent` with SwiftAgent's typed
/// interpretation so your UI or logging layer can react immediately without juggling enums or manual
/// decoding.
///
/// Reach for `currentContent` when you want a UI-stable projection that always exposes the
/// `PartiallyGenerated` representation, and check `finalContent` once the provider confirms the final
/// schema. `contentPhase` mirrors these states for callers that prefer to switch on enum cases.
///
/// ## Example
///
/// ```swift
/// struct WeatherReport: StructuredOutput {
///   static let name = "weatherReport"
///
///   @Generable
///   struct Schema {
///     let condition: String
///     let temperature: Double
///   }
/// }
///
/// let session = OpenAISession(instructions: "You are a helpful assistant.")
/// for try await snapshot in session.streamResponse(to: "Weather in Lisbon?", generating: WeatherReport.self) {
///   if let current = snapshot.currentContent {
///     WeatherView(content: current.content)
///   }
///
///   if let final = snapshot.finalContent {
///     persist(final)
///   }
/// }
/// ```
public struct StructuredOutputSnapshot<Output: StructuredOutput>: Identifiable {
  /// Represents the typed content carried by an update.
  public enum ContentPhase {
    /// Partially generated value that may still receive additional tokens.
    case partial(Output.Schema.PartiallyGenerated)

    /// Fully generated value that passed validation for the requested schema.
    case final(Output.Schema)
  }

  /// Stable projection that always surfaces the partially generated schema.
  ///
  /// `CurrentContent` always exposes the partially generated shape of the arguments, even when
  /// the underlying value is final. That keeps SwiftUI identity steady from the first token to the
  /// last, while the `isFinal` flag tells you when the agent finished deciding on its inputs.
  @dynamicMemberLookup
  public struct CurrentContent {
    /// Whether this current content represents the final value.
    public var isFinal: Bool

    /// The partially generated representation of the content.
    public var content: Output.Schema.PartiallyGenerated

    init(isFinal: Bool, content: Output.Schema.PartiallyGenerated) {
      self.isFinal = isFinal
      self.content = content
    }

    /// Provides convenient access to fields of the partially generated content.
    public subscript<Value>(dynamicMember keyPath: KeyPath<Output.Schema.PartiallyGenerated, Value>) -> Value {
      content[keyPath: keyPath]
    }
  }

  /// Stable identifier used to correlate snapshots in the same generation.
  public var id: String

  /// The raw provider payload from which the structured content was decoded.
  public var rawContent: GeneratedContent

  /// The current phase of the content (partial or final).
  ///
  /// - `nil`: Arguments failed to decode or are not available
  /// - `.partial`: Arguments are being streamed and may be incomplete
  /// - `.final`: Arguments are complete and validated
  public var contentPhase: ContentPhase?

  /// UI-stable projection of the snapshot content.
  public var currentContent: CurrentContent?

  /// Fully validated schema returned once the provider finalizes the output.
  public var finalContent: Output.Schema?

  /// Error payload when the snapshot represents a provider-reported failure.
  public var error: GeneratedContent?

  /// Creates a snapshot backed by decoded content.
  public init(id: String, contentPhase: ContentPhase, rawContent: GeneratedContent) {
    self.id = id
    self.contentPhase = contentPhase
    self.rawContent = rawContent
    currentContent = Self.makeCurrentContent(from: contentPhase, raw: rawContent)

    switch contentPhase {
    case let .final(final):
      finalContent = final
    default:
      break
    }
  }

  /// Creates a snapshot that represents a provider-reported error payload.
  public init(id: String, error: GeneratedContent, rawContent: GeneratedContent) {
    self.id = id
    self.error = error
    self.rawContent = rawContent
  }

  /// Builds a partial snapshot from the provider's JSON payload.
  public static func partial(id: String, json: String) throws -> StructuredOutputSnapshot<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema.PartiallyGenerated(rawContent)
    return StructuredOutputSnapshot(id: id, contentPhase: .partial(content), rawContent: rawContent)
  }

  /// Builds a final snapshot from the provider's JSON payload.
  public static func final(id: String, json: String) throws -> StructuredOutputSnapshot<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema(rawContent)
    return StructuredOutputSnapshot(id: id, contentPhase: .final(content), rawContent: rawContent)
  }

  /// Builds an error snapshot from the provider's JSON payload.
  public static func error(id: String, error: GeneratedContent) throws -> StructuredOutputSnapshot<Output> {
    StructuredOutputSnapshot(id: id, error: error, rawContent: error)
  }
}

private extension StructuredOutputSnapshot {
  /// Produces the `CurrentContent` projection for a given phase.
  static func makeCurrentContent(from content: ContentPhase, raw: GeneratedContent) -> CurrentContent? {
    switch content {
    case let .partial(content):
      CurrentContent(isFinal: false, content: content)
    case let .final(content):
      CurrentContent(isFinal: true, content: content.asPartiallyGenerated())
    }
  }
}

extension StructuredOutputSnapshot.ContentPhase: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputSnapshot.ContentPhase: Equatable where Output.Schema: Equatable,
  Output.Schema.PartiallyGenerated: Equatable {}
extension StructuredOutputSnapshot: Sendable where Output.Schema: Sendable,
  Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputSnapshot.CurrentContent: Sendable where Output.Schema.PartiallyGenerated: Sendable {}
extension StructuredOutputSnapshot: Equatable {
  public static func == (lhs: StructuredOutputSnapshot<Output>,
                         rhs: StructuredOutputSnapshot<Output>) -> Bool {
    lhs.id == rhs.id && lhs.rawContent == rhs.rawContent
  }
}
