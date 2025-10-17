// By Dennis Müller

import Foundation
import FoundationModels

// MARK: - String Response Methods

public extension LanguageModelProvider {
  func streamResponse(
    to prompt: String,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, using: model, options: options)
  }

  func streamResponse(
    to prompt: Prompt,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    try streamResponse(to: prompt.formatted(), using: model, options: options)
  }

  func streamResponse(
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    try streamResponse(to: prompt().formatted(), using: model, options: options)
  }
}

// MARK: - Structured Response Methods

public extension LanguageModelProvider {
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, generating: type, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, generating: StructuredOutput.self, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    try streamResponse(to: prompt.formatted(), generating: type, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    try streamResponse(to: prompt.formatted(), generating: StructuredOutput.self, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    try streamResponse(to: prompt().formatted(), generating: type, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    try streamResponse(to: prompt().formatted(), generating: StructuredOutput.self, using: model, options: options)
  }
}

// MARK: - Context-Aware Response Methods

public extension LanguageModelProvider {
  func streamResponse(
    to input: String,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, using: model, options: options)
  }

  @discardableResult
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: StructuredOutput.Type,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, generating: type, using: model, options: options)
  }

  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput.Schema>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, generating: StructuredOutput.self, using: model, options: options)
  }
}
