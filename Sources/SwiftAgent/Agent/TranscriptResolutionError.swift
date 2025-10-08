// By Dennis Müller

import Foundation

public enum TranscriptResolutionError: Error, LocalizedError, Sendable, Equatable {
  case prompt(PromptResolution)
  case toolRun(ToolRunResolution)

  public var errorDescription: String? {
    switch self {
    case let .prompt(resolution):
      resolution.errorDescription
    case let .toolRun(resolution):
      resolution.errorDescription
    }
  }

  public enum PromptResolution: Error, LocalizedError, Sendable, Equatable {
    case groundingDecodingFailed(description: String)

    public var errorDescription: String? {
      switch self {
      case let .groundingDecodingFailed(description):
        "Prompt grounding decoding failed: \(description)"
      }
    }
  }

  public enum ToolRunResolution: Error, LocalizedError, Sendable, Equatable {
    case unknownTool(name: String)
    case resolutionFailed(description: String)

    public var errorDescription: String? {
      switch self {
      case let .unknownTool(name):
        "Tool run failed: unknown tool named \(name)"
      case let .resolutionFailed(description):
        "Tool run failed: \(description)"
      }
    }
  }
}
