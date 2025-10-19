// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// Allows decoding structured segments from a transcript for a specific provider.
///
/// ## Example
///
/// ```swift
/// struct NoteSummary: StructuredOutput {
///   static let name = "note_summary"
///
///   @Generable
///   struct Schema {
///     let summary: String
///   }
/// }
///
/// @LanguageModelProvider(.openAI)
/// final class Session {
///   // The macro generates a nested decodable representation used internally to
///   // transform `StructuredOutputSnapshot<NoteSummary>` into a provider-specific value.
///   @StructuredOutput(NoteSummary.self) var note
/// }
///
/// ```
///
/// - Note: You usually do not implement this protocol manually. When you declare
/// `@StructuredOutput` properties on a `@LanguageModelProvider` session, the macro
/// generates a concrete type conforming to `DecodableStructuredOutput` that knows how to
/// decode your output from transcript updates.
public protocol DecodableStructuredOutput<DecodedStructuredOutput>: Sendable, Equatable {
  /// The user‑declared output type that defines the `Schema` to generate.
  associatedtype Base: StructuredOutput
  /// The provider for which decoding is performed.
  associatedtype DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput
  /// Stable name under which segments for this output are recorded in transcripts.
  static var name: String { get }
  /// Decode a structured update into the provider's concrete decoded output type.
  static func decode(_ structuredOutput: StructuredOutputSnapshot<Base>) -> DecodedStructuredOutput
}

public extension DecodableStructuredOutput {
  /// Uses the base output's `name` by default.
  static var name: String { Base.name }
}
