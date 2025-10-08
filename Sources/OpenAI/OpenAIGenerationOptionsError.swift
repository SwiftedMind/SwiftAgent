// By Dennis Müller

import Foundation
import Internal

public enum OpenAIGenerationOptionsError: Error, LocalizedError {
  case missingEncryptedReasoningForReasoningModel

  public var errorDescription: String? {
    switch self {
    case .missingEncryptedReasoningForReasoningModel:
      "You are trying to generate a response with a reasoning model without adding .encryptedReasoning in the include parameter of the generation options."
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .missingEncryptedReasoningForReasoningModel:
      "Add .encryptedReasoning to the include parameter of the generation options."
    }
  }
}
