// By Dennis Müller

import Foundation
import FoundationModels
@_exported import SwiftAgent

public extension LanguageModelProvider {
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
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
  ) async throws -> AgentResponse<String, Self> {
    let sourcesData = try encodeGrounding([GroundingRepresentation]())
    let transcriptPrompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    let promptEntry = Transcript.Entry.prompt(transcriptPrompt)
    await appendTranscript(promptEntry)

    let stream = await simulationAdapter(with: configuration).respond(
      to: transcriptPrompt,
      generating: String.self,
      generations: generations,
    )
    var responseContent: [String] = []
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        await appendTranscript(entry)
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

    let transcript = Transcript(entries: addedEntities)
    let resolvedTranscript = transcript.resolved(in: self)
    return AgentResponse<String, Self>(
      content: responseContent.joined(separator: "\n"),
      transcript: transcript,
      resolvedTranscript: resolvedTranscript,
      tokenUsage: aggregatedUsage,
    )
  }

  @discardableResult
  func simulateResponse<Content>(
    to prompt: String,
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
  ) async throws -> AgentResponse<Content, Self> where Content: MockableGenerable {
    let sourcesData = try encodeGrounding([GroundingRepresentation]())
    let transcriptPrompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    let promptEntry = Transcript.Entry.prompt(transcriptPrompt)
    await appendTranscript(promptEntry)

    let stream = await simulationAdapter(with: configuration).respond(
      to: transcriptPrompt,
      generating: Content.self,
      generations: generations,
    )
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        await appendTranscript(entry)
        addedEntities.append(entry)

        if case let .response(response) = entry {
          for segment in response.segments {
            switch segment {
            case .text:
              break
            case let .structure(structuredSegment):
              let transcript = Transcript(entries: addedEntities)
              let resolvedTranscript = transcript.resolved(in: self)
              return try AgentResponse<Content, Self>(
                content: Content(structuredSegment.content),
                transcript: transcript,
                resolvedTranscript: resolvedTranscript,
                tokenUsage: aggregatedUsage,
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

    let errorContext = GenerationError.UnexpectedStructuredResponseContext()
    throw GenerationError.unexpectedStructuredResponse(errorContext)
  }

  @discardableResult
  func simulateResponse(
    to prompt: SwiftAgent.Prompt,
    generations: [SimulatedGeneration<String>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
  ) async throws -> AgentResponse<String, Self> {
    try await simulateResponse(to: prompt.formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse<Content>(
    to prompt: SwiftAgent.Prompt,
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
  ) async throws -> AgentResponse<Content, Self> where Content: MockableGenerable {
    try await simulateResponse(to: prompt.formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse(
    generations: [SimulatedGeneration<String>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
    @SwiftAgent.PromptBuilder prompt: () throws -> SwiftAgent.Prompt,
  ) async throws -> AgentResponse<String, Self> {
    try await simulateResponse(to: prompt().formatted(), generations: generations, configuration: configuration)
  }

  @discardableResult
  func simulateResponse<Content>(
    generations: [SimulatedGeneration<Content>],
    configuration: SimulationAdapter.Configuration = SimulationAdapter.Configuration(),
    @SwiftAgent.PromptBuilder prompt: () throws -> SwiftAgent.Prompt,
  ) async throws -> AgentResponse<Content, Self> where Content: MockableGenerable {
    try await simulateResponse(to: prompt().formatted(), generations: generations, configuration: configuration)
  }
}
