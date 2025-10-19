// By Dennis Müller

import Foundation

/// An error produced when OpenAI generation options omit required reasoning parameters.
public enum OpenAIGenerationOptionsError: Error, LocalizedError {
  /// The include parameter for a reasoning model request is missing `.encryptedReasoning`.
  case missingEncryptedReasoningForReasoningModel

  /// A description suitable for presenting the error to the user.
  public var errorDescription: String? {
    switch self {
    case .missingEncryptedReasoningForReasoningModel:
      "You are trying to generate a response with a reasoning model without adding .encryptedReasoning in the include parameter of the generation options."
    }
  }

  /// Guidance on how to resolve the error condition.
  public var recoverySuggestion: String? {
    switch self {
    case .missingEncryptedReasoningForReasoningModel:
      "Add .encryptedReasoning to the include parameter of the generation options."
    }
  }
}
