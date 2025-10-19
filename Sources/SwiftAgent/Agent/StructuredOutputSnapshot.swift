// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// Represents a single update emitted while generating a structured output.
///
/// Updates may be streamed as partial values and completed with a final value.
/// Each update carries the raw provider payload plus a typed interpretation.
///
/// The `currentContent` property provides convenient access to the schema
/// regardless of finality. It always exposes a `PartiallyGenerated` view,
/// making UI development simpler and more predictable by eliminating the need
/// to branch between partial and final content.
///
/// ## Example
///
/// ```swift
/// // 1) Define the structured output
/// struct WeatherReport: StructuredOutput {
///   static let name = "weatherReport"
///   @Generable
///   struct Schema {
///     let temperature: Double
///     let condition: String
///     let humidity: Int
///   }
/// }
///
/// // 2) Define a session using the macro and expose generation via @StructuredOutput
/// @LanguageModelProvider(.openAI)
/// final class Session {
///   @StructuredOutput(WeatherReport.self) var weatherReport
/// }
///
/// // 3) Stream a structured response and pass to SwiftUI view
/// let session = Session()
/// for try await snapshot in session.weatherReport.streamGeneration(
///   from: "Weather for San Francisco",
/// ) {
///   // Pass the current content directly to your SwiftUI view
///   if let content = snapshot.currentContent.content {
///     WeatherView(content: content)
///   }
/// }
/// struct WeatherView: View {
///   let content: WeatherReport.Schema.PartiallyGenerated
///
///   var body: some View {
///     VStack(alignment: .leading, spacing: 12) {
///       if let condition = content.condition {
///         Text(condition)
///           .font(.headline)
///           .contentTransition(.interpolate)
///       }
///
///       HStack {
///         if let temperature = content.temperature {
///           Text("\(temperature, specifier: "%.1f")°C")
///             .contentTransition(.numericText())
///         }
///
///         if let humidity = content.humidity {
///           Text("\(humidity)% humidity")
///             .contentTransition(.numericText())
///         }
///       }
///       .font(.caption)
///       .foregroundStyle(.secondary)
///     }
///     .frame(maxWidth: .infinity, alignment: .leading)
///   }
/// }
/// ```
public struct StructuredOutputSnapshot<Output: StructuredOutput>: Identifiable {
  /// Represents the typed content carried by an update.
  public enum ContentPhase {
    /// A partially generated value that may be followed by further updates.
    case partial(Output.Schema.PartiallyGenerated)

    /// A final, fully generated value.
    case final(Output.Schema)
  }

  /// A current view over update content that always exposes a
  /// `PartiallyGenerated` value plus a flag indicating finality.
  ///
  /// Designed for UI rendering: you always receive the partially generated
  /// representation, keeping your view code stable from the first token to the
  /// last. When the update is final, the value is still converted to
  /// `PartiallyGenerated` so bindings keep working without additional state
  /// switches.
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

  /// Stable identifier used to correlate updates in the same generation.
  public var id: String

  /// The raw provider payload from which the structured content was decoded.
  public var rawContent: GeneratedContent

  /// The typed content for this update, if decoding succeeded.
  public var contentPhase: ContentPhase?

  /// A current view over the content, available when `contentPhase` is present.
  ///
  /// This always contains a `PartiallyGenerated` view of the schema—even when
  /// the underlying update is final. Final values are converted into their
  /// `PartiallyGenerated` form so that UI code (e.g. SwiftUI views) can bind to
  /// a single, stable model without branching on status.
  public var currentContent: CurrentContent?

  public var finalContent: Output.Schema?

  /// Error payload when the update represents a provider-reported failure.
  public var error: GeneratedContent?

  /// Creates an update that carries typed content.
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

  /// Creates an update that represents a provider-reported error.
  public init(id: String, error: GeneratedContent, rawContent: GeneratedContent) {
    self.id = id
    self.error = error
    self.rawContent = rawContent
  }

  /// Decodes a partial update from a JSON string.
  public static func partial(id: String, json: String) throws -> StructuredOutputSnapshot<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema.PartiallyGenerated(rawContent)
    return StructuredOutputSnapshot(id: id, contentPhase: .partial(content), rawContent: rawContent)
  }

  /// Decodes a final update from a JSON string.
  public static func final(id: String, json: String) throws -> StructuredOutputSnapshot<Output> {
    let rawContent = try GeneratedContent(json: json)
    let content = try Output.Schema(rawContent)
    return StructuredOutputSnapshot(id: id, contentPhase: .final(content), rawContent: rawContent)
  }

  /// Creates an update that carries an error payload.
  public static func error(id: String, error: GeneratedContent) throws -> StructuredOutputSnapshot<Output> {
    StructuredOutputSnapshot(id: id, error: error, rawContent: error)
  }
}

private extension StructuredOutputSnapshot {
  /// Produces a current view for a given typed content.
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
