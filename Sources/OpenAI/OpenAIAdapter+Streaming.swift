// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import SwiftAgent

extension OpenAIAdapter {
	public func streamResponse<Context>(
		to prompt: Transcript<Context>.Prompt,
		generating type: (some Generable).Type,
		using model: Model = .default,
		including transcript: Transcript<Context>,
		options: OpenAIGenerationOptions
	) -> AsyncThrowingStream<AdapterUpdate<Context>, any Error> where Context: PromptContextSource {
		let setup = AsyncThrowingStream<AdapterUpdate<Context>, any Error>.makeStream()

		AgentLog.start(
			model: String(describing: model),
			toolNames: tools.map(\.name),
			promptPreview: prompt.input
		)

		let task = Task<Void, Never> {
			do {
				try options.validate(for: model)
			} catch {
				AgentLog.error(error, context: "Invalid generation options")
				setup.continuation.finish(throwing: error)
				return
			}

			do {
				try await runStreamResponse(
					transcript: transcript,
					generating: type,
					using: model,
					options: options,
					continuation: setup.continuation
				)
			} catch {
				AgentLog.error(error, context: "streaming response")
				setup.continuation.finish(throwing: error)
				return
			}

			setup.continuation.finish()
		}

		setup.continuation.onTermination = { _ in
			task.cancel()
		}

		return setup.stream
	}

	private func runStreamResponse<Context>(
		transcript: Transcript<Context>,
		generating type: (some Generable).Type,
		using model: Model,
		options: OpenAIGenerationOptions,
		continuation: AsyncThrowingStream<AdapterUpdate<Context>, any Error>.Continuation
	) async throws where Context: PromptContextSource {
		
		// Place to keep track of in-progress output items whose deltas are still streaming in
		var inProgressOutputItems: [String: OutputItem] = [:]

		var generatedTranscript = Transcript<Context>()
		let allowedSteps = 20
		var currentStep = 0
		
		for _ in 0..<allowedSteps {
			currentStep += 1
			AgentLog.stepRequest(step: currentStep)
			
			let request = try responseQuery(
				including: Transcript<Context>(entries: transcript.entries + generatedTranscript.entries),
				generating: type,
				using: model,
				options: options,
				streamResponses: true
			)
			
			let eventStream = httpClient.stream(
				path: responsesPath,
				method: .post,
				headers: [:],
				body: request
			)
			
			let decoder = OpenAIResponseStreamEventDecoder()
			
			for try await event in eventStream {
				guard let decodedEvent = try decoder.decodeEvent(from: event) else { continue }
				
				switch decodedEvent {
				case let .created(responseEvent):
					break
				case let .inProgress(responseEvent):
					break
				case let .completed(responseEvent):
					break
				case let .failed(responseEvent):
					break
				case let .incomplete(responseEvent):
					break
				case let .queued(responseEvent):
					continue
				case let .outputItem(outputItemEvent):
					switch outputItemEvent {
					case let .added(addedEvent):
						try await handleOutputAdded(
							addedEvent.item,
							type: type,
							generatedTranscript: &generatedTranscript,
							continuation: continuation
						)
					case let .done(doneEvent):
						break
					}
				case let .contentPart(contentPartEvent):
					continue
				case let .outputText(outputTextEvent):
					break
				case let .audio(audioEvent):
					continue
				case let .audioTranscript(audioTranscriptEvent):
					continue
				case let .codeInterpreterCall(codeInterpreterCallEvent):
					continue
				case let .error(responseErrorEvent):
					break
				case let .fileSearchCall(fileSearchCallEvent):
					continue
				case let .functionCallArguments(functionCallArgumentsEvent):
					break
				case let .refusal(refusalEvent):
					break
				case let .webSearchCall(webSearchCallEvent):
					continue
				case let .reasoningSummaryPart(reasoningSummaryPartEvent):
					break
				case let .reasoningSummaryText(reasoningSummaryTextEvent):
					break
				case let .imageGenerationCall(imageGenerationCallEvent):
					continue
				case let .mcpCall(mCPCallEvent):
					continue
				case let .mcpCallArguments(mCPCallArgumentsEvent):
					continue
				case let .mcpListTools(mCPListToolsEvent):
					continue
				case let .outputTextAnnotation(outputTextAnnotationEvent):
					continue
				case let .reasoning(reasoningEvent):
					break
				case let .reasoningSummary(reasoningSummaryEvent):
					break
				}
			}
			
			// TODO: yield token usage somehow
			// TODO: Handle loop stop logic (when no tool call happened in the response)
		}
	}

	private func handleOutputAdded<Context>(
		_ output: OutputItem,
		type: (some Generable).Type,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AdapterUpdate<Context>, any Error>.Continuation
	) async throws where Context: PromptContextSource {
		switch output {
		case let .outputMessage(message):
			break
		case let .functionToolCall(functionCall):
			break
		case let .reasoning(reasoning):
		default:
			break
		}
	}
}
