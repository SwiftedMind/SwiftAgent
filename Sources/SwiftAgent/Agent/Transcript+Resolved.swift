// By Dennis Müller

import Foundation
import FoundationModels

public extension Transcript {
	struct Resolved<Provider: LanguageModelProvider>: Equatable, Sendable {
		/// All transcript entries with resolved tool runs attached where available.
		public package(set) var entries: [Entry]

		init(transcript: Transcript, session: Provider) {
			let resolver = ToolResolver(for: session, transcript: transcript)
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
					entries.append(.response(response))
				case let .toolCalls(toolCalls):
					for call in toolCalls {
						entries.append(.toolRun(.init(call: call, resolution: resolver.resolve(call))))
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

		/// A resolved tool run.
		public struct ToolRunKind: Identifiable, Equatable, Sendable {
			/// The identifier of this run.
			public var id: String

			/// The tool resolution.
			public let resolution: Provider.ResolvedToolRun

			/// The tool name captured within the original call, convenient for switching logic.
			public var toolName: String

			init(
				call: Transcript.ToolCall,
				resolution: Provider.ResolvedToolRun,
			) {
				id = call.id
				toolName = call.toolName
				self.resolution = resolution
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
