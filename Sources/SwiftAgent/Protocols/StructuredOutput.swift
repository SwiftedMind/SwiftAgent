// By Dennis Müller

import Foundation
import FoundationModels

/// Names a schema SwiftAgent can generate directly as a typed value.
///
/// Conforming types declare a `Schema` using FoundationModels' `@Generable` macro and expose a
/// stable `name` used to tag transcript segments. Add the type to a `@SessionSchema` type with
/// `@StructuredOutput` to request the value, stream partial updates, and access decoded results.
///
/// ```swift
/// struct WeatherReport: StructuredOutput {
///   static let name = "weather_report"
///
///   @Generable
///   struct Schema {
///     let condition: String
///     let temperature: Double
///   }
/// }
///
/// @SessionSchema
/// struct SessionSchema {
///   @StructuredOutput(WeatherReport.self) var weatherReport
/// }
///
/// let session = OpenAISession(schema: SessionSchema(), instructions: "You are a helpful assistant.", apiKey: "sk-...")
/// let report = try await session.respond(to: "Weather in Lisbon?", generating: \.weatherReport).content
/// ```
public protocol StructuredOutput<Schema>: Sendable {
  /// The schema that the model should produce for this output.
  associatedtype Schema: Generable

  /// A stable identifier for the output used in transcripts.
  static var name: String { get }
}

extension String: StructuredOutput {
  /// The schema is the string itself, enabling plain text generation
  /// through the same structured output pipeline.
  public typealias Schema = Self

  /// A stable name for transcript tagging and decoding.
  public static var name: String { "String" }
}
