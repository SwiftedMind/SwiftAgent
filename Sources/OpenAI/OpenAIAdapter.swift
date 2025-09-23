// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

public final class OpenAIAdapter: AgentAdapter {
	public typealias Model = OpenAIModel
	public typealias Transcript<Context: PromptContextSource> = AgentTranscript<Context>
	public typealias ConfigurationError = OpenAIGenerationOptionsError

	private var tools: [any AgentTool]
	private var instructions: String = ""
	private let httpClient: HTTPClient
	private let responsesPath: String

	public init(
		tools: [any AgentTool],
		instructions: String,
		configuration: OpenAIConfiguration,
	) {
		self.tools = tools
		self.instructions = instructions
		httpClient = configuration.httpClient
		responsesPath = configuration.responsesPath
	}

	public func respond<Context>(
		to prompt: Transcript<Context>.Prompt,
		generating type: (some Generable).Type,
		using model: Model = .default,
		including transcript: Transcript<Context>,
		options: OpenAIGenerationOptions,
	) -> AsyncThrowingStream<AgentUpdate<Context>, any Error> where Context: PromptContextSource {
		let setup = AsyncThrowingStream<AgentUpdate<Context>, any Error>.makeStream()

		// Log start of an agent run
		AgentLog.start(
			model: String(describing: model),
			toolNames: tools.map(\.name),
			promptPreview: prompt.input,
		)

		let task = Task<Void, Never> {
			// Validate configuration before creating request
			do {
				try options.validate(for: model)
			} catch {
				AgentLog.error(error, context: "Invalid generation options")
				setup.continuation.finish(throwing: error)
			}

			// Run the agent
			do {
				try await run(
					transcript: transcript,
					generating: type,
					using: model,
					options: options,
					continuation: setup.continuation,
				)
			} catch {
				// Surface a clear, user-friendly message
				AgentLog.error(error, context: "agent response")
				setup.continuation.finish(throwing: error)
			}

			setup.continuation.finish()
		}

		setup.continuation.onTermination = { _ in
			task.cancel()
		}

		return setup.stream
	}

	private func run<Context>(
		transcript: Transcript<Context>,
		generating type: (some Generable).Type,
		using model: Model = .default,
		options: GenerationOptions,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		var generatedTranscript = Transcript<Context>()
		let allowedSteps = 20
		var currentStep = 0

		for _ in 0..<allowedSteps {
			currentStep += 1
			AgentLog.stepRequest(step: currentStep)

			let request = try request(
				including: Transcript<Context>(entries: transcript.entries + generatedTranscript.entries),
				generating: type,
				using: model,
				options: options,
			)

			try Task.checkCancellation()

			// Call provider backend
			let response = try await httpClient.send(
				path: responsesPath,
				method: .post,
				queryItems: nil,
				headers: nil,
				body: request,
				responseType: ResponseObject.self,
			)

			// Emit token usage if available
			if let usage = response.usage {
				let reported = TokenUsage(
					inputTokens: Int(usage.inputTokens),
					outputTokens: Int(usage.outputTokens),
					totalTokens: Int(usage.totalTokens),
					cachedTokens: Int(usage.inputTokensDetails.cachedTokens),
					reasoningTokens: Int(usage.outputTokensDetails.reasoningTokens),
				)
				AgentLog.tokenUsage(
					inputTokens: reported.inputTokens,
					outputTokens: reported.outputTokens,
					totalTokens: reported.totalTokens,
					cachedTokens: reported.cachedTokens,
					reasoningTokens: reported.reasoningTokens,
				)
				continuation.yield(.tokenUsage(reported))
			}

			for output in response.output {
				try await handleOutput(
					output,
					type: type,
					generatedTranscript: &generatedTranscript,
					continuation: continuation,
				)
			}

			let outputFunctionCalls = response.output.compactMap { output -> Components.Schemas.FunctionToolCall? in
				guard case let .functionToolCall(functionCall) = output else { return nil }

				return functionCall
			}

			if outputFunctionCalls.isEmpty {
				AgentLog.finish()
				continuation.finish()
				return
			}
		}
	}

	private func handleOutput<Context>(
		_ output: OutputItem,
		type: (some Generable).Type,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		switch output {
		case let .outputMessage(message):
			try await handleMessage(
				message,
				type: type,
				generatedTranscript: &generatedTranscript,
				continuation: continuation,
			)
		case let .functionToolCall(functionCall):
			try await handleFunctionCall(
				functionCall,
				generatedTranscript: &generatedTranscript,
				continuation: continuation,
			)
		case let .reasoning(reasoning):
			try await handleReasoning(
				reasoning,
				generatedTranscript: &generatedTranscript,
				continuation: continuation,
			)
		default:
			Logger.main.warning("Unsupported output received: \(String(describing: output), privacy: .public)")
		}
	}

	private func handleMessage<Context>(
		_ message: Components.Schemas.OutputMessage,
		type: (some Generable).Type,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		if type == String.self {
			try await processStringResponse(
				message,
				generatedTranscript: &generatedTranscript,
				continuation: continuation,
			)
		} else {
			try await processStructuredResponse(
				message,
				type: type,
				generatedTranscript: &generatedTranscript,
				continuation: continuation,
			)
		}
	}

	private func processStringResponse<Context>(
		_ message: Components.Schemas.OutputMessage,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let expectedTypeName = String(describing: String.self)
		let status: Transcript<Context>.Status = transcriptStatusFromOpenAIStatus(message.status)

		var textFragments: [String] = []
		var refusalMessage: String?

		for content in message.content {
			switch content.extractedTextSegment {
			case let .text(text):
				textFragments.append(text)
			case let .refusal(reason):
				refusalMessage = reason
			case .none:
				break
			}
		}

		if let refusalMessage {
			let refusalSegments = [Transcript<Context>.Segment.text(Transcript.TextSegment(content: refusalMessage))]
			let refusalResponse = Transcript<Context>.Response(
				id: message.id,
				segments: refusalSegments,
				status: status,
			)

			AgentLog.outputMessage(text: refusalMessage, status: String(describing: message.status))

			generatedTranscript.append(.response(refusalResponse))
			continuation.yield(.transcript(.response(refusalResponse)))

			let errorContext = AgentGenerationError.ContentRefusalContext(expectedType: expectedTypeName, reason: refusalMessage)
			throw AgentGenerationError.contentRefusal(errorContext)
		}

		guard !textFragments.isEmpty else {
			let errorContext = AgentGenerationError.EmptyMessageContentContext(expectedType: expectedTypeName)
			throw AgentGenerationError.emptyMessageContent(errorContext)
		}

		let responseSegments = textFragments.map { fragment in
			Transcript<Context>.Segment.text(Transcript.TextSegment(content: fragment))
		}
		let response = Transcript<Context>.Response(
			id: message.id,
			segments: responseSegments,
			status: status,
		)

		let joinedText = textFragments.joined(separator: "\n")
		AgentLog.outputMessage(text: joinedText, status: String(describing: message.status))

		generatedTranscript.append(.response(response))
		continuation.yield(.transcript(.response(response)))
	}

	private func processStructuredResponse<Context>(
		_ message: Components.Schemas.OutputMessage,
		type: (some Generable).Type,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let expectedTypeName = String(describing: type)
		let status: Transcript<Context>.Status = transcriptStatusFromOpenAIStatus(message.status)

		var aggregatedFragments: [String] = []
		var refusalMessage: String?

		for content in message.content {
			switch content {
			case let .OutputTextContent(textContent):
				aggregatedFragments.append(textContent.text)
			case let .RefusalContent(refusal):
				refusalMessage = refusal.refusal
			}
		}

		if let refusalMessage {
			let refusalResponse = Transcript<Context>.Response(
				id: message.id,
				segments: [.text(Transcript.TextSegment(content: refusalMessage))],
				status: status,
			)

			AgentLog.outputMessage(text: refusalMessage, status: String(describing: message.status))

			generatedTranscript.append(.response(refusalResponse))
			continuation.yield(.transcript(.response(refusalResponse)))

			let errorContext = AgentGenerationError.ContentRefusalContext(expectedType: expectedTypeName, reason: refusalMessage)
			throw AgentGenerationError.contentRefusal(errorContext)
		}

		guard !aggregatedFragments.isEmpty else {
			let errorContext = AgentGenerationError.EmptyMessageContentContext(expectedType: expectedTypeName)
			throw AgentGenerationError.emptyMessageContent(errorContext)
		}

		let combinedJSON = aggregatedFragments.joined()

		do {
			let generatedContent = try GeneratedContent(json: combinedJSON)
			let response = Transcript<Context>.Response(
				id: message.id,
				segments: [.structure(Transcript.StructuredSegment(content: generatedContent))],
				status: status,
			)

			AgentLog.outputStructured(json: combinedJSON, status: String(describing: message.status))

			generatedTranscript.append(.response(response))
			continuation.yield(.transcript(.response(response)))
		} catch {
			AgentLog.error(error, context: "structured_response_parsing")
			let errorContext = AgentGenerationError.StructuredContentParsingFailedContext(
				rawContent: combinedJSON,
				underlyingError: error,
			)
			throw AgentGenerationError.structuredContentParsingFailed(errorContext)
		}
	}

	private func handleFunctionCall<Context>(
		_ functionCall: Components.Schemas.FunctionToolCall,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let generatedContent = try GeneratedContent(json: functionCall.arguments)

		let toolCall = Transcript<Context>.ToolCall(
			id: functionCall.id ?? UUID().uuidString,
			callId: functionCall.callId,
			toolName: functionCall.name,
			arguments: generatedContent,
			status: transcriptStatusFromOpenAIStatus(functionCall.status),
		)

		AgentLog.toolCall(
			name: functionCall.name,
			callId: functionCall.callId,
			argumentsJSON: functionCall.arguments,
		)

		generatedTranscript.entries.append(.toolCalls(Transcript.ToolCalls(calls: [toolCall])))
		continuation.yield(.transcript(.toolCalls(Transcript.ToolCalls(calls: [toolCall]))))

		guard let tool = tools.first(where: { $0.name == functionCall.name }) else {
			AgentLog.error(
				AgentGenerationError.unsupportedToolCalled(.init(toolName: functionCall.name)),
				context: "tool_not_found",
			)
			let errorContext = AgentGenerationError.UnsupportedToolCalledContext(toolName: functionCall.name)
			throw AgentGenerationError.unsupportedToolCalled(errorContext)
		}

		do {
			let output = try await callTool(tool, with: generatedContent)

			let toolOutputEntry = Transcript<Context>.ToolOutput(
				id: functionCall.id ?? UUID().uuidString,
				callId: functionCall.callId,
				toolName: functionCall.name,
				segment: .structure(AgentTranscript.StructuredSegment(content: output)),
				status: transcriptStatusFromOpenAIStatus(functionCall.status),
			)

			let transcriptEntry = Transcript<Context>.Entry.toolOutput(toolOutputEntry)

			// Try to log as JSON if possible
			AgentLog.toolOutput(
				name: tool.name,
				callId: functionCall.callId,
				outputJSONOrText: output.generatedContent.jsonString,
			)

			generatedTranscript.entries.append(transcriptEntry)
			continuation.yield(.transcript(transcriptEntry))
		} catch let toolRunProblem as ToolRunProblem {
			let toolOutputEntry = Transcript<Context>.ToolOutput(
				id: functionCall.id ?? UUID().uuidString,
				callId: functionCall.callId,
				toolName: functionCall.name,
				segment: .structure(AgentTranscript.StructuredSegment(content: toolRunProblem.generatedContent)),
				status: transcriptStatusFromOpenAIStatus(functionCall.status),
			)

			let transcriptEntry = Transcript<Context>.Entry.toolOutput(toolOutputEntry)

			AgentLog.toolOutput(
				name: tool.name,
				callId: functionCall.callId,
				outputJSONOrText: toolRunProblem.generatedContent.jsonString,
			)

			generatedTranscript.entries.append(transcriptEntry)
			continuation.yield(.transcript(transcriptEntry))
		} catch {
			AgentLog.error(error, context: "tool_call_failed_\(tool.name)")
			throw ToolRunError(tool: tool, underlyingError: error)
		}
	}

	private func handleReasoning<Context>(
		_ reasoning: Components.Schemas.ReasoningItem,
		generatedTranscript: inout Transcript<Context>,
		continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation,
	) async throws where Context: PromptContextSource {
		let summary = reasoning.summary.map { summary in
			summary.text
		}

		let entryData = Transcript<Context>.Reasoning(
			id: reasoning.id,
			summary: summary,
			encryptedReasoning: reasoning.encryptedContent,
			status: transcriptStatusFromOpenAIStatus(reasoning.status),
		)

		AgentLog.reasoning(summary: summary)

		let entry = Transcript<Context>.Entry.reasoning(entryData)
		generatedTranscript.entries.append(entry)
		continuation.yield(.transcript(entry))
	}

	private func callTool<T: FoundationModels.Tool>(
		_ tool: T,
		with generatedContent: GeneratedContent,
	) async throws -> T.Output where T.Output: ConvertibleToGeneratedContent {
		let arguments = try T.Arguments(generatedContent)
		return try await tool.call(arguments: arguments)
	}

	private func request(
		including transcript: Transcript<some PromptContextSource>,
		generating type: (some Generable).Type,
		using model: Model,
		options: GenerationOptions,
	) throws -> CreateModelResponseQuery {
		let textConfig: CreateModelResponseQuery.TextResponseConfigurationOptions? = {
			if type == String.self {
				return nil
			}

			let config = CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat.StructuredOutputsConfig(
				name: snakeCaseName(for: type),
				schema: .dynamicJsonSchema(type.generationSchema),
				description: nil,
				strict: false,
			)

			return CreateModelResponseQuery.TextResponseConfigurationOptions.jsonSchema(config)
		}()

		return try CreateModelResponseQuery(
			input: .inputItemList(transcriptToListItems(transcript)),
			model: model.rawValue,
			include: options.include,
			background: nil,
			instructions: instructions,
			maxOutputTokens: options.maxOutputTokens,
			metadata: nil,
			parallelToolCalls: options.allowParallelToolCalls,
			previousResponseId: nil,
			prompt: nil,
			reasoning: options.reasoning,
			serviceTier: options.serviceTier,
			store: false,
			stream: nil,
			temperature: options.temperature,
			text: textConfig,
			toolChoice: options.toolChoice,
			tools: tools.map { tool in
				try .functionTool(
					FunctionTool(
						name: tool.name,
						description: tool.description,
						parameters: tool.parameters.asJSONSchema(),
						strict: false, // GenerationSchema doesn't produce a compliant strict schema for OpenAI
					),
				)
			},
			topP: options.topP,
			truncation: options.truncation,
			user: options.safetyIdentifier,
		)
	}

	// MARK: - Helpers

	private func transcriptStatusFromOpenAIStatus<Context>(
		_ status: Components.Schemas.OutputMessage.StatusPayload,
	) -> Transcript<Context>.Status where Context: PromptContextSource {
		switch status {
		case .completed: .completed
		case .incomplete: .incomplete
		case .inProgress: .inProgress
		}
	}

	private func transcriptStatusFromOpenAIStatus<Context>(
		_ status: Components.Schemas.FunctionToolCall.StatusPayload?,
	) -> Transcript<Context>.Status? where Context: PromptContextSource {
		guard let status else {
			return nil
		}

		switch status {
		case .completed: return .completed
		case .incomplete: return .incomplete
		case .inProgress: return .inProgress
		}
	}

	private func transcriptStatusFromOpenAIStatus<Context>(
		_ status: Components.Schemas.ReasoningItem.StatusPayload?,
	) -> Transcript<Context>.Status? where Context: PromptContextSource {
		guard let status else {
			return nil
		}

		switch status {
		case .completed: return .completed
		case .incomplete: return .incomplete
		case .inProgress: return .inProgress
		}
	}

	private func transcriptStatusToMessageStatus(
		_ status: Transcript<some PromptContextSource>.Status,
	) -> Components.Schemas.OutputMessage.StatusPayload {
		switch status {
		case .completed: .completed
		case .incomplete: .incomplete
		case .inProgress: .inProgress
		}
	}

	private func transcriptStatusToFunctionCallStatus(
		_ status: Transcript<some PromptContextSource>.Status?,
	) -> Components.Schemas.FunctionToolCall.StatusPayload? {
		guard let status else {
			return nil
		}

		switch status {
		case .completed: return .completed
		case .incomplete: return .incomplete
		case .inProgress: return .inProgress
		}
	}

	private func transcriptStatusToFunctionCallOutputStatus(
		_ status: Transcript<some PromptContextSource>.Status?,
	) -> Components.Schemas.FunctionCallOutputItemParam.StatusPayload? {
		guard let status else {
			return nil
		}

		switch status {
		case .completed: return .init(value1: .completed)
		case .incomplete: return .init(value1: .incomplete)
		case .inProgress: return .init(value1: .inProgress)
		}
	}

	private func transcriptStatusToReasoningStatus(
		_ status: Transcript<some PromptContextSource>.Status?,
	) -> Components.Schemas.ReasoningItem.StatusPayload? {
		guard let status else {
			return nil
		}

		switch status {
		case .completed: return .completed
		case .incomplete: return .incomplete
		case .inProgress: return .inProgress
		}
	}

	func transcriptToListItems(_ transcript: Transcript<some PromptContextSource>) -> [InputItem] {
		var listItems: [InputItem] = []

		for entry in transcript {
			switch entry {
			case let .prompt(prompt):
				listItems.append(InputItem.inputMessage(EasyInputMessage(
					role: .user,
					content: .textInput(prompt.embeddedPrompt),
				)))
			case let .reasoning(reasoning):
				let item = Components.Schemas.ReasoningItem(
					_type: .reasoning,
					id: reasoning.id,
					encryptedContent: reasoning.encryptedReasoning,
					summary: [],
					status: transcriptStatusToReasoningStatus(reasoning.status),
				)

				listItems.append(InputItem.item(.reasoningItem(item)))
			case let .toolCalls(toolCalls):
				for toolCall in toolCalls {
					let item = Components.Schemas.FunctionToolCall(
						id: toolCall.id,
						_type: .functionCall,
						callId: toolCall.callId,
						name: toolCall.toolName,
						arguments: toolCall.arguments.jsonString,
						status: transcriptStatusToFunctionCallStatus(toolCall.status),
					)

					listItems.append(InputItem.item(.functionToolCall(item)))
				}
			case let .toolOutput(toolOutput):
				let output: String = switch toolOutput.segment {
				case let .text(textSegment):
					textSegment.content
				case let .structure(structuredSegment):
					structuredSegment.content.generatedContent.jsonString
				}

				let item = Components.Schemas.FunctionCallOutputItemParam(
					id: .init(value1: toolOutput.id),
					callId: toolOutput.callId,
					_type: .functionCallOutput,
					output: output,
					status: transcriptStatusToFunctionCallOutputStatus(toolOutput.status),
				)

				listItems.append(InputItem.item(.functionCallOutputItemParam(item)))
			case let .response(response):
				let item = Components.Schemas.OutputMessage(
					id: response.id,
					_type: .message,
					role: .assistant,
					content: response.segments.compactMap { segment in
						switch segment {
						case let .text(textSegment):
							Components.Schemas.OutputContent
								.OutputTextContent(
									Components.Schemas.OutputTextContent(
										_type: .outputText,
										text: textSegment.content,
										annotations: [],
									),
								)
						case let .structure(structuredSegment):
							Components.Schemas.OutputContent
								.OutputTextContent(
									Components.Schemas.OutputTextContent(
										_type: .outputText,
										text: structuredSegment.content.generatedContent.jsonString,
										annotations: [],
									),
								)
						}
					},
					status: transcriptStatusToMessageStatus(response.status),
				)

				listItems.append(InputItem.item(.outputMessage(item)))
			}
		}

		return listItems
	}
}
