// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
  struct Resolved<Provider: LanguageModelProvider>: Equatable, Sendable {
    /// All transcript entries with resolved tool runs attached where available.
    public package(set) var entries: [Entry]

    init(transcript: Transcript, session: Provider) {
      let resolver = TranscriptResolver(for: session, transcript: transcript)
      entries = []

      for entry in transcript.entries {
        switch entry {
        case let .prompt(prompt):
          var decodedSources: [Provider.GroundingSource] = []
          var errorContext: TranscriptResolutionError.PromptResolution?

          do {
            decodedSources = try session.decodeGrounding(from: prompt.sources)
          } catch {
            errorContext = .groundingDecodingFailed(description: error.localizedDescription)
          }

          entries.append(.prompt(Resolved.Prompt(
            id: prompt.id,
            input: prompt.input,
            sources: decodedSources,
            prompt: prompt.prompt,
            error: errorContext,
          )))
        case let .reasoning(reasoning):
          entries.append(.reasoning(Resolved.Reasoning(
            id: reasoning.id,
            summary: reasoning.summary,
          )))
        case let .response(response):
          var segments: [Segment] = []

          for segment in response.segments {
            switch segment {
            case let .text(text):
              segments.append(.text(Resolved.TextSegment(
                id: text.id,
                content: text.content,
              )))
            case let .structure(structure):
              let content = resolver.resolve(structure, status: response.status)
              segments.append(.structure(Resolved.StructuredSegment(
                id: structure.id,
                typeName: structure.typeName,
                content: content,
              )))
            }
          }

          entries.append(.response(Resolved.Response(
            id: response.id,
            segments: segments,
            status: response.status,
          )))
        case let .toolCalls(toolCalls):
          for call in toolCalls {
            let resolvedToolRun = resolver.resolve(call)
            entries.append(.toolRun(resolvedToolRun))
          }
        case .toolOutput:
          // Handled already by the .toolCalls cases
          break
        }
      }
    }

    /// Transcript entry augmented with resolved tool runs.
    public enum Entry: Identifiable, Equatable, Sendable {
      case prompt(Prompt)
      case reasoning(Reasoning)
      case toolRun(Provider.ResolvedToolRun)
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
      public var sources: [Provider.GroundingSource]
      public let error: TranscriptResolutionError.PromptResolution?
      package var prompt: String

      package init(
        id: String,
        input: String,
        sources: [Provider.GroundingSource],
        prompt: String,
        error: TranscriptResolutionError.PromptResolution? = nil,
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

      package init(
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

      public var text: String? {
        var components: [String] = []
        for segment in segments {
          switch segment {
          case let .text(textSegment):
            components.append(textSegment.content)
          case .structure:
            return nil
          }
        }

        guard !components.isEmpty else { return nil }

        return components.joined(separator: "\n")
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
      public var content: Provider.ResolvedStructuredOutput

      public init(id: String, typeName: String = "", content: Provider.ResolvedStructuredOutput) {
        self.id = id
        self.typeName = typeName
        self.content = content
      }
    }
  }
}

extension Transcript.Resolved: RandomAccessCollection, RangeReplaceableCollection {
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
