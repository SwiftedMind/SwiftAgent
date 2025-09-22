// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

@MainActor
public struct SimulationAdapter {
	public typealias Model = OpenAI.Model
	public typealias Transcript<Context: PromptContextSource> = AgentTranscript<Context>

	public struct Configuration: Sendable {
		/// The delay between simulated model generations. Defaults to 2 seconds.
		public var generationDelay: Duration

		/// Optional simulated aggregate token usage reported for the run.
		public var tokenUsage: TokenUsage?

		public init(generationDelay: Duration = .seconds(2), tokenUsage: TokenUsage? = nil) {
			self.generationDelay = generationDelay
			self.tokenUsage = tokenUsage
		}
	}

	private let configuration: Configuration

	public init(configuration: Configuration = Configuration()) {
		self.configuration = configuration
	}

	func respond<Content, Context>(
		to prompt: Transcript<Context>.Prompt,
		generating type: Content.Type,
		generations: [SimulatedGeneration<Content>],
	) -> AsyncThrowingStream<AgentUpdate<Context>, any Error>
		where Content: MockableGenerable, Context: PromptContextSource {
		let setup = AsyncThrowingStream<AgentUpdate<Context>, any Error>.makeStream()

		// Log the start of a simulated run for visibility
		AgentLog.start(
			model: "simulated",
			toolNames: generations.compactMap(\.toolName),
			promptPreview: prompt.input,
		)

		let task = Task<Void, Never> {
			do {
				for (index, generation) in generations.enumerated() {
					AgentLog.stepRequest(step: index + 1)
					try await Task.sleep(for: configuration.generationDelay)

					switch generation {
					case let .reasoning(summary):
						try await handleReasoning(
							summary: summary,
							continuation: setup.continuation,
						)
					case let .toolRun(tool):
						try await handleToolRun(
							tool,
							continuation: setup.continuation,
						)
					case let .response(content):
						if let content = content as? String {
							try await handleStringResponse(content, continuation: setup.continuation)
						} else {
							try await handleStructuredResponse(content, continuation: setup.continuation)
						}
					}
				}
			} catch {
				// Surface a clear, user-friendly message
				AgentLog.error(error, context: "respond")
				setup.continuation.finish(throwing: error)
			}

			AgentLog.finish()

			if let usage = configuration.tokenUsage {
				AgentLog.tokenUsage(
					inputTokens: usage.inputTokens,
					outputTokens: usage.outputTokens,
					totalTokens: usage.totalTokens,
					cachedTokens: usage.cachedTokens,
					reasoningTokens: usage.reasoningTokens,
				)
				setup.continuation.yield(.tokenUsage(usage))
			}

			setup.continuation.finish()
		}

		setup.continuation.onTermination = { _ in
			task.cancel()
		}

		return setup.stream
	}

	private func handleReasoning<Context>(
		summary: String,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let entryData = Transcript<Context>.Reasoning(
			id: UUID().uuidString,
			summary: [summary],
			encryptedReasoning: "",
			status: .completed,
		)

		AgentLog.reasoning(summary: [summary])

		let entry = Transcript<Context>.Entry.reasoning(entryData)
		continuation.yield(.transcript(entry))
	}

	private func handleToolRun<Context>(
		_ toolMock: some MockableAgentTool,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let callId = UUID().uuidString
		let argumentsJSON = try toolMock.mockArguments().jsonString()
		let arguments = try GeneratedContent(json: argumentsJSON)

		let toolCall = Transcript<Context>.ToolCall(
			id: UUID().uuidString,
			callId: callId,
			toolName: toolMock.tool.name,
			arguments: arguments,
			status: .completed,
		)

		AgentLog.toolCall(
			name: toolMock.tool.name,
			callId: callId,
			argumentsJSON: argumentsJSON,
		)

		continuation.yield(.transcript(.toolCalls(Transcript.ToolCalls(calls: [toolCall]))))

		do {
			let output = try await toolMock.mockOutput()

			let toolOutputEntry = Transcript<Context>.ToolOutput(
				id: UUID().uuidString,
				callId: callId,
				toolName: toolMock.tool.name,
				segment: .structure(AgentTranscript.StructuredSegment(content: output)),
				status: .completed,
			)

			let transcriptEntry = Transcript<Context>.Entry.toolOutput(toolOutputEntry)

			// Try to log as JSON if possible
			AgentLog.toolOutput(
				name: toolMock.tool.name,
				callId: callId,
				outputJSONOrText: output.generatedContent.jsonString,
			)

			continuation.yield(.transcript(transcriptEntry))
		} catch let recoverableError as RecoverableToolError {
			let toolOutputEntry = Transcript<Context>.ToolOutput(
				id: UUID().uuidString,
				callId: callId,
				toolName: toolMock.tool.name,
				segment: .structure(
					AgentTranscript.StructuredSegment(
						content: recoverableError.generatedContent
					)
				),
				status: .completed,
			)

			let transcriptEntry = Transcript<Context>.Entry.toolOutput(toolOutputEntry)

			AgentLog.toolOutput(
				name: toolMock.tool.name,
				callId: callId,
				outputJSONOrText: recoverableError.generatedContent.jsonString,
			)

			continuation.yield(.transcript(transcriptEntry))
		} catch {
			AgentLog.error(error, context: "tool_call_failed_\(toolMock.tool.name)")
			throw AgentToolCallError(tool: toolMock.tool, underlyingError: error)
		}
	}

	private func handleStringResponse<Context>(
		_ content: String,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let response = Transcript<Context>.Response(
			id: UUID().uuidString,
			segments: [.text(Transcript.TextSegment(content: content))],
			status: .completed,
		)

		AgentLog.outputMessage(text: content, status: "completed")
		continuation.yield(.transcript(.response(response)))
	}

	private func handleStructuredResponse<Context>(
		_ content: some MockableGenerable,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let generatedContent = GeneratedContent(content)

		let response = Transcript<Context>.Response(
			id: UUID().uuidString,
			segments: [.structure(Transcript.StructuredSegment(content: content))],
			status: .completed,
		)

		AgentLog.outputStructured(json: generatedContent.jsonString, status: "completed")
		continuation.yield(.transcript(.response(response)))
	}
}
