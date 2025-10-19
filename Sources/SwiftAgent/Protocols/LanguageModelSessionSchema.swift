// By Dennis Müller

import Foundation
import FoundationModels

public protocol GroundingSupportingSchema {}

/// Describes the schema backing an agent session.
///
/// A schema enumerates the tools, groundings, and structured outputs that SwiftAgent should decode
/// for a session. In typical apps you don't conform to this protocol manually—annotate a type with
/// the ``SessionSchema`` macro and the compiler will synthesize the required metadata and helper
/// wrappers for you.
public protocol LanguageModelSessionSchema {
  /// Your app's type that represents a resolved grounding item emitted by decoding.
  associatedtype DecodedGrounding: SwiftAgent.DecodedGrounding

  /// Your app's type that represents a decoded tool run.
  associatedtype DecodedToolRun: SwiftAgent.DecodedToolRun

  /// Your app's type that represents a decoded structured output.
  associatedtype DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput

  associatedtype StructuredOutputs

  typealias Transcript = SwiftAgent.Transcript.Decoded<Self>

  /// Internal decodable wrappers used by the transcript decoder.
  ///
  /// - Note: Populated automatically by the macro; you do not create these yourself.
  nonisolated var decodableTools: [any DecodableTool<DecodedToolRun>] { get }

  static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type]
}

public extension LanguageModelSessionSchema {
  func transcriptDecoder() -> TranscriptDecoder<Self> {
    TranscriptDecoder(for: self)
  }

  func decode(_ transcript: SwiftAgent.Transcript) throws -> Transcript {
    let decoder = TranscriptDecoder(for: self)
    return try decoder.decode(transcript)
  }
}

package extension LanguageModelSessionSchema {
  nonisolated func encodeGrounding(_ grounding: [DecodedGrounding]) throws -> Data {
    try JSONEncoder().encode(grounding)
  }
}

/// A default transcript decoder that can be used when no custom decoder is provided. It is empty.
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
