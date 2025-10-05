// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
	// Builds a *resolved transcript* — an immutable, read‑only **projection** of this transcript in which
	// tool‑related events are materialized as strongly-typed runs.
	//
	// ### What it does
	// - Walks the original entries in order.
	// - Converts `.toolCalls` into one or more `.toolRun` entries by resolving each call with one
	//   of the supplied tools.
	// - Coalesces related `.toolOutput` items into the resulting `.toolRun` and does **not** surface
	//   separate `.toolOutput` entries in the projection.
	//
	// ### When to use it
	// Use this when you want to *render* or *inspect* tool results in a type‑safe way without
	// mutating or duplicating transcript state.
	//
	// ### Failure
	// Returns `nil` if any tool call cannot be resolved with the provided tools (for example,
	// no matching tool by name, or decoding arguments failed).
	//
	// ### Example
	// ```swift
	// if let resolved = transcript.resolved(using: tools) {
	//   for entry in resolved {
	//     switch entry {
	//     case let .toolRun(run):
	//       render(run.resolution)
	//     default:
	//       break
	//     }
	//   }
	// }
	// ```
	//
	// - Parameter tools: The tools available during resolution. All must share the same resolution type.
	// - Returns: A read‑only projection that layers resolved tool runs over the original entries, or `nil` on failure.
//	func resolved<Resolver>(using toolGroup: Resolver) throws -> Resolved<Resolver>? {
//		try Resolved(transcript: self, toolGroup: toolGroup)
//	}

	/// An immutable **projection** of a transcript with tool runs resolved.
	///
	/// You can obtain instances via ``Transcript/resolved(using:)``.
	struct Resolved<Provider: LanguageModelProvider>: Equatable, Sendable {
		public let unresolvedTranscript: Transcript
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript, session: Provider) {
			let resolver = ToolResolver(for: session, transcript: transcript)
			unresolvedTranscript = transcript
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
					entries.append(.reasoning(reasoning))
				case let .response(response):
					entries.append(.response(response))
				case let .toolCalls(toolCalls):
					for call in toolCalls {
						var resolvedRun: Provider.ResolvedToolRun?
						var toolRunError: TranscriptResolutionError.ToolRunResolution?

						do {
							resolvedRun = try resolver.resolve(call)
						} catch {
							toolRunError = error
						}

						entries.append(.toolRun(.init(call: call, resolution: resolvedRun, error: toolRunError)))
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
			public var sources: [Provider.GroundingSource]
			public let error: TranscriptResolutionError.PromptResolution?
			package var prompt: String

			package init(
				id: String = UUID().uuidString,
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
		}

		/// A resolved tool run.
		public struct ToolRunKind: Identifiable, Equatable, Sendable {
			private let call: Transcript.ToolCall

			/// The identifier of this run.
			public var id: String { call.id }

			/// The tool resolution.
			public let resolution: Provider.ResolvedToolRun?

			/// The error that occurred during resolution.
			public let error: TranscriptResolutionError.ToolRunResolution?

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(
				call: Transcript.ToolCall,
				resolution: Provider.ResolvedToolRun?,
				error: TranscriptResolutionError.ToolRunResolution?,
			) {
				self.call = call
				self.resolution = resolution
				self.error = error
			}
		}
	}
}

extension Transcript.Resolved: RandomAccessCollection, RangeReplaceableCollection {
	public var startIndex: Int { entries.startIndex }
	public var endIndex: Int { entries.endIndex }

	public init() {
		unresolvedTranscript = Transcript()
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
