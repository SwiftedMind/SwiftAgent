// By Dennis Müller

import Foundation
import FoundationModels

/// Describes how a schema-defined structured output is decoded from transcript snapshots.
///
/// Conforming types are synthesized by ``SessionSchema`` macros when you annotate properties with
/// `@StructuredOutput`. They bridge the raw `StructuredOutputSnapshot<Base>` emitted during
/// streaming into the schema-specific `DecodedStructuredOutput` that powers decoded transcripts,
/// live snapshots, and tooling.
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
///   @StructuredOutput(WeatherReport.self) var weather
/// }
///
/// // The macro above generates a type conforming to DecodableStructuredOutput that
/// // knows how to turn WeatherReport snapshots into schema-backed decoded values.
/// ```
///
/// - Note: Most applications never implement this protocol manually; rely on the generated types instead.
public protocol DecodableStructuredOutput<DecodedStructuredOutput>: Sendable, Equatable {
  /// The user‑declared output type that defines the `Schema` to generate.
  associatedtype Base: StructuredOutput
  /// Concrete decoded output returned to schema consumers.
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
