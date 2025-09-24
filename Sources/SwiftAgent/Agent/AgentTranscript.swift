// By Dennis Müller

import Foundation
import FoundationModels

public struct AgentTranscript<Context: PromptContextSource>: Sendable, Equatable {
	public var entries: [Entry]

	public init(entries: [Entry] = []) {
		self.entries = entries
	}
}

// MARK: - RandomAccessCollection Conformance

extension AgentTranscript: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { entries.startIndex }
	public var endIndex: Int { entries.endIndex }

	public subscript(position: Int) -> Entry {
		entries[position]
	}

	public func index(after i: Int) -> Int {
		entries.index(after: i)
	}

	public func index(before i: Int) -> Int {
		entries.index(before: i)
	}

	public init() {
		entries = []
	}

	public mutating func replaceSubrange(_ subrange: Range<Int>, with newElements: some Collection<Entry>) {
		entries.replaceSubrange(subrange, with: newElements)
	}
}

public extension AgentTranscript {
	enum Entry: Sendable, Identifiable, Equatable {
		case prompt(Prompt)
		case reasoning(Reasoning)
		case toolCalls(ToolCalls)
		case toolOutput(ToolOutput)
		case response(Response)

		public var id: String {
			switch self {
			case let .prompt(prompt):
				prompt.id
			case let .reasoning(reasoning):
				reasoning.id
			case let .toolCalls(toolCalls):
				toolCalls.id
			case let .toolOutput(toolOutput):
				toolOutput.id
			case let .response(response):
				response.id
			}
		}
	}

	struct Prompt: Sendable, Identifiable, Equatable {
		public var id: String
		public var input: String
		public var context: PromptContext<Context>
		package var embeddedPrompt: String

		package init(
			id: String = UUID().uuidString,
			input: String,
			context: PromptContext<Context> = .empty,
			embeddedPrompt: String
		) {
			self.id = id
			self.input = input
			self.context = context
			self.embeddedPrompt = embeddedPrompt
		}
	}

	struct Reasoning: Sendable, Identifiable, Equatable {
		public var id: String
		public var summary: [String]
		public var encryptedReasoning: String?
		public var status: Status?

		package init(
			id: String,
			summary: [String],
			encryptedReasoning: String?,
			status: Status? = nil
		) {
			self.id = id
			self.summary = summary
			self.encryptedReasoning = encryptedReasoning
			self.status = status
		}
	}

	enum Status: Sendable, Identifiable, Equatable {
		case completed
		case incomplete
		case inProgress

		public var id: Self { self }
	}

	struct ToolCalls: Sendable, Identifiable, Equatable {
		public var id: String
		public var calls: [ToolCall]

		public init(id: String = UUID().uuidString, calls: [ToolCall]) {
			self.id = id
			self.calls = calls
		}
	}
}

// MARK: - ToolCalls RandomAccessCollection Conformance

extension AgentTranscript.ToolCalls: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { calls.startIndex }
	public var endIndex: Int { calls.endIndex }

	public subscript(position: Int) -> AgentTranscript<Context>.ToolCall {
		calls[position]
	}

	public func index(after i: Int) -> Int {
		calls.index(after: i)
	}

	public func index(before i: Int) -> Int {
		calls.index(before: i)
	}

	public init() {
		id = UUID().uuidString
		calls = []
	}

	public mutating func replaceSubrange(
		_ subrange: Range<Int>,
		with newElements: some Collection<AgentTranscript<Context>.ToolCall>
	) {
		calls.replaceSubrange(subrange, with: newElements)
	}
}

public extension AgentTranscript {
	struct ToolCall: Sendable, Identifiable, Equatable {
		public var id: String
		public var callId: String
		public var toolName: String
		public var arguments: GeneratedContent
		public var status: Status?

		package init(
			id: String,
			callId: String,
			toolName: String,
			arguments: GeneratedContent,
			status: Status?
		) {
			self.id = id
			self.callId = callId
			self.toolName = toolName
			self.arguments = arguments
			self.status = status
		}
	}

	struct ToolOutput: Sendable, Identifiable, Equatable {
		public var id: String
		public var callId: String
		public var toolName: String
		public var segment: Segment
		public var status: Status?

		public init(
			id: String,
			callId: String,
			toolName: String,
			segment: Segment,
			status: Status?
		) {
			self.id = id
			self.callId = callId
			self.toolName = toolName
			self.segment = segment
			self.status = status
		}
	}

	struct Response: Sendable, Identifiable, Equatable {
		public var id: String
		public var segments: [Segment]
		public var status: Status

		public init(
			id: String,
			segments: [Segment],
			status: Status
		) {
			self.id = id
			self.segments = segments
			self.status = status
		}
	}

	enum Segment: Sendable, Identifiable, Equatable {
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

	struct TextSegment: Sendable, Identifiable, Equatable {
		public var id: String
		public var content: String

		public init(id: String = UUID().uuidString, content: String) {
			self.id = id
			self.content = content
		}
	}

	struct StructuredSegment: Sendable, Identifiable, Equatable {
		public var id: String
		public var content: GeneratedContent

		public init(id: String = UUID().uuidString, content: GeneratedContent) {
			self.id = id
			self.content = content
		}

		public init(id: String = UUID().uuidString, content: some ConvertibleToGeneratedContent) {
			self.id = id
			self.content = content.generatedContent
		}
	}
}

public extension AgentTranscript {
	/// Returns a transcript view with resolved tool runs attached to each tool call entry.
	///
	/// This method provides a progressive enhancement on top of the base transcript. When you
	/// need strongly typed tool results, call this method to receive a typed view while keeping
	/// the underlying transcript unchanged. If you do not need tool resolution, simply work with
	/// ``AgentTranscript`` directly—no additional generics or APIs get in the way.
	///
	/// - Parameter tools: The tools used during the session, sharing the same `ResolvedToolRun` type.
	/// - Returns: A resolved transcript view that preserves the original entries and adds resolved runs.
	func resolved<ResolvedToolRun>(using tools: [any AgentTool<ResolvedToolRun>]) -> Resolved<ResolvedToolRun> {
		Resolved(transcript: self, tools: tools)
	}

	/// A transcript view that augments tool call entries with resolved tool runs.
	///
	/// The resolved transcript keeps the original transcript intact for full reproduction of the
	/// provider conversation, while offering type-safe access to resolved tool runs alongside each
	/// tool call.
	struct Resolved<ResolvedToolRun> {
		/// The original transcript that backs this view.
		public let originalTranscript: AgentTranscript<Context>

		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: AgentTranscript<Context>, tools: [any AgentTool<ResolvedToolRun>]) {
			self.originalTranscript = transcript
			let resolver = AgentToolResolver(tools: tools, in: transcript)
			self.entries = []
			
			for entry in transcript.entries {
				switch entry {
				case let .prompt(prompt):
					entries.append(.prompt(prompt))
				case let .reasoning(reasoning):
					entries.append(.reasoning(reasoning))
				case let .response(response):
					entries.append(.response(response))
				case let .toolCalls(toolCalls):
					for call in toolCalls {
						let resolvedToolRun = try! resolver.resolve(call)
						entries.append(.toolRun(resolvedToolRun))
					}
				case .toolOutput:
					// Handled already by the .toolCalls cases
					break
				}
			}
		}

		/// Transcript entry augmented with resolved tool runs.
		public enum Entry: Identifiable {
			case prompt(AgentTranscript<Context>.Prompt)
			case reasoning(AgentTranscript<Context>.Reasoning)
			case toolRun(ResolvedToolRun)
			case response(AgentTranscript<Context>.Response)

			public var id: String {
				switch self {
				case let .prompt(prompt):
					prompt.id
				case let .reasoning(reasoning):
					reasoning.id
				case let .toolRun(toolRun):
					// TODO: Fix this
					"toolRun.id"
				case let .response(response):
					response.id
				}
			}
		}
	}
}

extension AgentTranscript.Resolved: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { entries.startIndex }
	public var endIndex: Int { entries.endIndex }

	public init() {
		entries = []
		self.originalTranscript = AgentTranscript()
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
