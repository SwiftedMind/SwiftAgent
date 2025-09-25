// By Dennis Müller

import Foundation
import FoundationModels

/*

 Perspective Change: The session's transcript is not meant for direct display in the UI.
 - Flow should be that you start with an empty ui state (or build from existing transcript) and whenever you call respond(), you take the response object and parse the added entries into your ui state
 - With streaming it will then be the same, you just get partial data until everything has streamed in

 have the transcript as the base and emit it to the user in the stream response! then:

 transcript.partiallyResolved(using: tools)

 enum Transcript.PartiallyResolved

 case reasoning({ summary: String })
 case toolRun(PartialToolRun)
 case output()

 */

public func test() async throws -> Transcript<NoContext> {
	print(try! GeneratedContent(json: #"{"firstNumber": 42.0,"#))
	return try Transcript<NoContext>(
		entries: [.toolCalls(
			.init(
				calls: [.init(
					id: "id",
					callId: "ABC",
					toolName: "calculator",
					arguments: GeneratedContent(json: #"{"firstNumber": 42.0,"#),
					status: .inProgress
				)]
			)
		)]
	)
}

public extension Transcript {
	func partiallyResolved<Tools: ResolvableToolGroup>(using tools: [any ResolvableTool<Tools>])
		-> PartiallyResolved<Tools>? {
		try? PartiallyResolved(transcript: self, tools: tools)
	}

	/// An immutable **projection** of a transcript with tool runs resolved.
	///
	/// You can obtain instances via ``Transcript/resolved(using:)``.
	struct PartiallyResolved<Tools: ResolvableToolGroup> {
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript<Context>, tools: [any ResolvableTool<Tools>]) throws {
			let resolver = ToolResolver(tools: tools, in: transcript)
			entries = []

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
						let resolution = try resolver.resolvePartially(call)
						entries.append(.toolRun(.init(call: call, resolution: resolution)))
					}
				case .toolOutput:
					// Handled already by the .toolCalls cases
					break
				}
			}
		}

		/// Transcript entry augmented with resolved tool runs.
		public enum Entry: Identifiable {
			case prompt(Transcript<Context>.Prompt)
			case reasoning(Transcript<Context>.Reasoning)
			case toolRun(ToolRunKind)
			case response(Transcript<Context>.Response)

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

		/// A resolved tool run.
		public struct ToolRunKind: Identifiable {
			private let call: Transcript<Context>.ToolCall

			/// The identifier of this run.
			public var id: String { call.id }

			/// The tool resolution.
			public let resolution: Tools.Partials

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(call: Transcript<Context>.ToolCall, resolution: Tools.Partials) {
				self.call = call
				self.resolution = resolution
			}
		}
	}
}

extension Transcript.PartiallyResolved: RandomAccessCollection, RangeReplaceableCollection {
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
