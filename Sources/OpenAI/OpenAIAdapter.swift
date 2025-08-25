// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

public final class OpenAIAdapter: AgentAdapter {
  public typealias Model = OpenAI.Model
  public typealias Transcript<Context: PromptContextSource> = AgentTranscript<Context>
  public typealias ConfigurationError = OpenAIGenerationOptionsError

  private var tools: [any AgentTool]
  private var instructions: String = ""
  private let httpClient: HTTPClient
  private let responsesPath: String

  public init(
    tools: [any AgentTool],
    instructions: String,
    configuration: OpenAIConfiguration
  ) {
    self.tools = tools
    self.instructions = instructions
    httpClient = configuration.httpClient
    responsesPath = configuration.responsesPath
  }

  public func respond<Content, Context>(
    to prompt: Transcript<Context>.Prompt,
    generating type: Content.Type,
    using model: Model = .default,
    including transcript: Transcript<Context>,
    options: OpenAIGenerationOptions
  ) -> AsyncThrowingStream<AgentUpdate<Context>, any Error> where Content: Generable, Context: PromptContextSource {
    let setup = AsyncThrowingStream<AgentUpdate<Context>, any Error>.makeStream()

    // Log start of an agent run
    AgentLog.start(
      model: String(describing: model),
      toolNames: tools.map(\.name),
      promptPreview: prompt.input
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
          continuation: setup.continuation
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

  private func run<Content, Context>(
    transcript: Transcript<Context>,
    generating type: Content.Type,
    using model: Model = .default,
    options: GenerationOptions,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Content: Generable, Context: PromptContextSource {
    var generatedTranscript = Transcript<Context>()
    let allowedSteps = 20
    var currentStep = 0

    for _ in 0..<allowedSteps {
      currentStep += 1
      AgentLog.stepRequest(step: currentStep)

      let request = request(
        including: Transcript<Context>(entries: transcript.entries + generatedTranscript.entries),
        generating: type,
        using: model,
        options: options
      )

      try Task.checkCancellation()

      // Call provider backend
      let response = try await httpClient.send(
        path: responsesPath,
        method: .post,
        queryItems: nil,
        headers: nil,
        body: request,
        responseType: OpenAI.Response.self
      )
      
      // Emit token usage if available
      if let usage = response.usage {
        let reported = TokenUsage(
          inputTokens: Int(usage.inputTokens),
          outputTokens: Int(usage.outputTokens),
          totalTokens: Int(usage.totalTokens),
          cachedTokens: Int(usage.inputTokensDetails.cachedTokens),
          reasoningTokens: Int(usage.outputTokensDetails.reasoningTokens)
        )
        AgentLog.tokenUsage(
          inputTokens: reported.inputTokens,
          outputTokens: reported.outputTokens,
          totalTokens: reported.totalTokens,
          cachedTokens: reported.cachedTokens,
          reasoningTokens: reported.reasoningTokens
        )
        continuation.yield(.tokenUsage(reported))
      }

      for output in response.output {
        try await handleOutput(
          output,
          type: type,
          generatedTranscript: &generatedTranscript,
          continuation: continuation
        )
      }

      let outputFunctionCalls = response.output.compactMap { output -> Item.FunctionCall? in
        guard case let .functionCall(functionCall) = output else { return nil }

        return functionCall
      }

      if outputFunctionCalls.isEmpty {
        AgentLog.finish()
        continuation.finish()
        return
      }
    }
  }

  private func handleOutput<Content, Context>(
    _ output: Item.Output,
    type: Content.Type,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Content: Generable, Context: PromptContextSource {
    switch output {
    case let .message(message):
      try await handleMessage(
        message,
        type: type,
        generatedTranscript: &generatedTranscript,
        continuation: continuation
      )
    case let .functionCall(functionCall):
      try await handleFunctionCall(
        functionCall,
        generatedTranscript: &generatedTranscript,
        continuation: continuation
      )
    case let .reasoning(reasoning):
      try await handleReasoning(
        reasoning,
        generatedTranscript: &generatedTranscript,
        continuation: continuation
      )
    default:
      Logger.main.warning("Unsupported output received: \(String(describing: output), privacy: .public)")
    }
  }

  private func handleMessage<Content, Context>(
    _ message: Message.Output,
    type: Content.Type,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Content: Generable, Context: PromptContextSource {
    if type == String.self {
      try await processStringResponse(
        message,
        generatedTranscript: &generatedTranscript,
        continuation: continuation
      )
    } else {
      try await processStructuredResponse(
        message,
        type: type,
        generatedTranscript: &generatedTranscript,
        continuation: continuation
      )
    }
  }

  private func processStringResponse<Context>(
    _ message: Message.Output,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Context: PromptContextSource {
    let response = Transcript<Context>.Response(
      id: message.id,
      segments: message.content.compactMap(\.asText).map { .text(Transcript.TextSegment(content: $0)) },
      status: transcriptStatusFromOpenAIStatus(message.status),
    )

    let text = message.content.compactMap(\.asText).joined(separator: "\n")
    AgentLog.outputMessage(text: text, status: String(describing: message.status))

    generatedTranscript.append(.response(response))
    continuation.yield(.transcript(.response(response)))
  }

  private func processStructuredResponse<Content, Context>(
    _ message: Message.Output,
    type: Content.Type,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Content: Generable, Context: PromptContextSource {
    guard let content = message.content.first else {
      let errorContext = AgentGenerationError.EmptyMessageContentContext(expectedType: String(describing: type))
      throw AgentGenerationError.emptyMessageContent(errorContext)
    }

    switch content {
    case let .text(text, _, _):
      do {
        let generatedContent = try GeneratedContent(json: text)
        let response = Transcript<Context>.Response(
          id: message.id,
          segments: [.structure(Transcript.StructuredSegment(content: generatedContent))],
          status: transcriptStatusFromOpenAIStatus(message.status),
        )

        AgentLog.outputStructured(json: text, status: String(describing: message.status))

        generatedTranscript.append(.response(response))
        continuation.yield(.transcript(.response(response)))
      } catch {
        AgentLog.error(error, context: "structured_response_parsing")
        let errorContext = AgentGenerationError.StructuredContentParsingFailedContext(
          rawContent: text,
          underlyingError: error
        )
        throw AgentGenerationError.structuredContentParsingFailed(errorContext)
      }
    case .refusal:
      let errorContext = AgentGenerationError.ContentRefusalContext(expectedType: String(describing: type))
      throw AgentGenerationError.contentRefusal(errorContext)
    }
  }

  private func handleFunctionCall<Context>(
    _ functionCall: Item.FunctionCall,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Context: PromptContextSource {
    let generatedContent = try GeneratedContent(json: functionCall.arguments)

    let toolCall = Transcript<Context>.ToolCall(
      id: functionCall.id,
      callId: functionCall.callId,
      toolName: functionCall.name,
      arguments: generatedContent,
      status: transcriptStatusFromOpenAIStatus(functionCall.status),
    )

    AgentLog.toolCall(
      name: functionCall.name,
      callId: functionCall.callId,
      argumentsJSON: functionCall.arguments
    )

    generatedTranscript.entries.append(.toolCalls(Transcript.ToolCalls(calls: [toolCall])))
    continuation.yield(.transcript(.toolCalls(Transcript.ToolCalls(calls: [toolCall]))))

    guard let tool = tools.first(where: { $0.name == functionCall.name }) else {
      AgentLog.error(AgentGenerationError.unsupportedToolCalled(.init(toolName: functionCall.name)), context: "tool_not_found")
      let errorContext = AgentGenerationError.UnsupportedToolCalledContext(toolName: functionCall.name)
      throw AgentGenerationError.unsupportedToolCalled(errorContext)
    }

    do {
      let output = try await callTool(tool, with: generatedContent)

      let toolOutputEntry = Transcript<Context>.ToolOutput(
        id: functionCall.id,
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
        outputJSONOrText: output.generatedContent.jsonString
      )

      generatedTranscript.entries.append(transcriptEntry)
      continuation.yield(.transcript(transcriptEntry))
    } catch {
      AgentLog.error(error, context: "tool_call_failed_\(tool.name)")
      throw AgentToolCallError(tool: tool, underlyingError: error)
    }
  }

  private func handleReasoning<Context>(
    _ reasoning: Item.Reasoning,
    generatedTranscript: inout Transcript<Context>,
    continuation: AsyncThrowingStream<AgentUpdate<Context>, any Error>.Continuation
  ) async throws where Context: PromptContextSource {
    let summary = reasoning.summary.map { summary in
      switch summary {
      case let .text(text):
        return text
      }
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
    with generatedContent: GeneratedContent
  ) async throws -> T.Output where T.Output: ConvertibleToGeneratedContent {
    let arguments = try T.Arguments(generatedContent)
    return try await tool.call(arguments: arguments)
  }

  private func request<Content, Context>(
    including transcript: Transcript<Context>,
    generating type: Content.Type,
    using model: Model,
    options: GenerationOptions
  ) -> OpenAI.Request where Content: Generable, Context: PromptContextSource {
    let textConfig: TextConfig? = {
      if type == String.self {
        return nil
      }

      let format = TextConfig.Format.generationSchema(
        schema: type.generationSchema,
        name: snakeCaseName(for: type),
        strict: false
      )

      return TextConfig(format: format)
    }()

    return Request(
      model: model,
      input: .list(transcriptToListItems(transcript)),
      background: nil,
      include: options.include,
      instructions: instructions,
      maxOutputTokens: options.maxOutputTokens,
      metadata: nil,
      parallelToolCalls: options.allowParallelToolCalls,
      previousResponseId: nil,
      prompt: nil,
      promptCacheKey: options.promptCacheKey,
      reasoning: options.reasoning,
      safetyIdentifier: options.safetyIdentifier,
      serviceTier: options.serviceTier,
      store: false,
      stream: nil,
      temperature: options.temperature,
      text: textConfig,
      toolChoice: options.toolChoice,
      tools: tools.map { tool in
        .function(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
          strict: false // Important because GenerationSchema doesn't produce a compliant strict schema for OpenAI!
        )
      },
      topLogprobs: options.topLogProbs,
      topP: options.topP,
      truncation: options.truncation
    )
  }

  // MARK: - Helpers

  private func transcriptStatusFromOpenAIStatus<Context>(
    _ status: Message.Status
  ) -> Transcript<Context>.Status where Context: PromptContextSource {
    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusFromOpenAIStatus<Context>(
    _ status: Item.FunctionCall.Status
  ) -> Transcript<Context>.Status where Context: PromptContextSource {
    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusFromOpenAIStatus<Context>(
    _ status: Item.Reasoning.Status?
  ) -> Transcript<Context>.Status? where Context: PromptContextSource {
    guard let status else { return nil }

    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusToMessageStatus<Context>(
    _ status: Transcript<Context>.Status
  ) -> Message.Status where Context: PromptContextSource {
    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusToFunctionCallStatus<Context>(
    _ status: Transcript<Context>.Status
  ) -> Item.FunctionCall.Status where Context: PromptContextSource {
    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  private func transcriptStatusToReasoningStatus<Context>(
    _ status: Transcript<Context>.Status?
  ) -> Item.Reasoning.Status? where Context: PromptContextSource {
    guard let status else { return nil }

    switch status {
    case .completed: return .completed
    case .incomplete: return .incomplete
    case .inProgress: return .inProgress
    }
  }

  func transcriptToListItems<Context>(_ transcript: Transcript<Context>) -> [Input.ListItem] where Context: PromptContextSource {
    var listItems: [Input.ListItem] = []

    for entry in transcript {
      switch entry {
      case let .prompt(prompt):
        listItems.append(Input.ListItem.message(role: .user, content: .text(prompt.embeddedPrompt)))
      case let .reasoning(reasoning):
        let item = Item.Reasoning(
          id: reasoning.id,
          summary: [],
          status: transcriptStatusToReasoningStatus(reasoning.status),
          encryptedContent: reasoning.encryptedReasoning
        )

        listItems.append(Input.ListItem.item(.reasoning(item)))
      case let .toolCalls(toolCalls):
        for toolCall in toolCalls {
          let item = Item.FunctionCall(
            arguments: toolCall.arguments.jsonString,
            callId: toolCall.callId,
            id: toolCall.id,
            name: toolCall.toolName,
            status: transcriptStatusToFunctionCallStatus(toolCall.status)
          )

          listItems.append(Input.ListItem.item(.functionCall(item)))
        }
      case let .toolOutput(toolOutput):
        let output: String = {
          switch toolOutput.segment {
          case let .text(textSegment):
            return textSegment.content
          case let .structure(structuredSegment):
            return structuredSegment.content.generatedContent.jsonString
          }
        }()

        let item = Item.FunctionCallOutput(
          id: toolOutput.id,
          status: transcriptStatusToFunctionCallStatus(toolOutput.status),
          callId: toolOutput.callId,
          output: output
        )

        listItems.append(Input.ListItem.item(.functionCallOutput(item)))
      case let .response(response):
        let item = Message.Output(
          content: response.segments.compactMap { segment in
            switch segment {
            case let .text(textSegment):
              return Item.Output.Content.text(text: textSegment.content, annotations: [], logprobs: [])
            case .structure:
              // Not supported right now
              return nil
            }
          },
          id: response.id,
          role: .assistant,
          status: transcriptStatusToMessageStatus(response.status)
        )

        listItems.append(Input.ListItem.item(.outputMessage(item)))
      }
    }

    return listItems
  }
}

extension OpenAI.Model: AdapterModel {
  public static var `default`: Self {
    .gpt5
  }

  public var isReasoning: Bool {
    switch self {
    case .gpt5,
         .gpt5_mini,
         .gpt5_nano,
         .o1,
         .o1Pro,
         .o1Mini,
         .o3,
         .o3Pro,
         .o3Mini,
         .o4Mini,
         .o4MiniDeepResearch:
      return true
    default: return false
    }
  }
}
