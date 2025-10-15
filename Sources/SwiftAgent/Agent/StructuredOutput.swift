// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// Describes a named, schema-driven value that a provider can generate directly.
///
/// A type conforming to `StructuredOutput` declares a `Schema` describing the
/// structure of the generated value and a `name` that is used to identify the
/// output in transcripts and decoding.
///
/// Usage with `@StructuredOutput` on a session type exposes a fluent API to
/// generate this value from prompts.
///
/// ## Example
///
/// ```swift
/// struct GreetingReport: StructuredOutput {
///   static let name = "greeting"
///
///   @Generable
///   struct Schema {
///     let message: String
///   }
/// }
///
/// @LanguageModelProvider(.openAI)
/// final class Session {
///   @StructuredOutput(GreetingReport.self) var greeting
/// }
///
/// // Later:
/// let session = Session(...)
/// let response = try await session.greeting.generate(from: "Say hello")
/// let report = try response.value // GreetingReport.Schema
/// ```
public protocol StructuredOutput<Schema>: Sendable {
  /// The schema that the model should produce for this output.
  associatedtype Schema: Generable

  /// A short, stable identifier for the output used in transcripts.
  static var name: String { get }
}

extension String: StructuredOutput {
  /// The schema is the string itself, enabling plain text generation
  /// through the same structured output pipeline.
  public typealias Schema = Self

  /// Human‑readable, stable name for transcript tagging and decoding.
  public static var name: String { "String" }
}
