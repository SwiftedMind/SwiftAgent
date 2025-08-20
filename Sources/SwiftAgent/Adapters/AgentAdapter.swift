// By Dennis Müller

import Foundation
import FoundationModels
import Internal

@MainActor
public protocol AgentAdapter {
  associatedtype GenerationOptions: AdapterGenerationOptions
  associatedtype Model: AdapterModel
  associatedtype Configuration: AdapterConfiguration
  associatedtype ConfigurationError: Error & LocalizedError

  init(tools: [any AgentTool], instructions: String, configuration: Configuration)

  func respond<Content, ContextReference>(
    to prompt: AgentTranscript<ContextReference>.Prompt,
    generating type: Content.Type,
    using model: Model,
    including transcript: AgentTranscript<ContextReference>,
    options: GenerationOptions
  ) -> AsyncThrowingStream<AgentTranscript<ContextReference>.Entry, any Error> where Content: Generable, ContextReference: PromptContextReference
}

// MARK: - GenerationOptions

public protocol AdapterGenerationOptions {
  associatedtype Model: AdapterModel
  associatedtype ConfigurationError: Error & LocalizedError

  init()

  /// Validates the generation options for the given model.
  /// - Parameter model: The model to validate options against
  /// - Throws: ConfigurationError if the options are invalid for the model
  func validate(for model: Model) throws(ConfigurationError)
}

// MARK: - Model

public protocol AdapterModel {
  static var `default`: Self { get }
}

// MARK: Configuration

@MainActor
public protocol AdapterConfiguration: Sendable {
  /// The default configuration used when no explicit configuration is supplied.
  static var `default`: Self { get set }

  /// Override the default configuration used by convenience initializers/providers.
  static func setDefaultConfiguration(_ configuration: Self)
}

public extension AdapterConfiguration {
  /// Overrides the static default configuration used by convenience providers.
  static func setDefaultConfiguration(_ configuration: Self) {
    `default` = configuration
  }
}
