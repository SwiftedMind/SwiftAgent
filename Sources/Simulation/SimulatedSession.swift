// By Dennis Müller

import Foundation
import FoundationModels
@_exported import SwiftAgent

public extension ModelSession {
  private var simulationAdapter: SimulationAdapter {
    SimulationAdapter()
  }

  private func simulationAdapter(with configuration: SimulationAdapter.Configuration) -> SimulationAdapter {
    SimulationAdapter(configuration: configuration)
  }

  @discardableResult
  func simulateResponse(
    to prompt: String,
    generations: [SimulatedGeneration<String>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration()
  ) async throws -> Response<String> {
    let transcriptPrompt = Transcript.Prompt(input: prompt, embeddedPrompt: prompt)
    let promptEntry = Transcript.Entry.prompt(transcriptPrompt)
    transcript.append(promptEntry)

    let stream = simulationAdapter(with: configuration).respond(
      to: transcriptPrompt,
      generating: String.self,
      generations: generations
    )
    var responseContent: [String] = []
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        transcript.append(entry)
        addedEntities.append(entry)

        if case let .response(response) = entry {
          for segment in response.segments {
            switch segment {
            case let .text(textSegment):
              responseContent.append(textSegment.content)
            case .structure:
              break
            }
          }
        }
      case let .tokenUsage(usage):
        if var current = aggregatedUsage {
          current.merge(usage)
          aggregatedUsage = current
        } else {
          aggregatedUsage = usage
        }
      }
    }

    return AgentResponse<Adapter, Context, String>(
      content: responseContent.joined(separator: "\n"),
      addedEntries: addedEntities,
      tokenUsage: aggregatedUsage
    )
  }

  @discardableResult
  func simulateResponse<Content>(
    to prompt: String,
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration()
  ) async throws -> Response<Content> where Content: MockableGenerable {
    let transcriptPrompt = Transcript.Prompt(input: prompt, embeddedPrompt: prompt)
    let promptEntry = Transcript.Entry.prompt(transcriptPrompt)
    transcript.append(promptEntry)

    let stream = simulationAdapter(with: configuration).respond(
      to: transcriptPrompt,
      generating: Content.self,
      generations: generations
    )
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        transcript.append(entry)
        addedEntities.append(entry)

        if case let .response(response) = entry {
          for segment in response.segments {
            switch segment {
            case .text:
              break
            case let .structure(structuredSegment):
              return try AgentResponse<Adapter, Context, Content>(
                content: Content(structuredSegment.content),
                addedEntries: addedEntities,
                tokenUsage: aggregatedUsage
              )
            }
          }
        }
      case let .tokenUsage(usage):
        if var current = aggregatedUsage {
          current.merge(usage)
          aggregatedUsage = current
        } else {
          aggregatedUsage = usage
        }
      }
    }

    let errorContext = AgentGenerationError.UnexpectedStructuredResponseContext()
    throw AgentGenerationError.unexpectedStructuredResponse(errorContext)
  }

  @discardableResult
  func simulateResponse(
    to prompt: SwiftAgent.Prompt,
    generations: [SimulatedGeneration<String>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration()
  ) async throws -> Response<String> {
    try await simulateResponse(to: prompt.formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse<Content>(
    to prompt: SwiftAgent.Prompt,
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration()
  ) async throws -> Response<Content> where Content: MockableGenerable {
    try await simulateResponse(to: prompt.formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse(
    generations: [SimulatedGeneration<String>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
    @SwiftAgent.PromptBuilder prompt: () throws -> SwiftAgent.Prompt
  ) async throws -> Response<String> {
    try await simulateResponse(to: prompt().formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse<Content>(
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
    @SwiftAgent.PromptBuilder prompt: () throws -> SwiftAgent.Prompt
  ) async throws -> Response<Content> where Content: MockableGenerable {
    try await simulateResponse(to: prompt().formatted(), generations: generations, configuration: configuration)
  }
}
