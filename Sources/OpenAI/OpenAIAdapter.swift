// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

public actor OpenAIAdapter: Adapter {
  public typealias Model = OpenAIModel
  public typealias Transcript = SwiftAgent.Transcript
  public typealias ConfigurationError = OpenAIGenerationOptionsError

  public nonisolated let tools: [any SwiftAgentTool]
  package let instructions: String
  package let httpClient: HTTPClient
  package let responsesPath: String = "/v1/responses"

  public init(
    tools: [any SwiftAgentTool],
    instructions: String,
    configuration: OpenAIConfiguration,
  ) {
    self.tools = tools
    self.instructions = instructions
    httpClient = configuration.httpClient
  }

  public func respond(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: Model = .default,
    including transcript: Transcript,
    options: OpenAIGenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    let setup = AsyncThrowingStream<AdapterUpdate, any Error>.makeStream()

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
        return
      }

      setup.continuation.finish()
    }

    setup.continuation.onTermination = { _ in
      task.cancel()
    }

    return setup.stream
  }

  private func run(
    transcript: Transcript,
    generating type: (some StructuredOutput).Type?,
    using model: Model = .default,
    options: OpenAIGenerationOptions,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    var generatedTranscript = Transcript()
    let allowedSteps = 20
    var currentStep = 0

    for _ in 0..<allowedSteps {
      try Task.checkCancellation()
      currentStep += 1
      AgentLog.stepRequest(step: currentStep)

      let request = try responseQuery(
        including: Transcript(entries: transcript.entries + generatedTranscript.entries),
        generating: type,
        using: model,
        options: options,
      )

      try Task.checkCancellation()

      // Call provider backend
      let response: ResponseObject
      do {
        response = try await httpClient.send(
          path: responsesPath,
          method: .post,
          queryItems: nil,
          headers: nil,
          body: request,
          responseType: ResponseObject.self,
        )
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw GenerationError.fromRequest(error, httpErrorMapper: GenerationError.from)
      }

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
        try Task.checkCancellation()
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

  private func handleOutput(
    _ output: OutputItem,
    type: (some StructuredOutput).Type?,
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
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

  private func handleMessage(
    _ message: Components.Schemas.OutputMessage,
    type: (some StructuredOutput).Type?,
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let structuredOutputTypeName = type?.name

    let expectedContentDescription = structuredOutputTypeName ?? "String"
    let status: Transcript.Status = transcriptStatusFromOpenAIStatus(message.status)

    var fragments: [String] = []
    var refusalMessage: String?

    for content in message.content {
      switch content {
      case let .OutputTextContent(textContent):
        fragments.append(textContent.text)
      case let .RefusalContent(refusal):
        refusalMessage = refusal.refusal
      }
    }

    if let refusalMessage {
      let refusalSegments: [Transcript.Segment] = [
        .text(.init(content: refusalMessage)),
      ]
      let refusalResponse = Transcript.Response(
        id: message.id,
        segments: refusalSegments,
        status: status,
      )

      AgentLog.outputMessage(text: refusalMessage, status: String(describing: message.status))
      generatedTranscript.append(.response(refusalResponse))
      continuation.yield(.transcript(.response(refusalResponse)))

      throw GenerationError.contentRefusal(.init(expectedType: expectedContentDescription, reason: refusalMessage))
    }

    guard !fragments.isEmpty else {
      throw GenerationError.emptyMessageContent(.init(expectedType: expectedContentDescription))
    }

    let response: Transcript.Response

    if let type {
      let combinedJSON = fragments.joined()
      do {
        let generatedContent = try GeneratedContent(json: combinedJSON)
        AgentLog.outputStructured(json: combinedJSON, status: String(describing: message.status))

        response = Transcript.Response(
          id: message.id,
          segments: [.structure(.init(typeName: structuredOutputTypeName ?? type.name, content: generatedContent))],
          status: status,
        )
      } catch {
        AgentLog.error(error, context: "structured_response_parsing")
        throw GenerationError.structuredContentParsingFailed(
          .init(rawContent: combinedJSON, underlyingError: error),
        )
      }
    } else {
      let joinedText = fragments.joined(separator: "\n")
      AgentLog.outputMessage(text: joinedText, status: String(describing: message.status))

      response = Transcript.Response(
        id: message.id,
        segments: fragments.map { .text(.init(content: $0)) },
        status: status,
      )
    }

    generatedTranscript.append(.response(response))
    continuation.yield(.transcript(.response(response)))
  }

  private func handleFunctionCall(
    _ functionCall: Components.Schemas.FunctionToolCall,
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let generatedContent = try GeneratedContent(json: functionCall.arguments)

    let toolCall = Transcript.ToolCall(
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
        GenerationError.unsupportedToolCalled(.init(toolName: functionCall.name)),
        context: "tool_not_found",
      )
      let errorContext = GenerationError.UnsupportedToolCalledContext(toolName: functionCall.name)
      throw GenerationError.unsupportedToolCalled(errorContext)
    }

    do {
      let output = try await callTool(tool, with: generatedContent)

      let toolOutputEntry = Transcript.ToolOutput(
        id: functionCall.id ?? UUID().uuidString,
        callId: functionCall.callId,
        toolName: functionCall.name,
        segment: .structure(Transcript.StructuredSegment(content: output)),
        status: transcriptStatusFromOpenAIStatus(functionCall.status),
      )

      let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)

      // Try to log as JSON if possible
      AgentLog.toolOutput(
        name: tool.name,
        callId: functionCall.callId,
        outputJSONOrText: output.generatedContent.jsonString,
      )

      generatedTranscript.entries.append(transcriptEntry)
      continuation.yield(.transcript(transcriptEntry))
    } catch let toolRunRejection as ToolRunRejection {
      let toolOutputEntry = Transcript.ToolOutput(
        id: functionCall.id ?? UUID().uuidString,
        callId: functionCall.callId,
        toolName: functionCall.name,
        segment: .structure(Transcript.StructuredSegment(content: toolRunRejection.generatedContent)),
        status: transcriptStatusFromOpenAIStatus(functionCall.status),
      )

      let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)

      AgentLog.toolOutput(
        name: tool.name,
        callId: functionCall.callId,
        outputJSONOrText: toolRunRejection.generatedContent.jsonString,
      )

      generatedTranscript.entries.append(transcriptEntry)
      continuation.yield(.transcript(transcriptEntry))
    } catch {
      AgentLog.error(error, context: "tool_call_failed_\(tool.name)")
      throw GenerationError.toolExecutionFailed(toolName: tool.name, underlyingError: error)
    }
  }

  private func handleReasoning(
    _ reasoning: Components.Schemas.ReasoningItem,
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let summary = reasoning.summary.map { summary in
      summary.text
    }

    let entryData = Transcript.Reasoning(
      id: reasoning.id,
      summary: summary,
      encryptedReasoning: reasoning.encryptedContent,
      status: transcriptStatusFromOpenAIStatus(reasoning.status),
    )

    AgentLog.reasoning(summary: summary)

    let entry = Transcript.Entry.reasoning(entryData)
    generatedTranscript.entries.append(entry)
    continuation.yield(.transcript(entry))
  }

  func callTool<T: FoundationModels.Tool>(
    _ tool: T,
    with generatedContent: GeneratedContent,
  ) async throws -> T.Output where T.Output: ConvertibleToGeneratedContent {
    let arguments = try T.Arguments(generatedContent)
    return try await tool.call(arguments: arguments)
  }

  func responseQuery(
    including transcript: Transcript,
    generating type: (some StructuredOutput).Type?,
    using model: Model,
    options: OpenAIGenerationOptions,
    streamResponses: Bool = false,
  ) throws -> CreateModelResponseQuery {
    let textConfig: CreateModelResponseQuery.TextResponseConfigurationOptions? = {
      guard let type else {
        return nil
      }

      let config = CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat.StructuredOutputsConfig(
        name: type.name,
        schema: .dynamicJsonSchema(type.Schema.generationSchema),
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
      stream: streamResponses ? true : nil,
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

  private func transcriptStatusFromOpenAIStatus(
    _ status: Components.Schemas.OutputMessage.StatusPayload,
  ) -> Transcript.Status {
    switch status {
    case .completed: .completed
    case .incomplete: .incomplete
    case .inProgress: .inProgress
    }
  }

  private func transcriptStatusFromOpenAIStatus(
    _ status: Components.Schemas.FunctionToolCall.StatusPayload?,
  ) -> Transcript.Status? {
    guard let status else {
      return nil
    }

    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusFromOpenAIStatus(
    _ status: Components.Schemas.ReasoningItem.StatusPayload?,
  ) -> Transcript.Status? {
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
    _ status: Transcript.Status,
  ) -> Components.Schemas.OutputMessage.StatusPayload {
    switch status {
    case .completed: .completed
    case .incomplete: .incomplete
    case .inProgress: .inProgress
    }
  }

  private func transcriptStatusToFunctionCallStatus(
    _ status: Transcript.Status?,
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
    _ status: Transcript.Status?,
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
    _ status: Transcript.Status?,
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

  func transcriptToListItems(_ transcript: Transcript) -> [InputItem] {
    var listItems: [InputItem] = []

    for entry in transcript {
      switch entry {
      case let .prompt(prompt):
        listItems.append(InputItem.inputMessage(EasyInputMessage(
          role: .user,
          content: .textInput(prompt.prompt),
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
