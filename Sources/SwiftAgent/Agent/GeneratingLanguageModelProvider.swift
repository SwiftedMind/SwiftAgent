// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct GeneratingLanguageModelProvider<Provider: LanguageModelProvider, Output: StructuredOutput> {
  private var provider: Provider
  var output: Output.Type

  public init(provider: Provider, output: Output.Type) {
    self.provider = provider
    self.output = output
  }

  @discardableResult
  public func generate(
    from prompt: String,
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
  ) async throws -> Provider.Response<Output.Schema> {
    let sourcesData = try provider.encodeGrounding([Provider.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return try await provider.processResponse(
      from: prompt,
      generating: output,
      using: model,
      options: options,
    )
  }

  @discardableResult
  public func generate(
    from prompt: Prompt,
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
  ) async throws -> Provider.Response<Output.Schema> {
    try await generate(
      from: prompt.formatted(),
      using: model,
      options: options,
    )
  }

  @discardableResult
  public func generate(
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt,
  ) async throws -> Provider.Response<Output.Schema> {
    try await generate(
      from: prompt().formatted(),
      using: model,
      options: options,
    )
  }

  @discardableResult
  public func generate(
    from input: String,
    groundingWith sources: [Provider.DecodedGrounding],
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [Provider.DecodedGrounding]) -> Prompt,
  ) async throws -> Provider.Response<Output.Schema> {
    let sourcesData = try provider.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await provider.processResponse(
      from: prompt,
      generating: output,
      using: model,
      options: options,
    )
  }

  public func streamGeneration(
    from prompt: String,
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Provider.Snapshot<Output.Schema>, any Error> {
    let sourcesData = try provider.encodeGrounding([Provider.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return provider.processResponseStream(
      from: prompt,
      generating: output,
      using: model,
      options: options,
    )
  }

  public func streamGeneration(
    from prompt: Prompt,
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Provider.Snapshot<Output.Schema>, any Error> {
    try streamGeneration(
      from: prompt.formatted(),
      using: model,
      options: options,
    )
  }

  public func streamGeneration(
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Provider.Snapshot<Output.Schema>, any Error> {
    try streamGeneration(
      from: prompt().formatted(),
      using: model,
      options: options,
    )
  }

  public func streamGeneration(
    from input: String,
    groundingWith sources: [Provider.DecodedGrounding],
    using model: Provider.Adapter.Model = .default,
    options: Provider.Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [Provider.DecodedGrounding]) -> Prompt,
  ) throws -> AsyncThrowingStream<Provider.Snapshot<Output.Schema>, any Error> {
    let sourcesData = try provider.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return provider.processResponseStream(
      from: prompt,
      generating: output,
      using: model,
      options: options,
    )
  }
}
