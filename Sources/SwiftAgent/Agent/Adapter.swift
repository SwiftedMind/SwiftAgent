// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol Adapter: Actor {
  associatedtype GenerationOptions: AdapterGenerationOptions<Model>
  associatedtype Model: AdapterModel
  associatedtype Configuration: AdapterConfiguration
  associatedtype ConfigurationError: Error & Sendable

  nonisolated var tools: [any SwiftAgentTool] { get }

  init(tools: [any SwiftAgentTool], instructions: String, configuration: Configuration)

  func respond(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: Model,
    including transcript: Transcript,
    options: GenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error>

  func streamResponse(
    to prompt: Transcript.Prompt,
    generating type: (some StructuredOutput).Type?,
    using model: Model,
    including transcript: Transcript,
    options: GenerationOptions,
  ) -> AsyncThrowingStream<AdapterUpdate, any Error>
}

// MARK: - GenerationOptions

public protocol AdapterGenerationOptions<Model>: Sendable {
  associatedtype Model: AdapterModel
  associatedtype GenerationOptionsError: Error & LocalizedError

  var minimumStreamingSnapshotInterval: Duration? { get }

  init()

  static func automatic(for model: Model) -> Self

  /// Validates the generation options for the given model.
  /// - Parameter model: The model to validate options against
  /// - Throws: ConfigurationError if the options are invalid for the model
  func validate(for model: Model) throws(GenerationOptionsError)
}

// MARK: - Model

public protocol AdapterModel: Sendable {
  static var `default`: Self { get }
}

// MARK: Configuration

public protocol AdapterConfiguration: Sendable {}
