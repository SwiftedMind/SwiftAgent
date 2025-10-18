// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

public actor SimulationAdapter {
  public typealias Model = SimulationModel
  public typealias Transcript = SwiftAgent.Transcript

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

  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Transcript.Prompt,
    generating type: StructuredOutput.Type,
    generations: [SimulatedGeneration<StructuredOutput>],
  ) -> AsyncThrowingStream<AdapterUpdate, any Error> {
    let setup = AsyncThrowingStream<AdapterUpdate, any Error>.makeStream()

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

  private func handleReasoning(
    summary: String,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let entryData = Transcript.Reasoning(
      id: UUID().uuidString,
      summary: [summary],
      encryptedReasoning: "",
      status: .completed,
    )

    AgentLog.reasoning(summary: [summary])

    let entry = Transcript.Entry.reasoning(entryData)
    continuation.yield(.transcript(entry))
  }

  private func handleToolRun(
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

      let toolOutputEntry = Transcript.ToolOutput(
        id: UUID().uuidString,
        callId: callId,
        toolName: toolName,
        segment: .structure(Transcript.StructuredSegment(content: output)),
        status: .completed,
      )

      let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)

      // Try to log as JSON if possible
      AgentLog.toolOutput(
        name: toolName,
        callId: callId,
        outputJSONOrText: output.generatedContent.jsonString,
      )

      continuation.yield(.transcript(transcriptEntry))
    } catch let toolRunProblem as ToolRunProblem {
      let toolOutputEntry = Transcript.ToolOutput(
        id: UUID().uuidString,
        callId: callId,
        toolName: toolName,
        segment: .structure(Transcript.StructuredSegment(content: toolRunProblem.generatedContent)),
        status: .completed,
      )

      let transcriptEntry = Transcript.Entry.toolOutput(toolOutputEntry)

      AgentLog.toolOutput(
        name: toolName,
        callId: callId,
        outputJSONOrText: toolRunProblem.generatedContent.jsonString,
      )

      continuation.yield(.transcript(transcriptEntry))
    } catch {
      AgentLog.error(error, context: "tool_call_failed_\(toolName)")
      throw GenerationError.toolExecutionFailed(toolName: toolName, underlyingError: error)
    }
  }

  private func handleStringResponse(
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

  private func handleStructuredResponse(
    _ content: some Generable,
    continuation: AsyncThrowingStream<AdapterUpdate, any Error>.Continuation,
  ) async throws {
    let generatedContent = GeneratedContent(content)

    let response = Transcript.Response(
      id: UUID().uuidString,
      segments: [.structure(Transcript.StructuredSegment(content: content))],
      status: .completed,
    )

    AgentLog.outputStructured(json: generatedContent.jsonString, status: "completed")
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
