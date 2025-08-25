// By Dennis Müller

import Foundation
import FoundationModels
import Internal

@MainActor
public protocol AgentAdapter {
  associatedtype GenerationOptions: AdapterGenerationOptions<Model>
  associatedtype Model: AdapterModel
  associatedtype Configuration: AdapterConfiguration
  associatedtype ConfigurationError: Error & LocalizedError

  init(tools: [any AgentTool], instructions: String, configuration: Configuration)

  func respond<Content, Context>(
    to prompt: AgentTranscript<Context>.Prompt,
    generating type: Content.Type,
    using model: Model,
    including transcript: AgentTranscript<Context>,
    options: GenerationOptions
  ) -> AsyncThrowingStream<AgentUpdate<Context>, any Error> where Content: Generable, Context: PromptContextSource
}

// MARK: - GenerationOptions

public protocol AdapterGenerationOptions<Model> {
  associatedtype Model: AdapterModel
  associatedtype GenerationOptionsError: Error & LocalizedError

  init()

  static func automatic(for model: Model) -> Self

  /// Validates the generation options for the given model.
  /// - Parameter model: The model to validate options against
  /// - Throws: ConfigurationError if the options are invalid for the model
  func validate(for model: Model) throws(GenerationOptionsError)
}

// MARK: - Model

public protocol AdapterModel {
  static var `default`: Self { get }
}

// MARK: Configuration

@MainActor
public protocol AdapterConfiguration: Sendable {}
