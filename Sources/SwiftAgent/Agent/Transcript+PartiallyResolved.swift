// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
//	func partiallyResolved<Session: LanguageModelProvider>(
//		using toolGroup: Resolver,
//	) throws -> PartiallyResolved<Resolver>? {
//		try PartiallyResolved(transcript: self, toolGroup: toolGroup)
//	}

	/// An immutable **projection** of a transcript with tool runs resolved.
	///
	/// You can obtain instances via ``Transcript/resolved(using:)``.
	struct PartiallyResolved<Session: LanguageModelProvider>: Equatable {
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript, session: Session) throws {
			let resolver = ToolResolver(for: session, transcript: transcript)
			entries = []

			for entry in transcript.entries {
				switch entry {
				case let .prompt(prompt):
					try entries.append(.prompt(PartiallyResolved.Prompt(
						id: prompt.id,
						input: prompt.input,
						sources: session.decodeGrounding(from: prompt.sources),
						prompt: prompt.prompt,
					)))
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
			case prompt(Prompt)
			case reasoning(Transcript.Reasoning)
			case toolRun(ToolRunKind)
			case response(Transcript.Response)

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

		public struct Prompt: Sendable, Identifiable, Equatable {
			public var id: String
			public var input: String
			public var sources: [Session.GroundingSource]
			package var prompt: String

			package init(
				id: String = UUID().uuidString,
				input: String,
				sources: [Session.GroundingSource],
				prompt: String,
			) {
				self.id = id
				self.input = input
				self.sources = sources
				self.prompt = prompt
			}
		}

		/// A resolved tool run.
		public struct ToolRunKind: Identifiable, Equatable {
			private let call: Transcript.ToolCall

			/// The identifier of this run.
			public var id: String { call.id }

			/// The tool resolution.
			public let resolution: Session.PartiallyResolvedToolRun

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(call: Transcript.ToolCall, resolution: Session.PartiallyResolvedToolRun) {
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
