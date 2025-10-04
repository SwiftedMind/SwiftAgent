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
	struct PartiallyResolved<Session: LanguageModelProvider>: Equatable, Sendable {
		public let unresolvedTranscript: Transcript
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript, session: Session) {
			let resolver = ToolResolver(for: session, transcript: transcript)
			unresolvedTranscript = transcript
			entries = []

			for entry in transcript.entries {
				switch entry {
				case let .prompt(prompt):
					var decodedSources: [Session.GroundingSource] = []
					var promptError: TranscriptResolutionError.PromptResolution?

					do {
						decodedSources = try session.decodeGrounding(from: prompt.sources)
					} catch {
						promptError = .groundingDecodingFailed(description: error.localizedDescription)
					}

					entries.append(.prompt(PartiallyResolved.Prompt(
						id: prompt.id,
						input: prompt.input,
						sources: decodedSources,
						prompt: prompt.prompt,
						error: promptError,
					)))
				case let .reasoning(reasoning):
					entries.append(.reasoning(reasoning))
				case let .response(response):
					entries.append(.response(response))
				case let .toolCalls(toolCalls):
					for call in toolCalls {
						var resolvedRun: Session.PartiallyResolvedToolRun?
						var toolRunError: TranscriptResolutionError.ToolRunResolution?

						do {
							resolvedRun = try resolver.resolvePartially(call)
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
			public var sources: [Session.GroundingSource]
			public let error: TranscriptResolutionError.PromptResolution?
			package var prompt: String

			package init(
				id: String = UUID().uuidString,
				input: String,
				sources: [Session.GroundingSource],
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
			public let resolution: Session.PartiallyResolvedToolRun?
			public let error: TranscriptResolutionError.ToolRunResolution?

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String { call.toolName }

			init(
				call: Transcript.ToolCall,
				resolution: Session.PartiallyResolvedToolRun?,
				error: TranscriptResolutionError.ToolRunResolution?,
			) {
				self.call = call
				self.resolution = resolution
				self.error = error
			}
		}
	}
}

extension Transcript.PartiallyResolved: RandomAccessCollection, RangeReplaceableCollection {
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
