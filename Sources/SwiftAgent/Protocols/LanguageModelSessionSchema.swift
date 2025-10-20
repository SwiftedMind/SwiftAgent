// By Dennis Müller

import Foundation
import FoundationModels

public protocol GroundingSupportingSchema {}

/// Describes the schema backing an agent session.
///
/// A schema enumerates the tools, groundings, and structured outputs that SwiftAgent should resolve
/// for a session. In typical apps you don't conform to this protocol manually—annotate a type with
/// the ``SessionSchema`` macro and the compiler will synthesize the required metadata and helper
/// wrappers for you.
public protocol LanguageModelSessionSchema {
  /// Your app's type that represents a resolved grounding item emitted by the transcript resolver.
  associatedtype DecodedGrounding: SwiftAgent.DecodedGrounding

  /// Your app's type that represents a resolved tool run.
  associatedtype DecodedToolRun: SwiftAgent.DecodedToolRun

  /// Your app's type that represents a resolved structured output.
  associatedtype DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput

  associatedtype StructuredOutputs

  typealias Transcript = SwiftAgent.Transcript.Resolved<Self>

  /// Internal decodable wrappers used by the transcript resolver.
  ///
  /// - Note: Populated automatically by the macro; you do not create these yourself.
  nonisolated var decodableTools: [any DecodableTool<DecodedToolRun>] { get }

  static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type]
}

public extension LanguageModelSessionSchema {
  func transcriptResolver() -> TranscriptResolver<Self> {
    TranscriptResolver(for: self)
  }

  func resolve(_ transcript: SwiftAgent.Transcript) throws -> Transcript {
    let resolver = TranscriptResolver(for: self)
    return try resolver.resolve(transcript)
  }
}

package extension LanguageModelSessionSchema {
  nonisolated func encodeGrounding(_ grounding: [DecodedGrounding]) throws -> Data {
    try JSONEncoder().encode(grounding)
  }
}

/// A default transcript resolver that can be used when no custom resolver is provided. It is empty.
public struct NoSchema: LanguageModelSessionSchema {
  public let decodableTools: [any DecodableTool<DecodedToolRun>] = []
  public static func structuredOutputs() -> [any DecodableStructuredOutput<DecodedStructuredOutput>.Type] {
    []
  }

  public init() {}

  public struct StructuredOutputs {}

  public struct DecodedGrounding: SwiftAgent.DecodedGrounding {}
  public struct DecodedToolRun: SwiftAgent.DecodedToolRun {
    public let id: String = UUID().uuidString

    public static func makeUnknown(toolCall: Transcript.ToolCall) -> DecodedToolRun {
      .init()
    }
  }

  public struct DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
    public static func makeUnknown(segment: Transcript.StructuredSegment) -> DecodedStructuredOutput {
      .init()
    }
  }
}
