// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import SwiftAgent

// TODO: Write unit tests that test structured output
// TODO: Add access levels to the macro implementation

extension OpenAIAdapter {
  public func streamResponse(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: Model = .default,
    including transcript: Transcript,
    options: OpenAIGenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    let setup = AsyncThrowingStream<AdapterUpdate, any Error>.makeStream()

    AgentLog.start(
      model: String(describing: model),
      toolNames: tools.map(\.name),
      promptPreview: prompt.input,
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
          continuation: setup.continuation,
        )

        AgentLog.finish()
        setup.continuation.finish()
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

  private func runStreamResponse(
    transcript: Transcript,
    generating type: (some StructuredOutput).Type?,
    using model: Model,
    options: OpenAIGenerationOptions,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    var generatedTranscript = Transcript()
    var entryIndices: [String: Int] = [:]
    var messageStates: [String: StreamingMessageState] = [:]
    var functionCallStates: [String: StreamingFunctionCallState] = [:]
    var functionCallOrder: [String] = []

    let structuredOutputTypeName = type?.name
    let expectedContentDescription = structuredOutputTypeName ?? "String"
    let allowedSteps = 20
    var currentStep = 0

    stepLoop: for _ in 0..<allowedSteps {
      try Task.checkCancellation()
      currentStep += 1
      AgentLog.stepRequest(step: currentStep)

      let accumulatedTranscript = Transcript(entries: transcript.entries + generatedTranscript.entries)
      let request = try responseQuery(
        including: accumulatedTranscript,
        generating: type,
        using: model,
        options: options,
        streamResponses: true,
      )

      try Task.checkCancellation()

      let eventStream = httpClient.stream(
        path: responsesPath,
        method: .post,
        headers: [:],
        body: request,
      )

      let decoder = OpenAIResponseStreamEventDecoder()
      var responseCompleted = false
      var shouldContinueLoop = false

      do {
        streamLoop: for try await event in eventStream {
          try Task.checkCancellation()
          guard let decodedEvent = try decoder.decodeEvent(from: event) else { continue }

          switch decodedEvent {
          case .created:
            continue
          case .inProgress:
            continue
          case let .completed(responseEvent):
            responseCompleted = true
            if let usage = tokenUsage(from: responseEvent.response) {
              continuation.yield(.tokenUsage(usage))
            }
            break streamLoop
          case let .failed(responseEvent):
            let responseError = responseEvent.response.error
            throw GenerationError.fromStreamErrorEvent(
              code: responseError?.code.rawValue,
              type: "response.failed",
              message: responseError?.message ?? "Response failed",
              param: nil,
            )
          case .incomplete:
            throw GenerationError.fromStreamErrorEvent(
              code: nil,
              type: "response.incomplete",
              message: "Response incomplete",
              param: nil,
            )
          case .queued:
            continue
          case let .outputItem(outputItemEvent):
            switch outputItemEvent {
            case let .added(addedEvent):
              try handleOutputItemAdded(
                addedEvent,
                structuredOutputTypeName: structuredOutputTypeName,
                generatedTranscript: &generatedTranscript,
                entryIndices: &entryIndices,
                messageStates: &messageStates,
                functionCallStates: &functionCallStates,
                functionCallOrder: &functionCallOrder,
                continuation: continuation,
              )
            case let .done(doneEvent):
              try handleOutputItemDone(
                doneEvent,
                expectedContentDescription: expectedContentDescription,
                generatedTranscript: &generatedTranscript,
                entryIndices: &entryIndices,
                messageStates: &messageStates,
                functionCallStates: &functionCallStates,
                continuation: continuation,
              )
            }
          case let .contentPart(.added(addedEvent)):
            try handleContentPartAdded(
              addedEvent,
              messageStates: &messageStates,
              generatedTranscript: &generatedTranscript,
              continuation: continuation,
            )
          case let .contentPart(.done(doneEvent)):
            try handleContentPartDone(
              doneEvent,
              messageStates: &messageStates,
              generatedTranscript: &generatedTranscript,
              continuation: continuation,
            )
          case let .outputText(.delta(deltaEvent)):
            try handleOutputTextDelta(
              deltaEvent,
              messageStates: &messageStates,
              generatedTranscript: &generatedTranscript,
              continuation: continuation,
            )
          case let .outputText(.done(doneEvent)):
            try handleOutputTextDone(
              doneEvent,
              messageStates: &messageStates,
              generatedTranscript: &generatedTranscript,
              continuation: continuation,
            )
          case let .functionCallArguments(.delta(deltaEvent)):
            try handleFunctionCallArgumentsDelta(
              deltaEvent,
              functionCallStates: &functionCallStates,
              generatedTranscript: &generatedTranscript,
              entryIndices: entryIndices,
              continuation: continuation,
            )
          case let .functionCallArguments(.done(doneEvent)):
            try handleFunctionCallArgumentsDone(
              doneEvent,
              functionCallStates: &functionCallStates,
              generatedTranscript: &generatedTranscript,
              entryIndices: &entryIndices,
              continuation: continuation,
            )
          case let .reasoning(reasoningEvent):
            handleReasoningEvent(
              reasoningEvent,
              generatedTranscript: &generatedTranscript,
              entryIndices: entryIndices,
              continuation: continuation,
            )
          case .audio, .audioTranscript, .codeInterpreterCall, .fileSearchCall, .imageGenerationCall,
               .mcpCall, .mcpCallArguments, .mcpListTools, .outputTextAnnotation,
               .reasoningSummaryPart, .reasoningSummaryText, .refusal, .webSearchCall, .reasoningSummary:
            continue
          case let .error(errorEvent):
            let errorType = errorEvent._type.rawValue
            throw GenerationError.fromStreamErrorEvent(
              code: errorEvent.code,
              type: errorType,
              message: errorEvent.message,
              param: errorEvent.param,
            )
          }
        }

      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw GenerationError.fromStream(error, httpErrorMapper: GenerationError.from)
      }

      try Task.checkCancellation()

      guard responseCompleted else {
        continue stepLoop
      }

      // After the full response has streamed, execute any queued tool calls
      // and append their outputs to the end of the transcript.
      if !functionCallOrder.isEmpty {
        let didExecuteAny = try await executeQueuedToolCalls(
          inOrder: functionCallOrder,
          functionCallStates: &functionCallStates,
          generatedTranscript: &generatedTranscript,
          entryIndices: &entryIndices,
          continuation: continuation,
        )

        if didExecuteAny {
          shouldContinueLoop = true
        }
      }

      if shouldContinueLoop {
        continue stepLoop
      }

      return
    }
  }

  private func tokenUsage(from response: ResponseObject) -> TokenUsage? {
    guard let usage = response.usage else { return nil }

    return TokenUsage(
      inputTokens: Int(usage.inputTokens),
      outputTokens: Int(usage.outputTokens),
      totalTokens: Int(usage.totalTokens),
      cachedTokens: Int(usage.inputTokensDetails.cachedTokens),
      reasoningTokens: Int(usage.outputTokensDetails.reasoningTokens),
    )
  }

  private func handleOutputItemAdded(
    _ event: ResponseOutputItemAddedEvent,
    structuredOutputTypeName: String?,
    generatedTranscript: inout Transcript,
    entryIndices: inout [String: Int],
    messageStates: inout [String: StreamingMessageState],
    functionCallStates: inout [String: StreamingFunctionCallState],
    functionCallOrder: inout [String],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    switch event.item {
    case let .outputMessage(message):
      let status: SwiftAgent.Transcript.Status = transcriptStatusForMessage(message.status)
      let response = Transcript.Response(id: message.id, segments: [], status: status)
      let entry = Transcript.Entry.response(response)
      let entryIndex = appendEntry(
        entry,
        to: &generatedTranscript,
        entryIndices: &entryIndices,
        continuation: continuation,
      )
      messageStates[message.id] = StreamingMessageState(
        entryIndex: entryIndex,
        status: status,
        structuredOutputTypeName: structuredOutputTypeName,
      )
    case let .functionToolCall(functionCall):
      let placeholderArguments = try GeneratedContent(json: "{}")
      let toolCall = Transcript.ToolCall(
        id: functionCall.id ?? UUID().uuidString,
        callId: functionCall.callId,
        toolName: functionCall.name,
        arguments: placeholderArguments,
        status: transcriptStatusForFunctionCall(functionCall.status),
      )
      let toolCalls = Transcript.ToolCalls(calls: [toolCall])
      let entry = Transcript.Entry.toolCalls(toolCalls)
      let entryIndex = appendEntry(
        entry,
        to: &generatedTranscript,
        entryIndices: &entryIndices,
        continuation: continuation,
      )
      let identifier = functionCall.id ?? functionCall.callId
      functionCallStates[identifier] = StreamingFunctionCallState(
        entryIndex: entryIndex,
        callIdentifier: identifier,
        toolName: functionCall.name,
        callId: functionCall.callId,
        argumentsBuffer: "",
        hasInvokedTool: false,
        status: transcriptStatusForFunctionCall(functionCall.status),
        transcriptEntryId: toolCalls.id,
      )
      functionCallOrder.append(identifier)
    case let .reasoning(reasoning):
      let summary = reasoning.summary.map(\.text)
      let entryData = Transcript.Reasoning(
        id: reasoning.id,
        summary: summary,
        encryptedReasoning: reasoning.encryptedContent,
        status: transcriptStatusForReasoning(reasoning.status),
      )
      let entry = Transcript.Entry.reasoning(entryData)
      _ = appendEntry(entry, to: &generatedTranscript, entryIndices: &entryIndices, continuation: continuation)
    default:
      return
    }
  }

  private func handleOutputItemDone(
    _ event: ResponseOutputItemDoneEvent,
    expectedContentDescription: String,
    generatedTranscript: inout Transcript,
    entryIndices: inout [String: Int],
    messageStates: inout [String: StreamingMessageState],
    functionCallStates: inout [String: StreamingFunctionCallState],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    switch event.item {
    case let .outputMessage(message):
      guard var state = messageStates[message.id] else { return }

      state.status = transcriptStatusForMessage(message.status)
      try updateMessageEntry(
        state: &state,
        generatedTranscript: &generatedTranscript,
        finalizeStructuredContent: false,
        continuation: continuation,
      )
      messageStates[message.id] = state
      if let refusalText = state.refusalText {
        AgentLog.outputMessage(text: refusalText, status: String(describing: message.status))
        throw GenerationError.contentRefusal(
          .init(expectedType: expectedContentDescription, reason: refusalText),
        )
      }
    case let .functionToolCall(functionCall):
      let identifier = functionCall.id ?? functionCall.callId
      guard var state = functionCallStates[identifier],
            let index = entryIndices[state.transcriptEntryId] else { return }

      state.status = transcriptStatusForFunctionCall(functionCall.status)
      functionCallStates[identifier] = state
      updateTranscriptEntry(at: index, in: &generatedTranscript, continuation: continuation) { entry in
        guard case var .toolCalls(toolCalls) = entry else { return }
        guard let callIndex = toolCalls.calls.firstIndex(where: { $0.id == state.callIdentifier }) else { return }

        toolCalls.calls[callIndex].status = state.status
        entry = .toolCalls(toolCalls)
      }
    case let .reasoning(reasoning):
      guard let index = entryIndices[reasoning.id] else { return }

      updateTranscriptEntry(at: index, in: &generatedTranscript, continuation: continuation) { entry in
        guard case var .reasoning(existing) = entry else { return }

        existing.status = transcriptStatusForReasoning(reasoning.status)
        entry = .reasoning(existing)
      }
    default:
      return
    }
  }

  private func handleContentPartAdded(
    _ event: Components.Schemas.ResponseContentPartAddedEvent,
    messageStates: inout [String: StreamingMessageState],
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    try updateMessageState(
      for: event.itemId,
      messageStates: &messageStates,
      generatedTranscript: &generatedTranscript,
      finalizeStructuredContent: false,
      continuation: continuation,
    ) { state in
      switch event.part {
      case let .OutputTextContent(textContent):
        state.fragments.assign(textContent.text, at: event.contentIndex)
      case let .RefusalContent(refusal):
        state.refusalText = refusal.refusal
      }
    }
  }

  private func handleContentPartDone(
    _ event: Components.Schemas.ResponseContentPartDoneEvent,
    messageStates: inout [String: StreamingMessageState],
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    try updateMessageState(
      for: event.itemId,
      messageStates: &messageStates,
      generatedTranscript: &generatedTranscript,
      finalizeStructuredContent: false,
      continuation: continuation,
    ) { state in
      switch event.part {
      case let .OutputTextContent(textContent):
        state.fragments.assign(textContent.text, at: event.contentIndex)
      case let .RefusalContent(refusal):
        state.refusalText = refusal.refusal
      }
    }
  }

  private func handleOutputTextDelta(
    _ event: Components.Schemas.ResponseTextDeltaEvent,
    messageStates: inout [String: StreamingMessageState],
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    try updateMessageState(
      for: event.itemId,
      messageStates: &messageStates,
      generatedTranscript: &generatedTranscript,
      finalizeStructuredContent: false,
      continuation: continuation,
    ) { state in
      state.fragments.append(event.delta, at: event.contentIndex)
    }
  }

  private func handleOutputTextDone(
    _ event: Components.Schemas.ResponseTextDoneEvent,
    messageStates: inout [String: StreamingMessageState],
    generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    guard let currentState = messageStates[event.itemId] else { return }

    let finalizeStructuredContent = currentState.structuredOutputTypeName != nil

    let updatedState = try updateMessageState(
      for: event.itemId,
      messageStates: &messageStates,
      generatedTranscript: &generatedTranscript,
      finalizeStructuredContent: finalizeStructuredContent,
      continuation: continuation,
    ) { state in
      state.fragments.assign(event.text, at: event.contentIndex)
    }

    guard let state = updatedState else { return }

    if state.isGeneratingPlainText {
      let combinedText = state.fragments.joined(separator: "\n")
      AgentLog.outputMessage(text: combinedText, status: "completed")
    } else {
      let combinedJSON = state.fragments.joined()
      AgentLog.outputStructured(json: combinedJSON, status: "completed")
    }
  }

  private func handleFunctionCallArgumentsDelta(
    _ event: Components.Schemas.ResponseFunctionCallArgumentsDeltaEvent,
    functionCallStates: inout [String: StreamingFunctionCallState],
    generatedTranscript: inout Transcript,
    entryIndices: [String: Int],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    guard var state = functionCallStates[event.itemId],
          let entryIndex = entryIndices[state.transcriptEntryId] else { return }

    state.argumentsBuffer += event.delta
    functionCallStates[event.itemId] = state
    updateTranscriptEntry(at: entryIndex, in: &generatedTranscript, continuation: continuation) { entry in
      guard case var .toolCalls(toolCalls) = entry else { return }
      guard let callIndex = toolCalls.calls.firstIndex(where: { $0.id == state.callIdentifier }) else { return }

      if let updatedArguments = try? GeneratedContent(json: state.argumentsBuffer) {
        toolCalls.calls[callIndex].arguments = updatedArguments
      }
      entry = .toolCalls(toolCalls)
    }
  }

  private func handleFunctionCallArgumentsDone(
    _ event: Components.Schemas.ResponseFunctionCallArgumentsDoneEvent,
    functionCallStates: inout [String: StreamingFunctionCallState],
    generatedTranscript: inout Transcript,
    entryIndices: inout [String: Int],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    guard var state = functionCallStates[event.itemId],
          let entryIndex = entryIndices[state.transcriptEntryId] else { return }

    // Persist the final arguments buffer for deferred tool invocation
    state.argumentsBuffer = event.arguments
    functionCallStates[event.itemId] = state

    // Update the displayed tool call arguments immediately, but do not
    // invoke the tool yet. Tool execution will be deferred until after
    // the response stream completes to keep transcript ordering intact.
    try updateTranscriptEntry(at: entryIndex, in: &generatedTranscript, continuation: continuation) { entry in
      guard case var .toolCalls(toolCalls) = entry else { return }
      guard let callIndex = toolCalls.calls.firstIndex(where: { $0.id == state.callIdentifier }) else { return }

      let rawContent = try GeneratedContent(json: event.arguments)
      toolCalls.calls[callIndex].arguments = rawContent
      entry = .toolCalls(toolCalls)
    }
  }

  private func executeQueuedToolCalls(
    inOrder functionCallOrder: [String],
    functionCallStates: inout [String: StreamingFunctionCallState],
    generatedTranscript: inout Transcript,
    entryIndices: inout [String: Int],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws -> Bool {
    var executedAny = false

    for identifier in functionCallOrder {
      try Task.checkCancellation()
      guard var state = functionCallStates[identifier] else { continue }
      guard !state.hasInvokedTool else { continue }
      guard !state.argumentsBuffer.isEmpty else { continue }
      guard let tool = tools.first(where: { $0.name == state.toolName }) else {
        AgentLog.error(
          GenerationError.unsupportedToolCalled(.init(toolName: state.toolName)),
          context: "tool_not_found",
        )
        throw GenerationError.unsupportedToolCalled(.init(toolName: state.toolName))
      }

      AgentLog.toolCall(
        name: state.toolName,
        callId: state.callId,
        argumentsJSON: state.argumentsBuffer,
      )

      do {
        let rawContent = try GeneratedContent(json: state.argumentsBuffer)
        let output = try await callTool(tool, with: rawContent)
        let toolOutputEntry = Transcript.ToolOutput(
          id: state.callIdentifier,
          callId: state.callId,
          toolName: state.toolName,
          segment: .structure(.init(content: output)),
          status: state.status,
        )
        let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)
        appendEntry(transcriptEntry, to: &generatedTranscript, entryIndices: &entryIndices, continuation: continuation)
        state.hasInvokedTool = true
        functionCallStates[identifier] = state
        AgentLog.toolOutput(
          name: tool.name,
          callId: state.callId,
          outputJSONOrText: output.generatedContent.jsonString,
        )
        executedAny = true
      } catch let toolRunProblem as ToolRunProblem {
        let toolOutputEntry = Transcript.ToolOutput(
          id: state.callIdentifier,
          callId: state.callId,
          toolName: state.toolName,
          segment: .structure(.init(content: toolRunProblem.generatedContent)),
          status: state.status,
        )
        let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)
        appendEntry(transcriptEntry, to: &generatedTranscript, entryIndices: &entryIndices, continuation: continuation)
        state.hasInvokedTool = true
        functionCallStates[identifier] = state
        AgentLog.toolOutput(
          name: tool.name,
          callId: state.callId,
          outputJSONOrText: toolRunProblem.generatedContent.jsonString,
        )
        executedAny = true
      } catch {
        AgentLog.error(error, context: "tool_call_failed_\(state.toolName)")
        throw GenerationError.toolExecutionFailed(toolName: tool.name, underlyingError: error)
      }
    }

    return executedAny
  }

  private func handleReasoningEvent(
    _ event: ResponseStreamEvent.ReasoningEvent,
    generatedTranscript: inout Transcript,
    entryIndices: [String: Int],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) {
    switch event {
    case .delta:
      return
    case let .done(doneEvent):
      guard let index = entryIndices[doneEvent.itemId] else { return }

      var entry = generatedTranscript.entries[index]
      guard case var .reasoning(reasoning) = entry else { return }

      reasoning.status = .completed
      entry = .reasoning(reasoning)
      generatedTranscript.entries[index] = entry
      continuation.yield(.transcript(entry))
    }
  }

  @discardableResult
  private func appendEntry(
    _ entry: Transcript.Entry,
    to generatedTranscript: inout Transcript,
    entryIndices: inout [String: Int],
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) -> Int {
    generatedTranscript.entries.append(entry)
    let index = generatedTranscript.entries.count - 1
    entryIndices[entry.id] = index
    continuation.yield(.transcript(entry))
    return index
  }

  @discardableResult
  private func updateTranscriptEntry(
    at index: Int,
    in generatedTranscript: inout Transcript,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
    mutate: (inout Transcript.Entry) throws -> Void,
  ) rethrows -> Transcript.Entry {
    var entry = generatedTranscript.entries[index]
    try mutate(&entry)
    generatedTranscript.entries[index] = entry
    continuation.yield(.transcript(entry))
    return entry
  }

  /// Updates the transcript entry to reflect the most recent streaming state, parsing
  /// structured JSON content as soon as it becomes available.
  private func updateMessageEntry(
    state: inout StreamingMessageState,
    generatedTranscript: inout Transcript,
    finalizeStructuredContent: Bool,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) throws {
    try updateTranscriptEntry(at: state.entryIndex, in: &generatedTranscript, continuation: continuation) { entry in
      guard case var .response(response) = entry else { return }

      response.status = state.status

      if let refusalText = state.refusalText {
        state.structuredContent = nil
        response.segments = [.text(.init(content: refusalText))]
      } else if let typeName = state.structuredOutputTypeName {
        let combinedJSON = state.fragments.joined()
        guard !combinedJSON.isEmpty else { return }

        do {
          let content = try GeneratedContent(json: combinedJSON)
          state.structuredContent = content
          response.segments = [.structure(.init(typeName: typeName, content: content))]
        } catch {
          if finalizeStructuredContent {
            AgentLog.error(error, context: "structured_response_parsing")
            throw GenerationError.structuredContentParsingFailed(
              .init(rawContent: combinedJSON, underlyingError: error),
            )
          } else {
            return
          }
        }
      } else {
        let fragments = state.fragments.nonEmptyFragments
        guard !fragments.isEmpty else { return }

        state.structuredContent = nil
        response.segments = fragments.map { .text(.init(content: $0)) }
      }

      entry = .response(response)
    }
  }

  /// Applies a mutation to the streaming message state and keeps the backing transcript entry in sync.
  @discardableResult
  private func updateMessageState(
    for itemId: String,
    messageStates: inout [String: StreamingMessageState],
    generatedTranscript: inout Transcript,
    finalizeStructuredContent: Bool,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
    mutation: (inout StreamingMessageState) -> Void,
  ) throws -> StreamingMessageState? {
    guard var state = messageStates[itemId] else { return nil }

    mutation(&state)
    try updateMessageEntry(
      state: &state,
      generatedTranscript: &generatedTranscript,
      finalizeStructuredContent: finalizeStructuredContent,
      continuation: continuation,
    )
    messageStates[itemId] = state
    return state
  }
}

private struct StreamingMessageState {
  var entryIndex: Int
  var fragments = ContentFragmentBuffer()
  var structuredContent: GeneratedContent?
  var refusalText: String?
  var status: SwiftAgent.Transcript.Status
  var structuredOutputTypeName: String?

  var isGeneratingPlainText: Bool {
    structuredOutputTypeName == nil
  }
}

private struct StreamingFunctionCallState {
  var entryIndex: Int
  var callIdentifier: String
  var toolName: String
  var callId: String
  var argumentsBuffer: String
  var hasInvokedTool: Bool
  var status: SwiftAgent.Transcript.Status?
  var transcriptEntryId: String
}

private struct ContentFragmentBuffer {
  private(set) var fragments: [String] = []

  mutating func append(_ text: String, at index: Int) {
    ensureCapacity(for: index)
    fragments[index].append(text)
  }

  mutating func assign(_ text: String, at index: Int) {
    ensureCapacity(for: index)
    fragments[index] = text
  }

  func joined(separator: String = "") -> String {
    fragments.joined(separator: separator)
  }

  var nonEmptyFragments: [String] {
    fragments.filter { !$0.isEmpty }
  }

  private mutating func ensureCapacity(for index: Int) {
    if fragments.count <= index {
      fragments.append(contentsOf: Array(repeating: "", count: index - fragments.count + 1))
    }
  }
}

private func transcriptStatusForMessage(
  _ status: Components.Schemas.OutputMessage.StatusPayload,
) -> SwiftAgent.Transcript.Status {
  switch status {
  case .completed:
    SwiftAgent.Transcript.Status.completed
  case .incomplete:
    SwiftAgent.Transcript.Status.incomplete
  case .inProgress:
    SwiftAgent.Transcript.Status.inProgress
  }
}

private func transcriptStatusForFunctionCall(
  _ status: Components.Schemas.FunctionToolCall.StatusPayload?,
) -> SwiftAgent.Transcript.Status? {
  guard let status else { return nil }

  switch status {
  case .completed:
    return SwiftAgent.Transcript.Status.completed
  case .incomplete:
    return SwiftAgent.Transcript.Status.incomplete
  case .inProgress:
    return SwiftAgent.Transcript.Status.inProgress
  }
}

private func transcriptStatusForReasoning(
  _ status: Components.Schemas.ReasoningItem.StatusPayload?,
) -> SwiftAgent.Transcript.Status? {
  guard let status else { return nil }

  switch status {
  case .completed:
    return SwiftAgent.Transcript.Status.completed
  case .incomplete:
    return SwiftAgent.Transcript.Status.incomplete
  case .inProgress:
    return SwiftAgent.Transcript.Status.inProgress
  }
}
