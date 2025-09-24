// By Dennis Müller

import Foundation
import FoundationModels

public extension AgentTranscript {
	/// Builds a *resolved transcript* — an immutable, read‑only **projection** of this transcript in which
	/// tool‑related events are materialized as strongly-typed runs.
	///
	/// ### What it does
	/// - Walks the original entries in order.
	/// - Converts `.toolCalls` into one or more `.toolRun` entries by resolving each call with one
	///   of the supplied tools.
	/// - Coalesces related `.toolOutput` items into the resulting `.toolRun` and does **not** surface
	///   separate `.toolOutput` entries in the projection.
	///
	/// ### When to use it
	/// Use this when you want to *render* or *inspect* tool results in a type‑safe way without
	/// mutating or duplicating transcript state.
	///
	/// ### Failure
	/// Returns `nil` if any tool call cannot be resolved with the provided tools (for example,
	/// no matching tool by name, or decoding arguments failed).
	///
	/// ### Example
	/// ```swift
	/// if let resolved = transcript.resolved(using: tools) {
	///   for entry in resolved {
	///     switch entry {
	///     case let .toolRun(run):
	///       render(run.resolution)
	///     default:
	///       break
	///     }
	///   }
	/// }
	/// ```
	///
	/// - Parameter tools: The tools available during resolution. All must share the same resolution type.
	/// - Returns: A read‑only projection that layers resolved tool runs over the original entries, or `nil` on failure.
	func resolved<ResolvedToolRun>(using tools: [any AgentTool<ResolvedToolRun>]) -> Resolved<ResolvedToolRun>? {
		try? Resolved(transcript: self, tools: tools)
	}

	/// An immutable **projection** of a transcript with tool runs resolved.
	///
	/// You can obtain instances via ``AgentTranscript/resolved(using:)``.
	struct Resolved<ResolutionType> {
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: AgentTranscript<Context>, tools: [any AgentTool<ResolutionType>]) throws {
			let resolver = AgentToolResolver(tools: tools, in: transcript)
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
						let resolution = try resolver.resolve(call)
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
					toolRun.id
				case let .response(response):
					response.id
				}
			}
		}

		/// A resolved tool run.
		public struct ResolvedToolRun: Identifiable {
			private let call: AgentTranscript<Context>.ToolCall

			/// The identifier of this run.
			public var id: String { call.id }

			/// The tool resolution.
			public let resolution: ResolutionType

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(call: AgentTranscript<Context>.ToolCall, resolution: ResolutionType) {
				self.call = call
				self.resolution = resolution
			}
		}
	}
}

extension AgentTranscript.Resolved: RandomAccessCollection, RangeReplaceableCollection {
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
