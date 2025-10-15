// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A helper that provides generation APIs for a specific `StructuredOutput` on a provider.
///
/// Instances of this type are surfaced via the `@StructuredOutput` property wrapper on
/// your `@LanguageModelProvider`-annotated session. Use it to generate the output from a
/// simple string, a `Prompt`, or a prompt built with `@PromptBuilder`, with optional
/// streaming variants. The `model` parameter selects a concrete adapter model and `options`
/// allow passing adapter-specific generation settings.
///
/// Example
///
/// ```swift
/// struct TodoSummary: StructuredOutput {
///   static let name = "todo_summary"
///
///   @Generable
///   struct Schema {
///     let title: String
///   }
/// }
///
/// @LanguageModelProvider(.openAI)
/// final class Session {
///   @StructuredOutput(TodoSummary.self) var todo
/// }
/// // let result = try await session.todo.generate(from: "Summarize today's tasks")
/// // let value: TodoSummary.Schema = try result.value
/// ```
public struct GeneratingLanguageModelProvider<Provider: LanguageModelProvider, Output: StructuredOutput> {
  private var provider: Provider
  var output: Output.Type

  /// Create a generator for a specific provider and output type.
  /// - Parameters:
  ///   - provider: The session conforming to `LanguageModelProvider`.
  ///   - output: The `StructuredOutput` type to generate.
  public init(provider: Provider, output: Output.Type) {
    self.provider = provider
    self.output = output
  }

  /// Generate the structured output from a plain string prompt.
  /// - Parameters:
  ///   - prompt: The user prompt to send to the model.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  /// - Returns: A response containing the decoded `Output.Schema`.
  /// - Throws: If grounding data cannot be encoded or the underlying adapter fails to generate.
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

  /// Generate from a formatted `Prompt` value.
  /// - Parameters:
  ///   - prompt: A `Prompt` value; its formatted string is sent to the model.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  /// - Returns: A response containing the decoded `Output.Schema`.
  /// - Throws: If generation fails in the underlying adapter.
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

  /// Build a `Prompt` with `@PromptBuilder` and generate the structured output.
  /// - Parameters:
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  ///   - prompt: A builder that constructs the `Prompt` to send.
  /// - Returns: A response containing the decoded `Output.Schema`.
  /// - Throws: If the builder throws or the underlying adapter fails to generate.
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

  /// Generate using custom grounding sources and an embedding closure that builds the final prompt.
  /// - Parameters:
  ///   - input: The raw input string to pass into the embedding closure.
  ///   - sources: Grounding items to encode and attach to the prompt.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  ///   - prompt: An embedding closure that receives `input` and `sources` and returns a `Prompt`.
  /// - Returns: A response containing the decoded `Output.Schema`.
  /// - Throws: If grounding data cannot be encoded, the embedding closure throws, or generation fails.
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

  /// Stream snapshots while generating from a plain string prompt.
  /// - Parameters:
  ///   - prompt: The user prompt to send to the model.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  /// - Returns: A stream of snapshots containing partial and final `Output.Schema` values.
  /// - Throws: If grounding data cannot be encoded or the stream cannot be created.
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

  /// Stream snapshots while generating from a `Prompt` value.
  /// - Parameters:
  ///   - prompt: A `Prompt` value; its formatted string is sent to the model.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  /// - Returns: A stream of snapshots containing partial and final `Output.Schema` values.
  /// - Throws: If the stream cannot be created.
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

  /// Stream snapshots while building the prompt with `@PromptBuilder`.
  /// - Parameters:
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  ///   - prompt: A builder that constructs the `Prompt` to send.
  /// - Returns: A stream of snapshots containing partial and final `Output.Schema` values.
  /// - Throws: If the builder throws or the stream cannot be created.
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

  /// Stream snapshots using custom grounding sources and an embedding closure.
  /// - Parameters:
  ///   - input: The raw input string to pass into the embedding closure.
  ///   - sources: Grounding items to encode and attach to the prompt.
  ///   - model: The model to use. Defaults to the provider's `.default` model.
  ///   - options: Optional adapter-specific generation options.
  ///   - prompt: An embedding closure that receives `input` and `sources` and returns a `Prompt`.
  /// - Returns: A stream of snapshots containing partial and final `Output.Schema` values.
  /// - Throws: If grounding data cannot be encoded, the embedding closure throws, or the stream cannot be created.
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
