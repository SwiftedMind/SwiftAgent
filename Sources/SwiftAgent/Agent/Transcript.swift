// By Dennis Müller

import Foundation
import FoundationModels

public struct Transcript<Context: PromptContextSource>: Sendable, Equatable {
	public var entries: [Entry]
	
	public init(entries: [Entry] = []) {
		self.entries = entries
	}
	
	package mutating func upsert(_ entry: Entry) {
		if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
			entries[existingIndex] = entry
		} else {
			entries.append(entry)
		}
	}
}

// MARK: - RandomAccessCollection Conformance

extension Transcript: RandomAccessCollection, RangeReplaceableCollection {
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

public extension SwiftAgent.Transcript {
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
			embeddedPrompt: String,
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
			status: Status? = nil,
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

extension Transcript.ToolCalls: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { calls.startIndex }
	public var endIndex: Int { calls.endIndex }
	
	public subscript(position: Int) -> Transcript<Context>.ToolCall {
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
		with newElements: some Collection<Transcript<Context>.ToolCall>,
	) {
		calls.replaceSubrange(subrange, with: newElements)
	}
}

public extension Transcript {
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
			status: Status?,
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
			status: Status?,
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
			status: Status,
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
