// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
  /// Transcript materialized into strongly typed entries using a ``SessionSchema``.
  ///
  /// Each item mirrors the live transcript but swaps raw `GeneratedContent` blocks for the concrete
  /// types you registered in your schema. Groundings, tool runs, and structured responses are fully
  /// decoded so UI layers and tests can work with Swift values instead of JSON.
  ///
  /// Use ``Transcript/decoded(using:)`` to obtain this type and display it in your app. The decoded
  /// view stays lightweight: it preserves ordering, streaming identifiers, and even resolution errors
  /// when decoding fails so you can surface them to the user.
  struct Decoded<SessionSchema: LanguageModelSessionSchema>: Equatable, Sendable {
    /// Ordered transcript entries with schema-backed values.
    public package(set) var entries: [Entry]

    public init(entries: [Entry]) {
      self.entries = entries
    }

    /// One entry in the decoded transcript.
    public enum Entry: Identifiable, Equatable, Sendable {
      /// Rendered prompt plus typed grounding sources.
      case prompt(Prompt)

      /// Summarized reasoning lines exposed by the provider.
      case reasoning(Reasoning)

      /// Tool invocation paired with typed arguments and outputs.
      case toolRun(SessionSchema.DecodedToolRun)

      /// Model response with typed structured segments and plain text.
      case response(Response)

      public var id: String {
        switch self {
        case let .prompt(prompt):
          prompt.id
        case let .reasoning(reasoning):
          reasoning.id
        case let .toolRun(toolRun):
          toolRun.id
        case let .response(response):
          response.id
        }
      }
    }

    /// Prompt emitted during the turn with its decoded groundings.
    public struct Prompt: Identifiable, Sendable, Equatable {
      public var id: String

      /// Raw user input collected before rendering the final prompt.
      public var input: String

      /// Grounding payloads resolved through the session schema.
      public var sources: [SessionSchema.DecodedGrounding]

      /// Any errors encountered while reconstructing the prompt and sources.
      public let error: TranscriptDecodingError.PromptResolution?

      /// Final prompt body sent to the provider.
      public var prompt: String

      public init(
        id: String,
        input: String,
        sources: [SessionSchema.DecodedGrounding],
        prompt: String,
        error: TranscriptDecodingError.PromptResolution? = nil,
      ) {
        self.id = id
        self.input = input
        self.sources = sources
        self.error = error
        self.prompt = prompt
      }

      public static func == (lhs: Prompt, rhs: Prompt) -> Bool {
        lhs.id == rhs.id && lhs.prompt == rhs.prompt
      }

      public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(prompt)
      }
    }

    /// Provider reasoning surfaced during the turn with schema-aware status.
    public struct Reasoning: Sendable, Identifiable, Equatable {
      public var id: String

      /// High-level reasoning statements emitted by the provider.
      public var summary: [String]

      public init(
        id: String,
        summary: [String],
      ) {
        self.id = id
        self.summary = summary
      }
    }

    /// Model response with text segments and decoded structured payloads.
    public struct Response: Sendable, Identifiable, Equatable {
      public var id: String

      /// Ordered response segments.
      public var segments: [Segment]

      /// Completion status reported for the response.
      public var status: Status

      public init(
        id: String,
        segments: [Segment],
        status: Status,
      ) {
        self.id = id
        self.segments = segments
        self.status = status
      }

      /// Text segments emitted by the response in order.
      public var textSegments: [TextSegment] {
        segments.compactMap { segment in
          switch segment {
          case let .text(textSegment):
            textSegment
          case .structure:
            nil
          }
        }
      }

      /// Structured segments decoded with the session schema.
      public var structuredSegments: [StructuredSegment] {
        segments.compactMap { segment in
          switch segment {
          case let .structure(structuredSegment):
            structuredSegment
          case .text:
            nil
          }
        }
      }

      /// Convenience joined text across all text segments.
      public var text: String? {
        let contents = textSegments.map(\.content)
        if contents.isEmpty { return nil }
        return contents.joined(separator: "\n")
      }
    }

    /// Segment emitted by the model or a tool after decoding.
    public enum Segment: Sendable, Identifiable, Equatable {
      /// Plain text.
      case text(TextSegment)

      /// Structured payload resolved into schema types.
      case structure(StructuredSegment)

      public var id: String {
        switch self {
        case let .text(textSegment):
          textSegment.id
        case let .structure(structuredSegment):
          structuredSegment.id
        }
      }
    }

    /// Plain text emitted by the response or a tool.
    public struct TextSegment: Sendable, Identifiable, Equatable {
      public var id: String

      public var content: String

      public init(id: String, content: String) {
        self.id = id
        self.content = content
      }
    }

    /// Structured segment resolved into schema-backed content.
    public struct StructuredSegment: Sendable, Identifiable, Equatable {
      public var id: String

      /// Type hint supplied by the session, when available.
      public var typeName: String

      /// Fully decoded structured output from the session schema.
      public var content: SessionSchema.DecodedStructuredOutput

      public init(id: String, typeName: String = "", content: SessionSchema.DecodedStructuredOutput) {
        self.id = id
        self.typeName = typeName
        self.content = content
      }
    }
  }
}

extension Transcript.Decoded: RandomAccessCollection, RangeReplaceableCollection {
  public var startIndex: Int { entries.startIndex }
  public var endIndex: Int { entries.endIndex }

  public init() {
    entries = []
  }

  public subscript(position: Int) -> Entry {
    entries[position]
  }

  public func index(after i: Int) -> Int {
    entries.index(after: i)
  }

  public func index(before i: Int) -> Int {
    entries.index(before: i)
  }

  public mutating func replaceSubrange(_ subrange: Range<Int>, with newElements: some Collection<Entry>) {
    entries.replaceSubrange(subrange, with: newElements)
  }
}
