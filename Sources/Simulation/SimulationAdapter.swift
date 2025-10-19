// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog
import SwiftAgent

public actor SimulationAdapter: Adapter {
  public typealias Model = SimulationModel
  public typealias GenerationOptions = SimulationGenerationOptions
  public typealias Transcript = SwiftAgent.Transcript
  public typealias Configuration = SimulationConfiguration
  public typealias ConfigurationError = SimulationConfigurationError

  package let configuration: SimulationConfiguration
  private let instructions: String
  private let storedTools: [any SwiftAgentTool]

  public nonisolated var tools: [any SwiftAgentTool] {
    storedTools
  }

  public init(tools: [any SwiftAgentTool], instructions: String, configuration: SimulationConfiguration) {
    self.configuration = configuration
    self.instructions = instructions
    storedTools = tools
  }

  public func respond(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: SimulationModel,
    including transcript: Transcript,
    options: SimulationGenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    do {
      let resolvedOptions = try resolveOptions(for: options)
      return makeStream(
        for: prompt,
        generations: resolvedOptions.simulatedGenerations,
        tokenUsage: resolvedOptions.tokenUsageOverride ?? configuration.tokenUsage,
        generationDelay: configuration.generationDelay,
        expecting: type,
      )
    } catch {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: error)
      }
    }
  }

  public func streamResponse(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: SimulationModel,
    including transcript: Transcript,
    options: SimulationGenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    do {
      let resolvedOptions = try resolveOptions(for: options)
      return makeStream(
        for: prompt,
        generations: resolvedOptions.simulatedGenerations,
        tokenUsage: resolvedOptions.tokenUsageOverride ?? configuration.tokenUsage,
        generationDelay: configuration.generationDelay,
        expecting: type,
      )
    } catch {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: error)
      }
    }
  }
}

private extension SimulationAdapter {
  func resolveOptions(for options: SimulationGenerationOptions) throws -> SimulationGenerationOptions {
    if !options.simulatedGenerations.isEmpty {
      return options
    }

    if !configuration.defaultGenerations.isEmpty {
      return SimulationGenerationOptions(
        simulatedGenerations: configuration.defaultGenerations,
        tokenUsageOverride: configuration.tokenUsage,
      )
    }

    throw SimulationConfigurationError.missingGenerations
  }

  func makeStream(
    for prompt: Transcript.Prompt,
    generations: [SimulatedGeneration],
    tokenUsage: TokenUsage?,
    generationDelay: Duration,
    expecting type: (some StructuredOutput).Type?,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    let setup = AsyncThrowingStream<AdapterUpdate, any Error>.makeStream()

    AgentLog.start(
      model: "simulated",
      toolNames: generations.compactMap(\.toolName),
      promptPreview: prompt.input,
    )

    let task = Task<Void, Never> {
      defer { AgentLog.finish() }
      do {
        for (index, generation) in generations.enumerated() {
          try await Task.sleep(for: generationDelay)
          AgentLog.stepRequest(step: index + 1)

          switch generation {
          case let .reasoning(summary):
            try await handleReasoning(summary: summary, continuation: setup.continuation)

          case let .toolRun(toolMock):
            try await handleToolRun(toolMock, continuation: setup.continuation)

          case let .textResponse(text):
            try await handleStringResponse(text, continuation: setup.continuation)

          case let .structuredResponse(content):
            try await handleStructuredResponse(content, continuation: setup.continuation)
          }
        }

        if let usage = tokenUsage {
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
      } catch {
        AgentLog.error(error, context: "simulation_adapter")
        setup.continuation.finish(throwing: error)
      }
    }

    setup.continuation.onTermination = { _ in
      task.cancel()
    }

    return setup.stream
  }

  func handleReasoning(
    summary: String,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let entry = Transcript.Entry.reasoning(
      Transcript.Reasoning(
        id: UUID().uuidString,
        summary: [summary],
        encryptedReasoning: "",
        status: .completed,
      ),
    )

    AgentLog.reasoning(summary: [summary])
    continuation.yield(.transcript(entry))
  }

  func handleToolRun(
    _ toolMock: some MockableTool,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let sendableTool = UnsafelySendableMockTool(mock: toolMock)
    let toolName = sendableTool.toolName
    let callId = UUID().uuidString
    let arguments = sendableTool.arguments

    let toolCall = Transcript.ToolCall(
      id: UUID().uuidString,
      callId: callId,
      toolName: toolName,
      arguments: arguments,
      status: .completed,
    )

    AgentLog.toolCall(
      name: toolName,
      callId: callId,
      argumentsJSON: arguments.jsonString,
    )

    continuation.yield(.transcript(.toolCalls(Transcript.ToolCalls(calls: [toolCall]))))

    do {
      let output = try await sendableTool.mockOutput()
      try await yieldToolOutput(
        callId: callId,
        toolName: toolName,
        output: output.generatedContent,
        continuation: continuation,
      )
    } catch let rejection as ToolRunRejection {
      try await yieldToolOutput(
        callId: callId,
        toolName: toolName,
        output: rejection.generatedContent,
        continuation: continuation,
      )
    } catch {
      AgentLog.error(error, context: "tool_call_failed_\(toolName)")
      throw GenerationError.toolExecutionFailed(toolName: toolName, underlyingError: error)
    }
  }

  func yieldToolOutput(
    callId: String,
    toolName: String,
    output: GeneratedContent,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let toolOutputEntry = Transcript.ToolOutput(
      id: UUID().uuidString,
      callId: callId,
      toolName: toolName,
      segment: .structure(Transcript.StructuredSegment(content: output)),
      status: .completed,
    )

    AgentLog.toolOutput(
      name: toolName,
      callId: callId,
      outputJSONOrText: output.jsonString,
    )

    continuation.yield(.transcript(.toolOutput(toolOutputEntry)))
  }

  func handleStringResponse(
    _ content: String,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let response = Transcript.Response(
      id: UUID().uuidString,
      segments: [.text(Transcript.TextSegment(content: content))],
      status: .completed,
    )

    AgentLog.outputMessage(text: content, status: "completed")
    continuation.yield(.transcript(.response(response)))
  }

  func handleStructuredResponse(
    _ content: GeneratedContent,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let response = Transcript.Response(
      id: UUID().uuidString,
      segments: [.structure(Transcript.StructuredSegment(content: content))],
      status: .completed,
    )

    AgentLog.outputStructured(json: content.jsonString, status: "completed")
    continuation.yield(.transcript(.response(response)))
  }
}

/// Wraps a mockable tool so it can cross `await` boundaries inside the simulation adapter.
private struct UnsafelySendableMockTool<Mock>: @unchecked Sendable where Mock: MockableTool {
  let mock: Mock

  init(mock: Mock) {
    self.mock = mock
  }

  var arguments: GeneratedContent {
    mock.mockArguments().generatedContent
  }

  var toolName: String {
    mock.tool.name
  }

  func mockOutput() async throws -> Mock.Tool.Output {
    try await mock.mockOutput()
  }
}
