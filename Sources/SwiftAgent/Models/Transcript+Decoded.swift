// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
  struct Decoded<SessionSchema: LanguageModelSessionSchema>: Equatable, Sendable {
    /// All transcript entries with decoded tool runs attached where available.
    public package(set) var entries: [Entry]

    public init(entries: [Entry]) {
      self.entries = entries
    }

    /// Transcript entry augmented with decoded tool runs.
    public enum Entry: Identifiable, Equatable, Sendable {
      case prompt(Prompt)
      case reasoning(Reasoning)
      case toolRun(SessionSchema.DecodedToolRun)
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

    public struct Prompt: Identifiable, Sendable, Equatable {
      public var id: String
      public var input: String
      public var sources: [SessionSchema.DecodedGrounding]
      public let error: TranscriptDecodingError.PromptResolution?
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

    public struct Reasoning: Sendable, Identifiable, Equatable {
      public var id: String
      public var summary: [String]

      public init(
        id: String,
        summary: [String],
      ) {
        self.id = id
        self.summary = summary
      }
    }

    public struct Response: Sendable, Identifiable, Equatable {
      public var id: String
      public var segments: [Segment]
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

      public var text: String? {
        let contents = textSegments.map(\.content)
        if contents.isEmpty { return nil }
        return contents.joined(separator: "\n")
      }
    }

    public enum Segment: Sendable, Identifiable, Equatable {
      case text(TextSegment)
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

    public struct TextSegment: Sendable, Identifiable, Equatable {
      public var id: String
      public var content: String

      public init(id: String, content: String) {
        self.id = id
        self.content = content
      }
    }

    public struct StructuredSegment: Sendable, Identifiable, Equatable {
      public var id: String
      public var typeName: String
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
