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
  public func respond(
    to prompt: String,
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
}
