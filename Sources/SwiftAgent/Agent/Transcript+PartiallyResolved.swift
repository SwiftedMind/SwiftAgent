// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
	func partiallyResolved<ToolGroup: TranscriptDecodable>(
		using toolGroup: ToolGroup,
	) throws -> PartiallyResolved<ToolGroup>? {
		try PartiallyResolved(transcript: self, toolGroup: toolGroup)
	}

	/// An immutable **projection** of a transcript with tool runs resolved.
	///
	/// You can obtain instances via ``Transcript/resolved(using:)``.
	struct PartiallyResolved<ToolGroup: TranscriptDecodable>: Equatable {
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript<Context>, toolGroup: ToolGroup) throws {
			let resolver = ToolResolver(for: toolGroup, in: transcript)
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
		public enum Entry: Identifiable, Equatable {
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
		public struct ToolRunKind: Identifiable, Equatable {
			private let call: Transcript<Context>.ToolCall

			/// The identifier of this run.
			public var id: String { call.id }

			/// The tool resolution.
			public let resolution: ToolGroup.PartiallyResolvedToolRun

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(call: Transcript<Context>.ToolCall, resolution: ToolGroup.PartiallyResolvedToolRun) {
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
